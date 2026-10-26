import { computed, ref } from 'vue';
import type { Task } from '../types';
import { fetchTasks } from './client';

/**
 * 任务事件 store：WS 实时推送 + 断线慢速降级轮询。
 * module-level ref（本项目无 Pinia），App / Tasks / Generate / Edit / Gallery 共用。
 */

export const tasks = ref<Task[]>([]);
export const wsConnected = ref(false);

export const activeCount = computed(
  () => tasks.value.filter((t) => t.status === 'queued' || t.status === 'running').length,
);

const RECONNECT_MS = 3000;
const FALLBACK_MS = 15000;

let ws: WebSocket | null = null;
let started = false;
let reconnectTimer: number | null = null;
let fallbackTimer: number | null = null;

function upsertTask(t: Task) {
  const i = tasks.value.findIndex((x) => x.id === t.id);
  if (i >= 0) tasks.value[i] = t;
  else tasks.value.unshift(t);
}

function removeTask(id: string) {
  tasks.value = tasks.value.filter((x) => x.id !== id);
}

/** 把一份已知最新的任务合并进 store（提交/取消/单查后用，WS 断开时保证 UI 立即更新）。 */
export function applyTask(t: Task) {
  upsertTask(t);
}

/** 手动全量刷新（任务页「刷新」按钮）。 */
export async function refreshTasks() {
  const data = await fetchTasks({ silent: true });
  tasks.value = data.tasks;
}

async function fallbackRefresh() {
  try {
    await refreshTasks();
  } catch {
    /* 未登录或瞬时失败忽略 */
  }
}

function startFallback() {
  if (fallbackTimer != null) return;
  void fallbackRefresh();
  fallbackTimer = window.setInterval(() => {
    void fallbackRefresh();
  }, FALLBACK_MS);
}

function stopFallback() {
  if (fallbackTimer != null) {
    window.clearInterval(fallbackTimer);
    fallbackTimer = null;
  }
}

function connect() {
  if (!started) return;
  const proto = location.protocol === 'https:' ? 'wss' : 'ws';
  ws = new WebSocket(`${proto}://${location.host}/ws/app`);
  ws.onopen = () => {
    wsConnected.value = true;
    stopFallback();
  };
  ws.onclose = () => {
    wsConnected.value = false;
    ws = null;
    if (!started) return;
    // 断线期间走 15s 慢速轮询兜底，重连成功即停
    startFallback();
    reconnectTimer = window.setTimeout(connect, RECONNECT_MS);
  };
  ws.onerror = () => {
    ws?.close();
  };
  ws.onmessage = (ev) => {
    try {
      const data = JSON.parse(ev.data as string);
      if (data.type === 'tasks:snapshot') {
        tasks.value = data.tasks || [];
      } else if (data.type === 'task' && data.task) {
        upsertTask(data.task);
      } else if (data.type === 'task:removed' && data.id) {
        removeTask(data.id);
      }
      // 'snapshot' / 'log' 是日志通道消息，这里忽略
    } catch {
      /* ignore */
    }
  };
}

/** 登录后启动（幂等）。 */
export function startTaskEvents() {
  if (started) return;
  started = true;
  connect();
}

/** 登出时停止并清空。 */
export function stopTaskEvents() {
  started = false;
  stopFallback();
  if (reconnectTimer != null) {
    window.clearTimeout(reconnectTimer);
    reconnectTimer = null;
  }
  ws?.close();
  ws = null;
  wsConnected.value = false;
  tasks.value = [];
}
