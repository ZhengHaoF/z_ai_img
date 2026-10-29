<script setup lang="ts">
import { computed, onMounted, ref } from 'vue';
import { deleteTask } from '../api/client';
import { refreshTasks, tasks as storeTasks } from '../api/taskEvents';
import type { Task } from '../types';
import Lightbox from '../components/Lightbox.vue';

/** 列表由全局 store 驱动（WS 实时推送 + 断线降级轮询），「刷新」手动全量同步 */
const tasks = storeTasks;
const error = ref('');
const loading = ref(false);
const lightboxImages = ref<string[]>([]);
const lightboxIndex = ref(-1);
const copiedId = ref('');

/** 删除确认弹窗 */
const confirmVisible = ref(false);
const confirmTask = ref<Task | null>(null);
const removing = ref(false);
const confirmError = ref('');

const confirmMessage = computed(() => {
  const t = confirmTask.value;
  if (!t) return '';
  const prompt = t.params?.prompt ? t.params.prompt.slice(0, 40) : '';
  const n = t.images?.length || 0;
  return `确定删除该任务吗？\n${prompt}\n任务下 ${n} 张结果图将一并删除，不可恢复。`;
});

function isTaskLive(t: Task) {
  return t.status === 'queued' || t.status === 'running';
}

function askDelete(t: Task) {
  if (isTaskLive(t)) return;
  confirmTask.value = t;
  confirmError.value = '';
  confirmVisible.value = true;
}

function closeConfirm() {
  if (removing.value) return;
  confirmVisible.value = false;
  confirmTask.value = null;
}

async function onConfirmDelete() {
  const t = confirmTask.value;
  if (!t || removing.value) return;
  removing.value = true;
  confirmError.value = '';
  try {
    await deleteTask(t.id);
    confirmVisible.value = false;
    confirmTask.value = null;
    tasks.value = tasks.value.filter((x) => x.id !== t.id);
  } catch (e) {
    // 失败保留弹窗展示原因（例如任务进行中需先取消）
    confirmError.value = (e as Error).message;
  } finally {
    removing.value = false;
  }
}

function openLightbox(images: string[], index: number) {
  lightboxImages.value = images;
  lightboxIndex.value = index;
}

async function copyPrompt(t: Task) {
  const text = t.params?.prompt || '';
  if (!text) return;
  try {
    await navigator.clipboard.writeText(text);
  } catch {
    const ta = document.createElement('textarea');
    ta.value = text;
    ta.style.position = 'fixed';
    ta.style.left = '-9999px';
    document.body.appendChild(ta);
    ta.select();
    document.execCommand('copy');
    document.body.removeChild(ta);
  }
  copiedId.value = t.id;
  window.setTimeout(() => {
    if (copiedId.value === t.id) copiedId.value = '';
  }, 1500);
}

async function load() {
  if (loading.value) return;
  loading.value = true;
  error.value = '';
  try {
    await refreshTasks();
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    loading.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="card">
    <div class="toolbar">
      <h2>最近任务</h2>
      <button :disabled="loading" @click="load">{{ loading ? '加载中…' : '刷新' }}</button>
    </div>
    <p v-if="error" class="error">{{ error }}</p>
    <p v-if="loading && !tasks.length" class="muted">加载中…</p>
    <p v-if="!tasks.length && !loading" class="muted">暂无任务</p>
    <div v-for="t in tasks" :key="t.id" class="task">
      <div class="task-head">
        <strong>{{ t.params.prompt }}</strong>
        <div class="tags">
          <span class="tag">{{ t.type === 'generate' ? '文生图' : '图编辑' }}</span>
          <span class="tag">{{ t.status }}</span>
          <button
            type="button"
            class="ghost"
            :disabled="!t.params?.prompt"
            @click="copyPrompt(t)"
          >
            {{ copiedId === t.id ? '已复制' : '复制提示词' }}
          </button>
          <button
            type="button"
            class="ghost"
            :disabled="isTaskLive(t)"
            :title="isTaskLive(t) ? '任务进行中，请先取消后再删除' : '删除任务及其结果图'"
            @click="askDelete(t)"
          >
            删除
          </button>
        </div>
      </div>
      <p class="muted" style="margin: 0.35rem 0">
        {{ new Date(t.createdAt).toLocaleString() }}
        <template v-if="t.error && t.status === 'failed'"> · <span class="error">{{ t.error }}</span></template>
      </p>
      <div v-if="t.images?.length" class="grid">
        <div
          v-for="(img, i) in t.images"
          :key="img"
          class="thumb"
        >
          <img
            :src="img"
            alt=""
            loading="lazy"
            decoding="async"
            style="cursor: zoom-in"
            @click="openLightbox(t.images, i)"
          />
        </div>
      </div>
    </div>
  </div>

  <Lightbox
    v-if="lightboxIndex >= 0"
    :images="lightboxImages"
    :index="lightboxIndex"
    @close="lightboxIndex = -1"
    @update:index="lightboxIndex = $event"
  />

  <div v-if="confirmVisible" class="overlay" @click.self="closeConfirm">
    <div class="dialog">
      <h3 style="margin-top: 0">删除任务</h3>
      <p class="muted" style="white-space: pre-line">{{ confirmMessage }}</p>
      <p v-if="confirmError" class="error">{{ confirmError }}</p>
      <div class="row">
        <button class="danger primary" :disabled="removing" @click="onConfirmDelete">
          {{ removing ? '删除中…' : '删除' }}
        </button>
        <button :disabled="removing" @click="closeConfirm">取消</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 0.8rem;
}
.toolbar h2 {
  margin: 0;
  font-size: 1.15rem;
}
.task {
  border-top: 1px solid var(--line);
  padding: 0.75rem 0;
}
.task-head {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.4rem;
}
.task-head strong {
  flex: 1 1 12rem;
  min-width: 0;
  word-break: break-all;
}
.tags {
  display: flex;
  gap: 0.35rem;
  flex-shrink: 0;
}
.overlay {
  position: fixed;
  inset: 0;
  z-index: 200;
  background: rgba(0, 0, 0, 0.45);
  display: flex;
  align-items: center;
  justify-content: center;
}
.dialog {
  background: var(--panel);
  border: 1px solid var(--line);
  border-radius: 14px;
  padding: 1.25rem 1.4rem;
  width: min(360px, 92vw);
}
</style>
