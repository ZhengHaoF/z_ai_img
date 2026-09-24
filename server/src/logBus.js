const listeners = new Set();
const buffer = [];
const MAX_BUFFER = 500;

export function log(level, msg, meta) {
  const entry = {
    ts: Date.now(),
    level,
    msg: String(msg),
    meta: meta ?? null,
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
