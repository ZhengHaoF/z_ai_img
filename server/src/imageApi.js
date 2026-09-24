import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { config } from './config.js';
import { logger } from './logBus.js';

function pickError(json) {
  return (
    json?.error?.message ||
    json?.message ||
    json?.msg ||
    json?.error ||
    (typeof json?.error === 'string' ? json.error : null) ||
    null
  );
}

function upsertFail(res, json) {
  const detail = pickError(json);
  const bodyPreview = JSON.stringify(json || {}).slice(0, 500);
  logger.error(`上游 HTTP ${res.status}`, { detail, body: bodyPreview });
  return new Error(detail || `上游错误 HTTP ${res.status}${bodyPreview !== '{}' ? ` ${bodyPreview}` : ''}`);
}

/**
 * 调用上游图像 API。
 * target: { baseUrl, apiKey, protocol: 'openai'|'compatible', upstreamModel, defaultSize? }
 * 返回 [{ fileName, buffer }]，由调用方落盘。
 */
export async function callUpstream({ target, taskType, params }) {
  const isCompat = target.protocol === 'compatible';
  const timeout = config.upstreamTimeoutMs;

  if (taskType === 'generate') {
    const body = {
      model: target.upstreamModel,
      prompt: params.prompt,
      n: params.n || 1,
      size: params.size || target.defaultSize || '1024x1024',
    };
    // 仅标准 OpenAI Images 附带 quality/format；兼容/千问扩展不传，避免 400
    if (target.protocol === 'openai') {
      body.quality = 'auto';
      body.format = 'png';
      body.response_format = 'url';
    }
    return jsonGenerate(target, body, timeout);
  }

  // edit
  if (isCompat) {
    const imageUris = await Promise.all(
      (params.images || []).map(async (f) => toDataUri(f)),
    );
    const body = {
      model: target.upstreamModel,
      prompt: params.prompt,
      n: params.n || 1,
      size: params.size || target.defaultSize || '1024x1024',
      image: imageUris.length === 1 ? imageUris[0] : imageUris,
    };
    return jsonGenerate(target, body, timeout);
  }

  return multipartEdit(target, params, timeout);
}

async function jsonGenerate(target, body, timeout) {
  const url = joinUrl(target.baseUrl, '/v1/images/generations');
  logger.info(`POST ${url}`, { model: body.model, n: body.n, size: body.size });
  logger.info('请求体', body);
  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${target.apiKey}`,
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(timeout),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw upsertFail(res, json);
  }
  return downloadResults(json);
}

async function multipartEdit(target, params, timeout) {
  const url = joinUrl(target.baseUrl, '/v1/images/edits');
  const form = new FormData();
  form.append('prompt', params.prompt);
  form.append('model', target.upstreamModel);
  form.append('n', String(params.n || 1));
  form.append('size', params.size || target.defaultSize || '1024x1024');
  form.append('quality', 'auto');

  for (const f of params.images || []) {
    form.append('image', await toBlob(f), path.basename(f));
  }
  if (params.mask) {
    form.append('mask', await toBlob(params.mask), 'mask.png');
  }

  logger.info(`POST ${url} (multipart edit)`, { model: target.upstreamModel });
  const res = await fetch(url, {
    method: 'POST',
    headers: { Authorization: `Bearer ${target.apiKey}` },
    body: form,
    signal: AbortSignal.timeout(timeout),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw upsertFail(res, json);
  }
  return downloadResults(json);
}

async function downloadResults(json) {
  const items = Array.isArray(json?.data) ? json.data : [];
  if (items.length === 0) {
    // 兜底 choices
    const choices = Array.isArray(json?.choices) ? json.choices : [];
    const out = [];
    for (const c of choices) {
      const content = c?.message?.content;
      if (!content) continue;
      const buf = Buffer.from(content.replace(/^data:[^;]+;base64,/, ''), 'base64');
      out.push({ fileName: `${crypto.randomUUID()}.png`, buffer: buf });
    }
    if (out.length) return out;
    throw new Error(json?.error?.message || '上游未返回图片');
  }

  const out = [];
  for (const item of items) {
    if (item.b64_json) {
      out.push({
        fileName: `${crypto.randomUUID()}.png`,
        buffer: Buffer.from(item.b64_json, 'base64'),
      });
    } else if (item.url) {
      const res = await fetch(item.url, {
        signal: AbortSignal.timeout(config.upstreamTimeoutMs),
      });
      if (!res.ok) throw new Error(`下载结果图失败 HTTP ${res.status}`);
      const buf = Buffer.from(await res.arrayBuffer());
      out.push({ fileName: `${crypto.randomUUID()}.png`, buffer: buf });
    }
  }
  if (!out.length) throw new Error('上游未返回可用图片');
  return out;
}

/**
 * 拼上游地址：兼容 baseUrl 已带 /api/v1、/compatible-mode 等前缀的情况。
 * path 以 /v1/ 开头时，若 base 已以 /v1 结尾则不再重复拼。
 */
export function joinUrl(base, p) {
  const b = String(base).replace(/\/+$/, '');
  let path = p.startsWith('/') ? p : `/${p}`;
  if (/\/v1$/i.test(b) && path.startsWith('/v1/')) {
    path = path.slice(3); // 去掉开头 /v1
  }
  return `${b}${path}`;
}

async function resolveUpload(name) {
  // name: uploads 目录下的文件名
  const safe = path.basename(name);
  const p = path.join(config.uploadsDir, safe);
  if (!p.startsWith(config.uploadsDir)) throw new Error('非法路径');
  if (!fs.existsSync(p)) throw new Error(`上传文件不存在: ${safe}`);
  return p;
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
