<script setup lang="ts">
import { computed, onBeforeUnmount, ref } from 'vue';
import { X } from 'lucide-vue-next';
import { cancelTask, fetchTask, submitTask, uploadFiles } from '../api/client';
import type { ModelItem, Task } from '../types';
import Lightbox from '../components/Lightbox.vue';
import ModelSelect from '../components/ModelSelect.vue';

const prompt = ref('');
const modelId = ref('');
const modelInfo = ref<ModelItem | null>(null);
const size = ref('1024x1024');
const n = ref(1);
const files = ref<File[]>([]);
/** 本地缩略图 objectURL；禁止在模板里调 URL.createObjectURL（会打崩渲染）。 */
const previews = ref<string[]>([]);
const uploaded = ref<string[]>([]);
const busy = ref(false);
const uploading = ref(false);
const error = ref('');
const task = ref<Task | null>(null);
const lightboxIndex = ref(-1);
const lightboxImages = ref<string[]>([]);
let timer: number | null = null;

const isCompat = computed(() =>
  modelInfo.value?.protocol === 'compatible' ||
  modelInfo.value?.protocol === 'dashscope' ||
  modelInfo.value?.protocol === 'uuapi',
);
const sizes = computed(() =>
  isCompat.value
    ? ['1024x1024', '1536x1024', '1024x1536', '2048x2048', '2048x1152', '1152x2048', 'auto']
    : ['1024x1024', '1536x1024', '1024x1536', '2048x2048', '2048x1152', '3840x2160', '2160x3840', 'auto'],
);
const maxN = computed(() => (isCompat.value ? 6 : 10));

function onModelChange(m: ModelItem | null) {
  modelInfo.value = m;
  if (m && !sizes.value.includes(size.value)) size.value = sizes.value[0];
  if (m && n.value > maxN.value) n.value = maxN.value;
}

function clearPrompt() {
  prompt.value = '';
}

function revokeAll() {
  for (const u of previews.value) URL.revokeObjectURL(u);
  previews.value = [];
}

function setFiles(list: File[]) {
  revokeAll();
  files.value = list;
  previews.value = list.map((f) => URL.createObjectURL(f));
}

function stopPoll() {
  if (timer != null) {
    window.clearInterval(timer);
    timer = null;
  }
}

function onPick(e: Event) {
  const input = e.target as HTMLInputElement;
  setFiles(Array.from(input.files || []));
  uploaded.value = [];
  input.value = '';
}

function removeFile(i: number) {
  const url = previews.value[i];
  if (url) URL.revokeObjectURL(url);
  files.value.splice(i, 1);
  previews.value.splice(i, 1);
}

function openLightbox(images: string[], index: number) {
  lightboxImages.value = images;
  lightboxIndex.value = index;
}

async function poll(id: string) {
  const t = await fetchTask(id);
  task.value = t;
  if (t.status === 'succeeded' || t.status === 'failed' || t.status === 'canceled') {
    busy.value = false;
    stopPoll();
  }
}

async function onSubmit() {
  error.value = '';
  if (!prompt.value.trim()) {
    error.value = '请输入编辑描述';
    return;
  }
  if (files.value.length === 0) {
    error.value = '请至少选择一张源图';
    return;
  }
  if (!modelId.value) {
    error.value = '请选择模型';
    return;
  }
  busy.value = true;
  try {
    uploading.value = true;
    uploaded.value = await uploadFiles(files.value);
    uploading.value = false;
    const res = await submitTask({
      type: 'edit',
      prompt: prompt.value,
      modelId: modelId.value,
      size: size.value,
      n: n.value,
      images: uploaded.value,
    });
    task.value = await fetchTask(res.id);
    stopPoll();
    timer = window.setInterval(() => {
      poll(res.id).catch((e) => {
        error.value = (e as Error).message;
      });
    }, 2500);
  } catch (e) {
    error.value = (e as Error).message;
    busy.value = false;
    uploading.value = false;
  }
}

async function onCancel() {
  if (!task.value) return;
  try {
    task.value = await cancelTask(task.value.id);
    busy.value = false;
    stopPoll();
  } catch (e) {
    error.value = (e as Error).message;
  }
}

onBeforeUnmount(() => {
  stopPoll();
  revokeAll();
});
</script>

<template>
  <div class="card">
    <h2 style="margin-top: 0">图编辑</h2>
    <p class="muted">协议由模型绑定的上游决定；兼容协议不支持遮罩。</p>
    <div class="field">
      <label>源图片（可多选；点缩略图看大图，右上角删除）</label>
      <input type="file" accept="image/*" multiple @change="onPick" />
    </div>
    <div v-if="previews.length" class="row" style="margin-bottom: 0.85rem">
      <div v-for="(src, i) in previews" :key="i" class="thumb-wrap">
        <button class="icon-del" title="删除" @click="removeFile(i)">
          <X :size="12" />
        </button>
        <img class="thumb-img" :src="src" alt="src" @click="openLightbox(previews, i)" />
      </div>
    </div>
    <div class="field">
      <div class="field-head">
        <label>编辑描述</label>
        <button type="button" class="ghost" :disabled="!prompt" @click="clearPrompt">清空</button>
      </div>
      <textarea v-model="prompt" rows="5" maxlength="32000" placeholder="描述你想要的编辑效果…"></textarea>
    </div>
    <div class="row">
      <ModelSelect v-model="modelId" :disabled="busy || uploading" @change="onModelChange" />
      <div class="field">
        <label>尺寸</label>
        <select v-model="size">
          <option v-for="s in sizes" :key="s" :value="s">{{ s }}</option>
        </select>
      </div>
      <div class="field">
        <label>数量（最多 {{ maxN }}）</label>
        <input v-model.number="n" type="number" min="1" :max="maxN" />
      </div>
    </div>
    <div class="row" style="align-items: center">
      <button class="primary" :disabled="busy || uploading" @click="onSubmit">
        {{ uploading ? '上传中…' : busy ? '编辑中…' : '编辑图片' }}
      </button>
      <button class="danger" :disabled="!busy" @click="onCancel">取消</button>
      <span v-if="task" class="tag">{{ task.status }}</span>
    </div>
    <p v-if="error" class="error">{{ error }}</p>
    <p v-if="task?.error && task.status === 'failed'" class="error">{{ task.error }}</p>

    <div v-if="task?.images?.length" class="grid" style="margin-top: 1rem">
      <div v-for="(img, i) in task.images" :key="img" class="thumb">
        <img :src="img" alt="result" style="cursor: zoom-in" @click="openLightbox(task.images, i)" />
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
.thumb-wrap {
  position: relative;
  width: 88px;
  height: 88px;
  flex: 0 0 88px;
}
.thumb-img {
  width: 100%;
  height: 100%;
  object-fit: cover;
  border-radius: 8px;
  border: 1px solid var(--line);
  cursor: zoom-in;
  display: block;
}
.icon-del {
  position: absolute;
  top: -6px;
  right: -6px;
  z-index: 1;
  width: 22px;
  height: 22px;
  padding: 0;
  border: none;
  border-radius: 999px;
  background: var(--danger);
  color: #fff;
  display: flex;
  align-items: center;
  justify-content: center;
}
.thumb img {
  cursor: zoom-in;
}
</style>
