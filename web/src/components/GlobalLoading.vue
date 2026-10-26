<script setup lang="ts">
import { onBeforeUnmount, ref, watch } from 'vue';
import { globalPending } from '../api/loading';

const visible = ref(false);
let hideTimer: number | null = null;

watch(
  globalPending,
  (n) => {
    if (n > 0) {
      if (hideTimer != null) {
        window.clearTimeout(hideTimer);
        hideTimer = null;
      }
      visible.value = true;
    } else if (visible.value) {
      // 归 0 后稍等再隐藏，避免快速请求闪烁
      hideTimer = window.setTimeout(() => {
        visible.value = false;
        hideTimer = null;
      }, 180);
    }
  },
  { immediate: true },
);

onBeforeUnmount(() => {
  if (hideTimer != null) window.clearTimeout(hideTimer);
});
</script>

<template>
  <div class="top-progress" :class="{ show: visible }" aria-hidden="true">
    <div class="top-progress-bar" />
  </div>
</template>

<style scoped>
.top-progress {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  height: 2px;
  z-index: 9999;
  overflow: hidden;
  pointer-events: none;
  opacity: 0;
  transition: opacity 0.15s ease;
}
.top-progress.show {
  opacity: 1;
}
.top-progress-bar {
  height: 100%;
  width: 36%;
  background: var(--accent);
  animation: top-progress-slide 1s ease-in-out infinite;
}
@keyframes top-progress-slide {
  0% {
    transform: translateX(-100%);
  }
  100% {
    transform: translateX(300%);
  }
}
</style>
