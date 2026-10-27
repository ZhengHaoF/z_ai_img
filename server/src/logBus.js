const listeners = new Set();
const buffer = [];
const MAX_BUFFER = 500;
/** 单条日志上限：msg 2KB、meta 序列化 2KB，超出截断（防止 base64/大对象把 WS 快照撑爆） */
const MAX_MSG = 2048;
const MAX_META = 2048;

function clamp(str, max) {
  return str.length > max ? `${str.slice(0, max)}…(已截断,共${str.length}字符)` : str;
}

export function log(level, msg, meta) {
  let metaOut = meta ?? null;
  if (metaOut != null) {
    let s;
    try {
      s = JSON.stringify(metaOut);
    } catch {
      s = '[unserializable]';
    }
    if (s.length > MAX_META) {
      metaOut = { truncated: true, preview: clamp(s, MAX_META) };
    }
  }
  const entry = {
    ts: Date.now(),
    level,
    msg: clamp(String(msg), MAX_MSG),
    meta: metaOut,
  };
  buffer.push(entry);
  if (buffer.length > MAX_BUFFER) buffer.shift();
  for (const fn of listeners) {
    try {
      fn(entry);
    } catch {
      /* ignore */
    }
  }
  return entry;
}

export function onLog(fn) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

export function getLogBuffer() {
  return buffer.slice();
}

/** 包装 console，把后端打印汇入日志流。 */
export function hookConsole() {
  const wrap = (level, original) => {
    return (...args) => {
      original(...args);
      const msg = args
        .map((a) => {
          if (typeof a === 'string') return a;
          try {
            return JSON.stringify(a);
          } catch {
            return String(a);
          }
        })
        .join(' ');
      log(level, msg);
    };
  };
  console.log = wrap('info', console.log.bind(console));
  console.warn = wrap('warn', console.warn.bind(console));
  console.error = wrap('error', console.error.bind(console));
  console.info = wrap('info', console.info.bind(console));
}

export const logger = {
  info: (msg, meta) => log('info', msg, meta),
  warn: (msg, meta) => log('warn', msg, meta),
  error: (msg, meta) => log('error', msg, meta),
  debug: (msg, meta) => log('debug', msg, meta),
};
