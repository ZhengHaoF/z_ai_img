import crypto from 'node:crypto';
import {
  deleteModel,
  findModelByUpstream,
  getModelRow,
  insertModel,
  listModelRows,
  updateModel,
} from './db.js';
import { fetchLogged } from './fetchLog.js';

/** 前端可见字段（不含 api_key）。 */
function toPublic(row) {
  if (!row) return null;
  return {
    id: row.id,
    label: row.label,
    baseUrl: row.base_url,
    protocol: row.protocol,
    upstreamModel: row.upstream_model,
    enabled: Boolean(row.enabled),
    hasKey: Boolean(row.api_key),
  };
}

function normalizeProtocol(p) {
  if (p === 'compatible') return 'compatible';
  if (p === 'dashscope') return 'dashscope';
  if (p === 'uuapi') return 'uuapi';
  return 'openai';
}

export function listModels({ enabledOnly = false } = {}) {
  return listModelRows({ enabledOnly }).map(toPublic);
}

export function getModel(id) {
  return toPublic(getModelRow(id));
}

export function createModel({
  label,
  baseUrl,
  protocol,
  upstreamModel,
  apiKey,
  enabled = true,
}) {
  if (!baseUrl?.trim()) throw new Error('baseUrl 不能为空');
  if (!upstreamModel?.trim()) throw new Error('upstreamModel 不能为空');
  const id = crypto.randomUUID();
  insertModel({
    id,
    label: (label || upstreamModel).trim(),
    baseUrl: baseUrl.trim().replace(/\/+$/, ''),
    protocol: normalizeProtocol(protocol),
    upstreamModel: upstreamModel.trim(),
    apiKey: apiKey ?? '',
    enabled,
  });
  return getModel(id);
}

export function patchModel(id, fields) {
  const row = getModelRow(id);
  if (!row) throw new Error('模型不存在');
  const next = { ...fields };
  if (next.protocol !== undefined) next.protocol = normalizeProtocol(next.protocol);
  if (next.baseUrl !== undefined) {
    if (!String(next.baseUrl).trim()) throw new Error('baseUrl 不能为空');
    next.baseUrl = String(next.baseUrl).trim().replace(/\/+$/, '');
  }
  // apiKey 空字符串表示「不修改」
  if (next.apiKey === '') delete next.apiKey;
  updateModel(id, next);
  return getModel(id);
}

export function removeModel(id) {
  if (!getModelRow(id)) throw new Error('模型不存在');
  deleteModel(id);
}

/** 解析 modelId → 执行任务所需的上游连接信息（含 apiKey，仅服务端使用）。 */
export function resolveModel(modelId) {
  const row = getModelRow(modelId);
  if (!row) throw new Error('模型不存在或已删除');
  if (!row.enabled) throw new Error('模型已停用');
  return {
    modelId: row.id,
    label: row.label,
    target: {
      baseUrl: row.base_url,
      apiKey: row.api_key || '',
      protocol: normalizeProtocol(row.protocol),
      upstreamModel: row.upstream_model,
      defaultSize: '1024x1024',
    },
  };
}

/** 从任意上游 GET /v1/models 拉列表（用于同步/添加）。 */
export async function listRemoteModels({ baseUrl, apiKey }) {
  if (!baseUrl?.trim()) throw new Error('baseUrl 不能为空');
  let b = baseUrl.trim().replace(/\/+$/, '');
  // 已带 /v1 或 /api/v1 /compatible-mode 时避免再拼 /v1
  let url;
  if (/\/(api\/)?v1$/i.test(b)) {
    url = `${b}/models`;
  } else if (/\/compatible-mode$/i.test(b)) {
    url = `${b}/v1/models`;
  } else {
    url = `${b}/v1/models`;
  }
  const res = await fetchLogged(url, {
    headers: apiKey ? { Authorization: `Bearer ${apiKey}` } : {},
    signal: AbortSignal.timeout(15000),
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error(json?.error?.message || `上游错误 HTTP ${res.status}`);
  }
  const raw = json?.data ?? json?.models ?? [];
  const models = [];
  for (const item of raw) {
    const id = typeof item === 'string' ? item : item?.id || item?.model || item?.name;
    if (typeof id === 'string' && id.trim()) models.push(id.trim());
  }
  return [...new Set(models)];
}

/** 把远程模型批量写入注册表（默认启用，已存在跳过）。 */
export async function syncModelsFromUrl({ baseUrl, apiKey, protocol, enabled = true }) {
  const names = await listRemoteModels({ baseUrl, apiKey });
  const added = [];
  const skipped = [];
  for (const name of names) {
    const b = String(baseUrl).trim().replace(/\/+$/, '');
    if (findModelByUpstream(b, name)) {
      skipped.push({ upstreamModel: name, reason: 'exists' });
      continue;
    }
    added.push(
      createModel({
        label: name,
        baseUrl: b,
        protocol,
        upstreamModel: name,
        apiKey: apiKey ?? '',
        enabled,
      }),
    );
  }
  return { added, skipped, models: listModels() };
}
