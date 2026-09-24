<script setup lang="ts">
import { onBeforeUnmount, onMounted, ref } from 'vue';
import { X, ChevronLeft, ChevronRight, Download } from 'lucide-vue-next';

const props = defineProps<{
  images: string[];
  index: number;
}>();

const emit = defineEmits<{
  (e: 'close'): void;
  (e: 'update:index', v: number): void;
}>();

const current = ref(props.index);

function go(delta: number) {
  const n = props.images.length;
  if (!n) return;
  current.value = (current.value + delta + n) % n;
  emit('update:index', current.value);
}

function onKey(e: KeyboardEvent) {
  if (e.key === 'Escape') emit('close');
  if (e.key === 'ArrowLeft') go(-1);
  if (e.key === 'ArrowRight') go(1);
}

onMounted(() => window.addEventListener('keydown', onKey));
onBeforeUnmount(() => window.removeEventListener('keydown', onKey));
</script>

<template>
  <div class="overlay" @click.self="emit('close')">
    <button class="icon-btn close" title="关闭" @click="emit('close')"><X :size="22" /></button>
    <button v-if="images.length > 1" class="icon-btn prev" title="上一张" @click="go(-1)">
      <ChevronLeft :size="28" />
    </button>
    <button v-if="images.length > 1" class="icon-btn next" title="下一张" @click="go(1)">
      <ChevronRight :size="28" />
    </button>
    <img class="full" :src="images[current]" alt="preview" @click.stop />
    <div class="bar">
      <span v-if="images.length > 1">{{ current + 1 }} / {{ images.length }}</span>
      <a class="icon-btn" :href="images[current]" download title="下载">
        <Download :size="18" />
      </a>
    </div>
  </div>
</template>

<style scoped>
.overlay {
  position: fixed;
  inset: 0;
  z-index: 100;
  background: rgba(0, 0, 0, 0.88);
  display: flex;
  align-items: center;
  justify-content: center;
}
.full {
  max-width: min(92vw, 1200px);
  max-height: 86vh;
  object-fit: contain;
  border-radius: 6px;
}
.icon-btn {
  position: absolute;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 40px;
  height: 40px;
  border: none;
  border-radius: 999px;
  background: rgba(255, 255, 255, 0.12);
  color: #fff;
  text-decoration: none;
  cursor: pointer;
}
.icon-btn:hover {
  background: rgba(255, 255, 255, 0.22);
}
.close {
  top: 1rem;
  right: 1rem;
}
.prev {
  left: 1rem;
  top: 50%;
  transform: translateY(-50%);
}
.next {
  right: 1rem;
  top: 50%;
  transform: translateY(-50%);
}
.bar {
  position: absolute;
  bottom: 1.2rem;
  left: 0;
  right: 0;
  display: flex;
  gap: 0.75rem;
  align-items: center;
  justify-content: center;
  color: #fff;
  font-size: 0.9rem;
}
.bar .icon-btn {
  position: static;
}
</style>
