<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { fetchTasks } from '../api/client';
import type { Task } from '../types';
import Lightbox from '../components/Lightbox.vue';

const tasks = ref<Task[]>([]);
const error = ref('');
const lightboxImages = ref<string[]>([]);
const lightboxIndex = ref(-1);

function openLightbox(images: string[], index: number) {
  lightboxImages.value = images;
  lightboxIndex.value = index;
}

async function load() {
  try {
    const data = await fetchTasks();
    tasks.value = data.tasks;
  } catch (e) {
    error.value = (e as Error).message;
  }
}

onMounted(load);
</script>

<template>
  <div class="card">
    <div class="toolbar">
      <h2>最近任务</h2>
      <button @click="load">刷新</button>
    </div>
    <p v-if="error" class="error">{{ error }}</p>
    <p v-if="!tasks.length" class="muted">暂无任务</p>
    <div v-for="t in tasks" :key="t.id" class="task">
      <div class="task-head">
        <strong>{{ t.params.prompt.slice(0, 40) }}</strong>
        <div class="tags">
          <span class="tag">{{ t.type === 'generate' ? '文生图' : '图编辑' }}</span>
          <span class="tag">{{ t.status }}</span>
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
</style>
