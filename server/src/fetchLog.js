import { logger } from './logBus.js';

/** 把 undici/fetch 的 TypeError: fetch failed 拆成可诊断字段。 */
export function describeFetchError(err) {
  const cause = err?.cause;
  const pick = (o, keys) => {
    const out = {};
    if (!o || typeof o !== 'object') return out;
    for (const k of keys) {
      if (o[k] !== undefined && o[k] !== null && o[k] !== '') out[k] = o[k];
    }
    return out;
  };
  const keys = [
    'code',
    'errno',
    'syscall',
    'address',
    'port',
    'hostname',
    'library',
    'reason',
  ];
  return {
    name: err?.name,
    message: err?.message,
    ...pick(err, keys),
    causeName: cause?.name,
    causeMessage: cause?.message,
    ...Object.fromEntries(
      Object.entries(pick(cause, keys)).map(([k, v]) => [`cause_${k}`, v]),
    ),
  };
}

/** fetch 包装：失败时把 URL 与底层错误完整打进日志，再原样抛出。 */
export async function fetchLogged(url, options = {}) {
  const method = options.method || 'GET';
  try {
    return await fetch(url, options);
  } catch (err) {
    logger.error(`fetch failed ${method} ${url}`, describeFetchError(err));
    throw err;
  }
}
