/**
 * 任务事件总线：db 层状态变更 → WS 广播。
 * 与 logBus 同构（Set 订阅），无外部依赖，避免与 db.js 循环引用。
 */
const listeners = new Set();

/** 事件：{ type: 'task', task } | { type: 'task:removed', id } */
export function onTaskEvent(fn) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

export function emitTaskEvent(event) {
  for (const fn of listeners) {
    try {
      fn(event);
    } catch {
      /* ignore */
    }
  }
}

export function emitTask(task) {
  emitTaskEvent({ type: 'task', task });
}

export function emitTaskRemoved(id) {
  emitTaskEvent({ type: 'task:removed', id });
}
