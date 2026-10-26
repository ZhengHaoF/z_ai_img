import { ref } from 'vue';

/** 全局在途请求数（不含 silent 轮询），供顶部细进度条使用 */
export const globalPending = ref(0);

export interface RequestOptions {
  /** 轮询/后台静默请求：不计入全局进度条 */
  silent?: boolean;
}

export function beginRequest() {
  globalPending.value++;
}

export function endRequest() {
  if (globalPending.value > 0) globalPending.value--;
}
