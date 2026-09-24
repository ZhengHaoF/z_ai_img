import { getProfile } from './config.js';

/**
 * 从上游 GET /v1/models 拉取模型列表。
 * 拉不到时回退到 config.json 的 models（可能为空）。
 */
export async function fetchUpstreamModels(profileId) {
  const profile = getProfile(profileId);
  if (!profile) {
    return { models: [], source: 'none' };
  }
  if (!profile.hasKey) {
    return { models: [], source: 'none', error: '缺少 API Key' };
  }

  const url = `${profile.baseUrl.replace(/\/+$/, '')}/v1/models`;
  try {
    const res = await fetch(url, {
      headers: { Authorization: `Bearer ${profile.apiKey}` },
      signal: AbortSignal.timeout(15000),
    });
    const json = await res.json().catch(() => ({}));
    if (!res.ok) {
      throw new Error(json?.error?.message || `HTTP ${res.status}`);
    }

    const raw =
      json?.data ??
      json?.models ??
      (Array.isArray(json?.object) ? json.object : null) ??
      [];

    const models = [];
    for (const item of raw) {
      const id = typeof item === 'string' ? item : item?.id || item?.model || item?.name;
      if (typeof id === 'string' && id.trim()) models.push(id.trim());
    }

    // 去重保序
    const unique = [...new Set(models)];
    if (unique.length === 0 && Array.isArray(profile.models)) {
      return { models: profile.models, source: 'config' };
    }
    return { models: unique, source: 'upstream' };
  } catch (e) {
    const fallback = Array.isArray(profile.models) ? profile.models : [];
    return {
      models: fallback,
      source: 'config',
      error: e.message || String(e),
    };
  }
}
