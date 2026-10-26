<script setup lang="ts">
import { computed, onMounted, ref, watch } from 'vue';
import { cancelTask, fetchTask, submitTask } from '../api/client';
import { applyTask, tasks as allTasks } from '../api/taskEvents';
import type { ModelItem, Task } from '../types';
import Lightbox from '../components/Lightbox.vue';
import ModelSelect from '../components/ModelSelect.vue';

const prompt = ref('');
const modelId = ref('');
const modelInfo = ref<ModelItem | null>(null);
const size = ref('1024x1024');
const n = ref(1);
/** 提交请求在途锁；任务在服务端跑，不锁到任务完成 */
const submitting = ref(false);
/** 取消请求在途锁 */
const canceling = ref(false);
const error = ref('');
/** 当前跟踪的任务 id；任务详情由全局 store 的 WS/降级推送驱动 */
const watchedId = ref('');
const task = computed<Task | null>(
  () => allTasks.value.find((t) => t.id === watchedId.value) || null,
);
const lightboxIndex = ref(-1);

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

function isTaskLive(t: Task) {
  return t.status === 'queued' || t.status === 'running';
}

// 任务进入终态后清掉本地「上次任务」记忆
watch(task, (t) => {
  if (t && !isTaskLive(t)) localStorage.removeItem('z_ai_last_task');
});

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
  try {
    const res = await submitTask({
      type: 'generate',
      prompt: prompt.value,
      modelId: modelId.value,
      size: size.value,
      n: n.value,
    });
    localStorage.setItem('z_ai_last_task', res.id);
    watchedId.value = res.id;
    // 立即拉一次让 UI 马上有反馈；后续状态由 WS/降级推送自动更新
    applyTask(await fetchTask(res.id));
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    // 只锁「提交在途」；任务在服务端继续跑
    submitting.value = false;
  }
}

async function onCancel() {
  if (!task.value || canceling.value) return;
  canceling.value = true;
  try {
    applyTask(await cancelTask(task.value.id));
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    canceling.value = false;
  }
}

onMounted(async () => {
  const last = localStorage.getItem('z_ai_last_task');
  if (last) {
    try {
      applyTask(await fetchTask(last));
      watchedId.value = last;
    } catch {
      localStorage.removeItem('z_ai_last_task');
    }
  }
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
        {{ submitting ? '提交中…' : '生成图片' }}
      </button>
      <button class="danger" :disabled="!task || !isTaskLive(task) || canceling" @click="onCancel">
        {{ canceling ? '取消中…' : '取消' }}
      </button>
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
