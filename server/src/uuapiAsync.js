import fs from 'node:fs';
import path from 'node:path';
import { config } from './config.js';
import { logger } from './logBus.js';
import { fetchLogged } from './fetchLog.js';

function joinUrl(base, p) {
  const b = String(base).replace(/\/+$/, '');
  let path = p.startsWith('/') ? p : `/${p}`;
  if (/\/v1$/i.test(b) && path.startsWith('/v1/')) {
    path = path.slice(3);
  }
  return `${b}${path}`;
}

function authHeaders(apiKey) {
  return {
    Authorization: `Bearer ${apiKey}`,
    'Content-Type': 'application/json',
  };
}

function pickError(json) {
  return (
    json?.error?.message ||
    json?.message ||
    json?.msg ||
    (typeof json?.error === 'string' ? json.error : null)
  );
}

function failHttp(res, json) {
  const detail = pickError(json);
  logger.error(`uuapi HTTP ${res.status}`, {
    detail,
    body: JSON.stringify(json || {}).slice(0, 500),
  });
  return new Error(detail || `上游错误 HTTP ${res.status}`);
}

async function resolveUpload(name) {
  const safe = path.basename(name);
  const p = path.join(config.uploadsDir, safe);
  if (!p.startsWith(config.uploadsDir)) throw new Error('非法路径');
  if (!fs.existsSync(p)) throw new Error(`上传文件不存在: ${safe}`);
  return p;
}

async function toDataUri(name) {
  const p = await resolveUpload(name);
  const buf = fs.readFileSync(p);
  const ext = path.extname(p).toLowerCase();
  const type =
    ext === '.jpg' || ext === '.jpeg'
      ? 'image/jpeg'
      : ext === '.webp'
        ? 'image/webp'
        : ext === '.gif'
          ? 'image/gif'
          : 'image/png';
  return `data:${type};base64,${buf.toString('base64')}`;
}

async function toBlob(name) {
  const p = await resolveUpload(name);
  const buf = fs.readFileSync(p);
  const ext = path.extname(p).toLowerCase();
  const type =
    ext === '.jpg' || ext === '.jpeg'
      ? 'image/jpeg'
      : ext === '.webp'
        ? 'image/webp'
        : ext === '.gif'
          ? 'image/gif'
          : 'image/png';
  return new Blob([buf], { type });
}

/**
 * 提交 uuapi 异步任务。
 * 文生图：POST /v1/images/generations/async
 * 图编辑：POST /v1/images/edits/async（multipart 或 JSON images[].image_url）
 * 返回 { remoteTaskId }
 */
export async function submitUuapiAsync({ target, taskType, params }) {
  const timeout = config.upstreamTimeoutMs;

  if (taskType === 'generate') {
    const url = joinUrl(target.baseUrl, '/v1/images/generations/async');
    const body = {
      model: target.upstreamModel,
      prompt: params.prompt,
      n: params.n || 1,
      size: params.size || '1024x1024',
      response_format: 'url',
    };
    logger.info(`POST ${url}`, { model: body.model, n: body.n, size: body.size });
    const res = await fetchLogged(url, {
      method: 'POST',
      headers: authHeaders(target.apiKey),
      body: JSON.stringify(body),
      signal: AbortSignal.timeout(timeout),
    });
    const json = await res.json().catch(() => ({}));
    if (!res.ok && res.status !== 202) throw failHttp(res, json);
    const remoteTaskId = json?.task_id || json?.id;
    if (!remoteTaskId) throw new Error(json?.message || '上游未返回 task_id');
    return { remoteTaskId };
  }

  // edit：multipart（与文档一致，image/mask 文件字段）
  const url = joinUrl(target.baseUrl, '/v1/images/edits/async');
  const form = new FormData();
  form.append('model', target.upstreamModel);
  form.append('prompt', params.prompt);
  form.append('n', String(params.n || 1));
  form.append('size', params.size || '1024x1024');
  form.append('response_format', 'url');
  for (const f of params.images || []) {
    form.append('image', await toBlob(f), path.basename(f));
  }
  if (params.mask) {
    form.append('mask', await toBlob(params.mask), 'mask.png');
  }
  logger.info(`POST ${url} (multipart edit)`, { model: target.upstreamModel });
  const res = await fetchLogged(url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${target.apiKey}` },
    body: form,
    signal: AbortSignal.timeout(timeout),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok && res.status !== 202) throw failHttp(res, json);
  const remoteTaskId = json?.task_id || json?.id;
  if (!remoteTaskId) throw new Error(json?.message || '上游未返回 task_id');
  return { remoteTaskId };
}

/**
 * 轮询 uuapi 任务：processing / completed / failed
 * 返回 { status, urls?, error? }
 */
export async function queryUuapiAsync({ target, remoteTaskId }) {
  const url = joinUrl(target.baseUrl, `/v1/images/tasks/${remoteTaskId}`);
  logger.debug(`GET ${url}`);
  const res = await fetchLogged(url, {
    headers: authHeaders(target.apiKey),
    signal: AbortSignal.timeout(30000),
  });
  const json = await res.json().catch(() => ({}));
  if (res.status === 404) {
    return { status: 'failed', error: '任务不存在或跨 Key 查询' };
  }
  if (!res.ok) throw failHttp(res, json);

  const st = String(json?.status || '').toLowerCase();
  logger.debug(`uuapi 轮询 ${remoteTaskId} → ${st}`, {
    raw: JSON.stringify(json).slice(0, 1200),
  });

  if (st === 'completed') {
    const data = json?.result?.data || json?.result?.images || [];
    const urls = [];
    const buffers = [];
    for (const item of data) {
      if (typeof item?.url === 'string' && item.url) urls.push(item.url);
      else if (typeof item?.b64_json === 'string' && item.b64_json) {
        buffers.push(Buffer.from(item.b64_json, 'base64'));
      } else if (typeof item === 'string' && item) urls.push(item);
    }
    if (!urls.length && !buffers.length) {
      return { status: 'failed', error: '任务完成但无图片（详见日志 raw）' };
    }
    return { status: 'succeeded', urls, buffers };
  }
  if (st === 'failed') {
    const err = json?.error;
    const msg =
      (typeof err === 'string' ? err : err?.message) || json?.message || '上游任务失败';
    return { status: 'failed', error: msg };
  }
  return { status: 'running' };
}

export async function downloadUrlToBuffer(url) {
  const res = await fetchLogged(url, {
    signal: AbortSignal.timeout(config.upstreamTimeoutMs),
  });
  if (!res.ok) throw new Error(`下载结果图失败 HTTP ${res.status}`);
  return Buffer.from(await res.arrayBuffer());
}
