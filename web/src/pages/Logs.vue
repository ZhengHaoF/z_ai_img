<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { Trash2, Pause, Play, Download } from 'lucide-vue-next';

interface LogEntry {
  ts: number;
  level: string;
  msg: string;
  meta?: unknown;
}

const logs = ref<LogEntry[]>([]);
const connected = ref(false);
const paused = ref(false);
const follow = ref(true);
const filter = ref('');
const levelFilter = ref('all');
let ws: WebSocket | null = null;
let pending: LogEntry[] = [];

function levelClass(level: string) {
  if (level === 'error') return 'lv-error';
  if (level === 'warn') return 'lv-warn';
  if (level === 'debug') return 'lv-debug';
  return 'lv-info';
}

function fmtTime(ts: number) {
  const d = new Date(ts);
  return d.toLocaleTimeString('zh-CN', { hour12: false });
}

function push(entry: LogEntry) {
  if (paused.value) {
    pending.push(entry);
    return;
  }
  logs.value.push(entry);
  if (logs.value.length > 2000) logs.value.splice(0, logs.value.length - 2000);
}

function connect() {
  const proto = location.protocol === 'https:' ? 'wss' : 'ws';
  ws = new WebSocket(`${proto}://${location.host}/ws/logs`);
  ws.onopen = () => {
    connected.value = true;
  };
  ws.onclose = () => {
    connected.value = false;
    setTimeout(connect, 3000);
  };
  ws.onerror = () => {
    ws?.close();
  };
  ws.onmessage = (ev) => {
    try {
      const data = JSON.parse(ev.data);
      if (data.type === 'snapshot') {
        logs.value = data.logs || [];
      } else if (data.type === 'log' && data.log) {
        push(data.log);
      }
    } catch {
      /* ignore */
    }
  };
}

function togglePause() {
  paused.value = !paused.value;
  if (!paused.value && pending.length) {
    logs.value.push(...pending);
    pending = [];
  }
}

function clearLogs() {
  logs.value = [];
  pending = [];
}

function downloadLogs() {
  const text = filtered.value
    .map((l) => `${new Date(l.ts).toISOString()} [${l.level}] ${l.msg}`)
    .join('\n');
  const blob = new Blob([text], { type: 'text/plain' });
  const a = document.createElement('a');
  a.href = URL.createObjectURL(blob);
  a.download = `z-ai-logs-${Date.now()}.txt`;
  a.click();
  URL.revokeObjectURL(a.href);
}

const filtered = ref<LogEntry[]>([]);
const listEl = ref<HTMLElement | null>(null);

function recomputeFilter() {
  const q = filter.value.trim().toLowerCase();
  filtered.value = logs.value.filter((l) => {
    if (levelFilter.value !== 'all' && l.level !== levelFilter.value) return false;
    if (!q) return true;
    return l.msg.toLowerCase().includes(q);
  });
}

watch([logs, filter, levelFilter], recomputeFilter, { deep: true });

watch(
  () => filtered.value.length,
  () => {
    if (follow.value && listEl.value) {
      listEl.value.scrollTop = listEl.value.scrollHeight;
    }
  },
);

onMounted(connect);
onBeforeUnmount(() => {
  ws?.close();
  ws = null;
});
</script>

<template>
  <div class="card">
    <div class="row" style="align-items: center; margin-bottom: 0.75rem">
      <h2 style="margin: 0; flex: 1">
        后端日志
        <span class="tag">{{ connected ? '已连接' : '重连中…' }}</span>
      </h2>
      <button @click="togglePause">
        <Pause v-if="!paused" :size="14" style="vertical-align: -2px" />
        <Play v-else :size="14" style="vertical-align: -2px" />
        {{ paused ? '继续' : '暂停' }}
      </button>
      <label class="muted" style="display: flex; align-items: center; gap: 0.3rem">
        <input v-model="follow" type="checkbox" /> 跟随
      </label>
      <button @click="downloadLogs"><Download :size="14" style="vertical-align: -2px" /> 导出</button>
      <button class="danger" @click="clearLogs"><Trash2 :size="14" style="vertical-align: -2px" /> 清空</button>
    </div>

    <div class="row" style="margin-bottom: 0.6rem">
      <input v-model="filter" placeholder="过滤关键字…" />
      <select v-model="levelFilter">
        <option value="all">全部级别</option>
        <option value="debug">debug</option>
        <option value="info">info</option>
        <option value="warn">warn</option>
        <option value="error">error</option>
      </select>
    </div>

    <div ref="listEl" class="log-list">
      <div v-for="(l, i) in filtered" :key="i" class="log-line" :class="levelClass(l.level)">
        <span class="t">{{ fmtTime(l.ts) }}</span>
        <span class="lv">{{ l.level }}</span>
        <span class="m">{{ l.msg }}</span>
      </div>
      <p v-if="!filtered.length" class="muted">暂无日志</p>
    </div>
  </div>
</template>

<style scoped>
.log-list {
  height: 420px;
  max-height: 55vh;
  overflow: auto;
  background: var(--bg);
  border: 1px solid var(--line);
  border-radius: 10px;
  padding: 0.5rem 0.65rem;
  font-family: ui-monospace, Consolas, monospace;
  font-size: 0.78rem;
  line-height: 1.45;
}
@media (max-width: 640px) {
  .log-list {
    height: 50vh;
    font-size: 0.72rem;
  }
  .log-line .lv {
    flex-basis: 2.6rem;
  }
}
.log-line {
  display: flex;
  gap: 0.5rem;
  white-space: pre-wrap;
  word-break: break-all;
}
.log-line .t {
  color: var(--muted);
  flex: 0 0 auto;
}
.log-line .lv {
  flex: 0 0 3.2rem;
  text-transform: uppercase;
  font-size: 0.7rem;
  opacity: 0.8;
}
.log-line .m {
  flex: 1;
}
.lv-error {
  color: var(--danger);
}
.lv-warn {
  color: #b45309;
}
.lv-debug {
  color: var(--muted);
}
.lv-info {
  color: var(--ink);
}
input[type='checkbox'] {
  width: auto;
}
</style>
