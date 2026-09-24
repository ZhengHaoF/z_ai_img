import { config } from './config.js';
import { logger } from './logBus.js';
import { fetchLogged } from './fetchLog.js';

const TASKS_PATH = '/tasks';

/**
 * DashScope 基址固定为 {origin}/api/v1。
 * 用户误填 …/compatible-mode 或少 /api/v1 时自动纠正，避免 404。
 */
function dashScopeRoot(baseUrl) {
  try {
    const u = new URL(String(baseUrl).trim());
    return `${u.origin}/api/v1`;
  } catch {
    return String(baseUrl).replace(/\/+$/, '');
  }
}

function joinUrl(base, p) {
  const b = String(base).replace(/\/+$/, '');
  let path = p.startsWith('/') ? p : `/${p}`;
  if (/\/api\/v1$/i.test(b) && path.startsWith('/api/v1/')) {
    path = path.slice('/api/v1'.length);
  }
  return `${b}${path}`;
}

function authHeaders(apiKey) {
  return {
    Authorization: `Bearer ${apiKey}`,
    'Content-Type': 'application/json',
  };
}

/** OpenAI size `1024x1024` → DashScope `1024*1024` */
function toDashSize(size) {
  if (!size || size === 'auto') return undefined;
  return String(size).replace(/\s*[xX×]\s*/, '*');
}

/**
 * 提交 DashScope 异步文生图，返回 { remoteTaskId, taskStatus }。
 * body: model / prompt / n / size
 */
export async function submitDashScopeAsync({ target, params }) {
  const root = dashScopeRoot(target.baseUrl);
  const url = joinUrl(root, '/services/aigc/image-generation/generation');
  const body = {
    model: target.upstreamModel,
    input: {
      messages: [
        {
          role: 'user',
          content: [{ text: params.prompt }],
        },
      ],
    },
    parameters: {
      n: Math.min(Math.max(Number(params.n) || 1, 1), 6),
      prompt_extend: true,
    },
  };
  const size = toDashSize(params.size);
  if (size) body.parameters.size = size;

  logger.info(`POST ${url} (DashScope async)`, { model: target.upstreamModel });
  logger.debug('DashScope 请求体', body);
  const res = await fetchLogged(url, {
    method: 'POST',
    headers: {
      ...authHeaders(target.apiKey),
      'X-DashScope-Async': 'enable',
    },
    body: JSON.stringify(body),
    signal: AbortSignal.timeout(config.upstreamTimeoutMs),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    const detail = json?.message || json?.msg || json?.code || null;
    logger.error(`DashScope HTTP ${res.status}`, {
      detail,
      body: JSON.stringify(json || {}).slice(0, 500),
    });
    throw new Error(
      detail
        ? `DashScope ${res.status}: ${detail}`
        : `DashScope 上游错误 HTTP ${res.status} ${JSON.stringify(json).slice(0, 300)}`,
    );
  }
  const remoteTaskId = json?.output?.task_id;
  if (!remoteTaskId) {
    throw new Error(json?.message || '上游未返回 task_id');
  }
  return {
    remoteTaskId,
    taskStatus: json?.output?.task_status || 'PENDING',
  };
}

/**
 * 查询 DashScope 任务。
 * 返回 { status: 'running'|'succeeded'|'failed'|'canceled', urls?, error? }
 */
export async function queryDashScopeAsync({ target, remoteTaskId }) {
  const root = dashScopeRoot(target.baseUrl);
  const url = joinUrl(root, `${TASKS_PATH}/${remoteTaskId}`);
  logger.debug(`GET ${url}`);
  const res = await fetchLogged(url, {
    headers: authHeaders(target.apiKey),
    signal: AbortSignal.timeout(30000),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(json?.message || `查询任务失败 HTTP ${res.status}`);
  }
  const out = json?.output || {};
  const st = String(out.task_status || 'UNKNOWN').toUpperCase();
  logger.debug(`DashScope 响应 task_status=${st}`, {
    raw: JSON.stringify(json).slice(0, 1500),
  });

  if (st === 'SUCCEEDED') {
    const urls = extractUrls(out);
    if (!urls.length) {
      logger.error('SUCCEEDED 但未解析到图片', {
        raw: JSON.stringify(json).slice(0, 1500),
      });
      return { status: 'failed', error: '任务成功但无图片 URL（详见日志 raw）' };
    }
    return { status: 'succeeded', urls };
  }
  if (st === 'FAILED') {
    return { status: 'failed', error: out.message || out.code || '上游任务失败' };
  }
  if (st === 'CANCELED') {
    return { status: 'canceled', error: '上游任务已取消' };
  }
  return { status: 'running' };
}

/** 兼容多种结果形态：results[].url / choices[].message.content[].image */
function extractUrls(out) {
  const urls = [];
  for (const r of out.results || []) {
    if (typeof r?.url === 'string' && r.url) urls.push(r.url);
    if (typeof r?.image === 'string' && r.image) urls.push(r.image);
  }
  for (const c of out.choices || []) {
    const content = c?.message?.content;
    if (typeof content === 'string' && content.startsWith('http')) {
      urls.push(content);
      continue;
    }
    if (!Array.isArray(content)) continue;
    for (const part of content) {
      const u = part?.image || part?.url;
      if (typeof u === 'string' && u) urls.push(u);
    }
  }
  return [...new Set(urls)];
}

export async function downloadUrlToBuffer(url) {
  const res = await fetchLogged(url, {
    signal: AbortSignal.timeout(config.upstreamTimeoutMs),
  });
  if (!res.ok) throw new Error(`下载结果图失败 HTTP ${res.status}`);
  return Buffer.from(await res.arrayBuffer());
}
