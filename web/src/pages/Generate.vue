<script setup lang="ts">
import { computed, onBeforeUnmount, onMounted, ref } from 'vue';
import { cancelTask, fetchTask, submitTask } from '../api/client';
import type { ModelItem, Task } from '../types';
import Lightbox from '../components/Lightbox.vue';
import ModelSelect from '../components/ModelSelect.vue';

const prompt = ref('');
const modelId = ref('');
const modelInfo = ref<ModelItem | null>(null);
const size = ref('1024x1024');
const n = ref(1);
/** 提交后短暂锁定按钮，不绑定任务跑完 */
const submitting = ref(false);
const error = ref('');
const task = ref<Task | null>(null);
const lightboxIndex = ref(-1);
let timer: number | null = null;
let unlockTimer: number | null = null;

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
  if (m && !sizes.value.includes(size.value)) {
    size.value = sizes.value[0];
  }
  if (m && n.value > maxN.value) n.value = maxN.value;
}

function clearPrompt() {
  prompt.value = '';
}

function stopPoll() {
  if (timer != null) {
    window.clearInterval(timer);
    timer = null;
  }
}

function armUnlock() {
  if (unlockTimer != null) window.clearTimeout(unlockTimer);
  unlockTimer = window.setTimeout(() => {
    submitting.value = false;
    unlockTimer = null;
  }, 3000);
}

function isTaskLive(t: Task) {
  return t.status === 'queued' || t.status === 'running';
}

async function poll(id: string) {
  const t = await fetchTask(id);
  task.value = t;
  if (!isTaskLive(t)) {
    stopPoll();
    localStorage.removeItem('z_ai_last_task');
  }
}

async function onSubmit() {
  error.value = '';
  if (submitting.value) return;
  if (!prompt.value.trim()) {
    error.value = '请输入提示词';
    return;
  }
  if (!modelId.value) {
    error.value = '请选择模型';
    return;
  }
  submitting.value = true;
  armUnlock();
  try {
    const res = await submitTask({
      type: 'generate',
      prompt: prompt.value,
      modelId: modelId.value,
      size: size.value,
      n: n.value,
    });
    localStorage.setItem('z_ai_last_task', res.id);
    task.value = await fetchTask(res.id);
    stopPoll();
    timer = window.setInterval(() => {
      poll(res.id).catch((e) => {
        error.value = (e as Error).message;
      });
    }, 2500);
    await poll(res.id);
  } catch (e) {
    error.value = (e as Error).message;
    submitting.value = false;
    if (unlockTimer != null) {
      window.clearTimeout(unlockTimer);
      unlockTimer = null;
    }
  }
}

async function onCancel() {
  if (!task.value) return;
  try {
    task.value = await cancelTask(task.value.id);
    stopPoll();
  } catch (e) {
    error.value = (e as Error).message;
  }
}

onMounted(async () => {
  const last = localStorage.getItem('z_ai_last_task');
  if (last) {
    try {
      const t = await fetchTask(last);
      task.value = t;
      if (isTaskLive(t)) {
        stopPoll();
        timer = window.setInterval(() => {
          poll(last).catch(() => {});
        }, 2500);
      }
    } catch {
      localStorage.removeItem('z_ai_last_task');
    }
  }
});

onBeforeUnmount(() => {
  stopPoll();
  if (unlockTimer != null) window.clearTimeout(unlockTimer);
});
</script>

<template>
  <div class="card">
    <h2 style="margin-top: 0">文生图</h2>
    <div class="field">
      <div class="field-head">
        <label>提示词</label>
        <button type="button" class="ghost" :disabled="!prompt" @click="clearPrompt">清空</button>
      </div>
      <textarea v-model="prompt" rows="5" maxlength="1000" placeholder="描述你想生成的画面…"></textarea>
    </div>
    <div class="row">
      <ModelSelect v-model="modelId" :disabled="submitting" @change="onModelChange" />
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
      <button class="primary" :disabled="submitting" @click="onSubmit">
        {{ submitting ? '生成中…' : '生成图片' }}
      </button>
      <button class="danger" :disabled="!task || !isTaskLive(task)" @click="onCancel">取消</button>
      <span v-if="task" class="tag">{{ task.status }}</span>
    </div>
    <p v-if="error" class="error">{{ error }}</p>
    <p v-if="task?.error && task.status === 'failed'" class="error">{{ task.error }}</p>
    <p v-if="task && isTaskLive(task)" class="muted">
      任务在服务端执行，可继续生成；进度见「任务」。
    </p>

    <div v-if="task?.images?.length" class="grid" style="margin-top: 1rem">
      <div v-for="(img, i) in task.images" :key="img" class="thumb">
        <img :src="img" alt="result" style="cursor: zoom-in" @click="lightboxIndex = i" />
      </div>
    </div>
  </div>

  <Lightbox
    v-if="lightboxIndex >= 0 && task?.images?.length"
    :images="task.images"
    :index="lightboxIndex"
    @close="lightboxIndex = -1"
    @update:index="lightboxIndex = $event"
  />
</template>
