<script setup lang="ts">
import { ref, watch } from 'vue';
import { fetchModels } from '../api/client';
import type { ModelItem } from '../types';

const props = defineProps<{
  modelValue: string;
  disabled?: boolean;
}>();

const emit = defineEmits<{
  (e: 'update:modelValue', v: string): void;
  (e: 'change', model: ModelItem | null): void;
}>();

const models = ref<ModelItem[]>([]);
const loading = ref(false);
const loadError = ref('');

function emitChange(id: string) {
  emit('update:modelValue', id);
  emit('change', models.value.find((m) => m.id === id) || null);
}

async function load() {
  loading.value = true;
  loadError.value = '';
  try {
    const data = await fetchModels(true);
    models.value = data.models;
    if (!data.models.length) {
      loadError.value = '暂无启用模型，请到「模型管理」添加或同步';
      if (props.modelValue) emitChange('');
      return;
    }
    const has = data.models.some((m) => m.id === props.modelValue);
    if (!has) emitChange(data.models[0].id);
  } catch (e) {
    models.value = [];
    loadError.value = (e as Error).message;
  } finally {
    loading.value = false;
  }
}

watch(() => props.disabled, () => {}, { immediate: false });
load();
</script>

<template>
  <div class="field">
    <label>模型</label>
    <select
      :value="modelValue"
      :disabled="disabled || loading || !models.length"
      @change="emitChange(($event.target as HTMLSelectElement).value)"
    >
      <option v-if="!models.length" value="">{{ loading ? '加载中…' : '暂无模型' }}</option>
      <option v-for="m in models" :key="m.id" :value="m.id">
        {{ m.label }}
      </option>
    </select>
    <span v-if="loadError" class="error" style="font-size: 0.85rem">{{ loadError }}</span>
  </div>
</template>
