<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref, watch } from 'vue';
import { Trash2, RefreshCw } from 'lucide-vue-next';
import {
  deleteGalleryImage,
  fetchGallery,
  type GalleryImage,
} from '../api/client';
import { tasks as storeTasks } from '../api/taskEvents';
import Lightbox from '../components/Lightbox.vue';

const images = ref<GalleryImage[]>([]);
const error = ref('');
const loading = ref(false);
const lightboxIndex = ref(-1);

/** 删除确认弹窗 */
const confirmVisible = ref(false);
const confirmTitle = ref('');
const confirmMessage = ref('');
const removing = ref(false);
let confirmAction: (() => Promise<void>) | null = null;

function askConfirm(title: string, message: string, action: () => Promise<void>) {
  confirmTitle.value = title;
  confirmMessage.value = message;
  confirmAction = action;
  confirmVisible.value = true;
}

function onOverlayClick() {
  if (!removing.value) confirmVisible.value = false;
}

async function onConfirmYes() {
  const fn = confirmAction;
  if (!fn || removing.value) return;
  removing.value = true;
  try {
    await fn();
    confirmVisible.value = false;
    confirmAction = null;
    await load();
  } catch (e) {
    // 失败保留弹窗，用户可重试或取消
    error.value = (e as Error).message;
  } finally {
    removing.value = false;
  }
}

/**
 * 实时刷新：任务出图 / 任务被删时静默重载图库。
 * 签名 = 成功任务的 id+图片数，覆盖 WS 推送与降级轮询两条路径。
 */
const imgSignature = computed(() =>
  storeTasks.value
    .filter((t) => t.status === 'succeeded')
    .map((t) => `${t.id}:${t.images.length}`)
    .join('|'),
);
let reloadTimer: number | null = null;

function scheduleReload() {
  if (removing.value) return; // 删除中避免和本地乐观更新打架
  if (reloadTimer != null) window.clearTimeout(reloadTimer);
  reloadTimer = window.setTimeout(() => {
    reloadTimer = null;
    void load({ quiet: true });
  }, 400);
}

watch(imgSignature, scheduleReload);

async function load(opts?: { quiet?: boolean }) {
  if (!opts?.quiet) loading.value = true;
  error.value = '';
  try {
    const data = await fetchGallery();
    images.value = data.images;
  } catch (e) {
    if (!opts?.quiet) error.value = (e as Error).message;
  } finally {
    if (!opts?.quiet) loading.value = false;
  }
}

function onDelete(img: GalleryImage) {
  askConfirm(
    '删除图片',
    `确定删除这张图吗？\n${img.prompt ? img.prompt.slice(0, 40) : img.fileName}`,
    async () => {
      await deleteGalleryImage(img.fileName);
    },
  );
}

function fmtTime(ts: number) {
  return new Date(ts).toLocaleString('zh-CN', { hour12: false });
}

onMounted(load);
onBeforeUnmount(() => {
  if (reloadTimer != null) window.clearTimeout(reloadTimer);
});
</script>

<template>
  <div class="card">
    <div class="row" style="align-items: center; margin-bottom: 0.75rem">
      <h2 style="margin: 0; flex: 1">图库</h2>
      <span class="muted">{{ images.length }} 张</span>
      <button :disabled="loading" @click="load()">
        <RefreshCw :size="14" style="vertical-align: -2px" />
        {{ loading ? '加载中…' : '刷新' }}
      </button>
    </div>
    <p class="muted">进入页面自动加载服务端已保存的生成结果，可点击看大图、删除。</p>
    <p v-if="error" class="error">{{ error }}</p>
    <p v-if="!images.length && !loading" class="muted">暂无图片</p>

    <div class="grid">
      <div v-for="(img, i) in images" :key="img.fileName" class="cell">
        <img :src="img.url" :alt="img.prompt" @click="lightboxIndex = i" />
        <div class="bar">
          <span class="muted">{{ fmtTime(img.createdAt) }}</span>
          <button class="icon-del" title="删除这张图" @click="onDelete(img)">
            <Trash2 :size="14" />
          </button>
        </div>
      </div>
    </div>
  </div>

  <Lightbox
    v-if="lightboxIndex >= 0"
    :images="images.map((x) => x.url)"
    :index="lightboxIndex"
    @close="lightboxIndex = -1"
    @update:index="lightboxIndex = $event"
  />

  <div v-if="confirmVisible" class="overlay" @click.self="onOverlayClick">
    <div class="dialog">
      <h3 style="margin-top: 0">{{ confirmTitle }}</h3>
      <p class="muted" style="white-space: pre-line">{{ confirmMessage }}</p>
      <div class="row">
        <button class="danger primary" :disabled="removing" @click="onConfirmYes">
          {{ removing ? '删除中…' : '删除' }}
        </button>
        <button :disabled="removing" @click="confirmVisible = false">取消</button>
      </div>
    </div>
  </div>
</template>

<style scoped>
.grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(150px, 1fr));
  gap: 0.75rem;
}
@media (max-width: 640px) {
  .grid {
    grid-template-columns: repeat(2, 1fr);
    gap: 0.55rem;
  }
}
.cell {
  border: 1px solid var(--line);
  border-radius: 10px;
  overflow: hidden;
  background: var(--bg);
}
.cell img {
  width: 100%;
  aspect-ratio: 1;
  object-fit: cover;
  display: block;
  cursor: zoom-in;
}
.bar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 0.35rem 0.45rem;
  font-size: 0.75rem;
}
.icon-del {
  border: none;
  background: transparent;
  color: var(--danger);
  padding: 0.2rem;
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
