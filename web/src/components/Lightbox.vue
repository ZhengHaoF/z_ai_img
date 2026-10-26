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
/** 拖拽/滑动中的横向位移（px），>0 表示手指右移（看上一张） */
const dragX = ref(0);
const dragging = ref(false);
let dragStartX = 0;
let dragStartY = 0;
/** 拖拽方向判定：null 未定，'x' 横向翻图，'y' 纵向交还浏览器 */
let axis: 'x' | 'y' | null = null;
let longPressTimer: number | null = null;

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

function onDragStart(x: number, y: number) {
  if (props.images.length < 2) return;
  dragStartX = x;
  dragStartY = y;
  axis = null;
  dragging.value = true;
  dragX.value = 0;
  // 长按（未形成拖拽）后松手不触发翻页，避免误操作
  if (longPressTimer != null) window.clearTimeout(longPressTimer);
  longPressTimer = window.setTimeout(() => {
    longPressTimer = null;
    axis = 'y'; // 已按住很久未动，放弃翻页判定
  }, 800);
}

function onDragMove(x: number, y: number, ev: Event) {
  if (!dragging.value) return;
  const dx = x - dragStartX;
  const dy = y - dragStartY;
  if (axis == null) {
    if (Math.abs(dx) < 6 && Math.abs(dy) < 6) return;
    axis = Math.abs(dx) >= Math.abs(dy) ? 'x' : 'y';
    if (longPressTimer != null) {
      window.clearTimeout(longPressTimer);
      longPressTimer = null;
    }
    if (axis === 'y') {
      dragging.value = false;
      dragX.value = 0;
      return;
    }
  }
  if (axis !== 'x') return;
  // 阻止图片被拖成原生 drag / 页面滚动
  if (ev.cancelable) ev.preventDefault();
  dragX.value = dx;
}

function onDragEnd() {
  if (longPressTimer != null) {
    window.clearTimeout(longPressTimer);
    longPressTimer = null;
  }
  if (!dragging.value) return;
  dragging.value = false;
  const dx = dragX.value;
  dragX.value = 0;
  if (axis !== 'x') return;
  axis = null;
  const threshold = Math.min(120, window.innerWidth * 0.15);
  if (dx > threshold) go(-1);
  else if (dx < -threshold) go(1);
}

/* ---- 触摸 ---- */
function onTouchStart(e: TouchEvent) {
  const t = e.touches[0];
  if (t) onDragStart(t.clientX, t.clientY);
}
function onTouchMove(e: TouchEvent) {
  const t = e.touches[0];
  if (t) onDragMove(t.clientX, t.clientY, e);
}
function onTouchEnd() {
  onDragEnd();
}

/* ---- 鼠标拖拽（桌面端） ---- */
function onMouseDown(e: MouseEvent) {
  if (e.button !== 0) return;
  onDragStart(e.clientX, e.clientY);
}
function onMouseMove(e: MouseEvent) {
  onDragMove(e.clientX, e.clientY, e);
}
function onMouseUp() {
  onDragEnd();
}

onMounted(() => {
  window.addEventListener('keydown', onKey);
  window.addEventListener('mousemove', onMouseMove);
  window.addEventListener('mouseup', onMouseUp);
});
onBeforeUnmount(() => {
  window.removeEventListener('keydown', onKey);
  window.removeEventListener('mousemove', onMouseMove);
  window.removeEventListener('mouseup', onMouseUp);
  if (longPressTimer != null) window.clearTimeout(longPressTimer);
});
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
    <img
      class="full"
      :class="{ dragging }"
      :src="images[current]"
      alt="preview"
      draggable="false"
      :style="dragging || dragX ? { transform: `translateX(${dragX}px)` } : undefined"
      @click.stop
      @touchstart.passive="onTouchStart"
      @touchmove.passive="onTouchMove"
      @touchend="onTouchEnd"
      @touchcancel="onTouchEnd"
      @mousedown.prevent="onMouseDown"
    />
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
  user-select: none;
  -webkit-user-select: none;
  -webkit-user-drag: none;
  cursor: grab;
  touch-action: pan-y;
  transition: transform 0.25s ease;
}
.full.dragging {
  transition: none;
  cursor: grabbing;
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
