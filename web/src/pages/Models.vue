<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { Pencil, Plus, RefreshCw, Trash2, X, Check, Search } from 'lucide-vue-next';
import {
  createModel,
  deleteModel,
  fetchModels,
  listRemoteModels,
  syncModels,
  updateModel,
} from '../api/client';
import type { ModelItem } from '../types';

const models = ref<ModelItem[]>([]);
const error = ref('');
const notice = ref('');
const syncing = ref(false);
const listing = ref(false);
const remoteNames = ref<string[]>([]);

const showForm = ref(false);
const editingId = ref<string | null>(null);
const form = ref({
  label: '',
  baseUrl: '',
  protocol: 'dashscope' as 'openai' | 'compatible' | 'dashscope' | 'uuapi',
  upstreamModel: '',
  apiKey: '',
  enabled: true,
});

function protocolLabel(p: string) {
  if (p === 'compatible') return '兼容扩展';
  if (p === 'dashscope') return 'DashScope 异步';
  if (p === 'uuapi') return 'Images 异步 (uuapi)';
  return 'OpenAI Images';
}

async function load() {
  error.value = '';
  try {
    const m = await fetchModels(false);
    models.value = m.models;
  } catch (e) {
    error.value = (e as Error).message;
  }
}

function openCreate() {
  editingId.value = null;
  form.value = {
    label: '',
    baseUrl: '',
    protocol: 'dashscope',
    upstreamModel: '',
    apiKey: '',
    enabled: true,
  };
  remoteNames.value = [];
  showForm.value = true;
}

function openEdit(m: ModelItem) {
  editingId.value = m.id;
  form.value = {
    label: m.label,
    baseUrl: m.baseUrl,
    protocol: m.protocol,
    upstreamModel: m.upstreamModel,
    apiKey: '',
    enabled: m.enabled,
  };
  remoteNames.value = [];
  showForm.value = true;
}

async function onSave() {
  error.value = '';
  try {
    if (editingId.value) {
      const body: Parameters<typeof updateModel>[1] = {
        label: form.value.label,
        baseUrl: form.value.baseUrl,
        protocol: form.value.protocol,
        upstreamModel: form.value.upstreamModel,
        enabled: form.value.enabled,
      };
      if (form.value.apiKey) body.apiKey = form.value.apiKey;
      await updateModel(editingId.value, body);
    } else {
      await createModel({ ...form.value });
    }
    showForm.value = false;
    await load();
  } catch (e) {
    error.value = (e as Error).message;
  }
}

async function onToggle(m: ModelItem) {
  try {
    await updateModel(m.id, { enabled: !m.enabled });
    await load();
  } catch (e) {
    error.value = (e as Error).message;
  }
}

async function onDelete(m: ModelItem) {
  if (!confirm(`删除模型「${m.label}」？`)) return;
  try {
    await deleteModel(m.id);
    await load();
  } catch (e) {
    error.value = (e as Error).message;
  }
}

async function onListRemote() {
  if (!form.value.baseUrl.trim()) {
    error.value = '请先填写上游 Base URL';
    return;
  }
  listing.value = true;
  error.value = '';
  notice.value = '';
  try {
    const r = await listRemoteModels({
      baseUrl: form.value.baseUrl,
      apiKey: form.value.apiKey || undefined,
    });
    remoteNames.value = r.models;
    notice.value = `拉到 ${r.models.length} 个模型，点名称可填入`;
    if (!form.value.upstreamModel && r.models.length) {
      form.value.upstreamModel = r.models[0];
    }
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    listing.value = false;
  }
}

async function onSync() {
  if (!form.value.baseUrl.trim()) {
    error.value = '请先填写上游 Base URL';
    return;
  }
  syncing.value = true;
  error.value = '';
  notice.value = '';
  try {
    const r = await syncModels({
      baseUrl: form.value.baseUrl,
      apiKey: form.value.apiKey || undefined,
      protocol: form.value.protocol,
      enabled: form.value.enabled,
    });
    models.value = r.models;
    notice.value = `同步入库：新增 ${r.added.length}，跳过 ${r.skipped.length}`;
    showForm.value = false;
  } catch (e) {
    error.value = (e as Error).message;
  } finally {
    syncing.value = false;
  }
}

onMounted(load);
</script>

<template>
  <div class="card">
    <div class="toolbar">
      <h2>模型管理</h2>
      <button class="primary" @click="openCreate">
        <Plus :size="14" style="vertical-align: -2px" />
        添加
      </button>
    </div>
    <p class="muted">
      每个模型自带上游地址、协议与 Key（Key 只存服务端）。生图/编辑只显示「启用」的模型。
    </p>
    <p v-if="error" class="error">{{ error }}</p>
    <p v-if="notice" class="ok">{{ notice }}</p>

    <div class="model-list">
      <div v-for="m in models" :key="m.id" class="model-card">
        <div class="model-head">
          <div class="model-title">
            <strong>{{ m.label }}</strong>
            <span class="tag">{{ protocolLabel(m.protocol) }}</span>
            <span class="tag">{{ m.hasKey ? 'Key 已配' : '缺 Key' }}</span>
            <span class="tag" :class="m.enabled ? 'ok' : 'off'">{{ m.enabled ? '启用' : '停用' }}</span>
          </div>
          <div class="model-actions">
            <button class="icon-like" :title="m.enabled ? '停用' : '启用'" @click="onToggle(m)">
              <Check v-if="m.enabled" :size="16" />
              <X v-else :size="16" />
            </button>
            <button class="icon-like" title="编辑" @click="openEdit(m)"><Pencil :size="14" /></button>
            <button class="icon-like danger" title="删除" @click="onDelete(m)"><Trash2 :size="14" /></button>
          </div>
        </div>
        <div class="model-meta">
          <div><span class="k">上游模型</span>{{ m.upstreamModel }}</div>
          <div class="url"><span class="k">Base URL</span>{{ m.baseUrl }}</div>
        </div>
      </div>
      <p v-if="!models.length" class="muted">暂无模型，点「添加」</p>
    </div>
  </div>

  <div v-if="showForm" class="card" style="margin-top: 1rem">
    <h3 style="margin-top: 0">{{ editingId ? '编辑模型' : '添加模型' }}</h3>
    <div class="field">
      <label>显示名</label>
      <input v-model="form.label" placeholder="下拉里展示的名字" />
    </div>
    <div class="field">
      <label>协议</label>
      <select v-model="form.protocol">
        <option value="dashscope">DashScope 异步（千问 3.0 提交+轮询）</option>
        <option value="uuapi">Images 异步 uuapi（/generations/async + /tasks）</option>
        <option value="compatible">OpenAI 兼容扩展（JSON image）</option>
        <option value="openai">标准 OpenAI Images（multipart 编辑）</option>
      </select>
    </div>
    <div class="field">
      <label>上游 Base URL</label>
      <input v-model="form.baseUrl" placeholder="https://uuapi.cc/v1" />
    </div>
    <div class="field">
      <label>上游模型名</label>
      <input v-model="form.upstreamModel" placeholder="例如 gpt-image-2.5-flare" />
    </div>
    <div class="field">
      <label>API Key {{ editingId ? '（留空表示不修改）' : '' }}</label>
      <input v-model="form.apiKey" type="password" autocomplete="off" placeholder="sk-…" />
    </div>
    <div class="field">
      <label>启用</label>
      <select v-model="form.enabled">
        <option :value="true">是</option>
        <option :value="false">否</option>
      </select>
    </div>

    <div class="actions">
      <button :disabled="listing" @click="onListRemote">
        <Search :size="14" style="vertical-align: -2px" />
        {{ listing ? '拉取中…' : '拉取模型列表' }}
      </button>
      <button :disabled="syncing" @click="onSync">
        <RefreshCw :size="14" style="vertical-align: -2px" />
        {{ syncing ? '同步中…' : '同步并入库' }}
      </button>
    </div>
    <div v-if="remoteNames.length" class="remote">
      <span v-for="name in remoteNames" :key="name" class="tag" role="button" @click="form.upstreamModel = name">
        {{ name }}
      </span>
    </div>

    <div class="actions">
      <button class="primary" @click="onSave">保存</button>
      <button @click="showForm = false">取消</button>
    </div>
  </div>
</template>

<style scoped>
.toolbar {
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 0.75rem;
  margin-bottom: 0.75rem;
}
.toolbar h2 {
  margin: 0;
  font-size: 1.15rem;
}
.actions {
  display: flex;
  flex-wrap: wrap;
  gap: 0.5rem;
  margin: 0.75rem 0;
}
.actions button {
  flex: 1 1 auto;
  min-height: 40px;
}
.model-list {
  display: flex;
  flex-direction: column;
  gap: 0.65rem;
}
.model-card {
  border: 1px solid var(--line);
  border-radius: 12px;
  padding: 0.75rem 0.85rem;
  background: var(--bg);
}
.model-head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 0.5rem;
}
.model-title {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 0.35rem;
  min-width: 0;
  flex: 1;
}
.model-title strong {
  word-break: break-all;
}
.model-actions {
  display: flex;
  flex-shrink: 0;
  gap: 0.15rem;
}
.model-meta {
  margin-top: 0.55rem;
  font-size: 0.85rem;
  color: var(--muted);
  display: flex;
  flex-direction: column;
  gap: 0.25rem;
}
.model-meta .k {
  display: inline-block;
  min-width: 4.5rem;
  opacity: 0.8;
}
.model-meta .url {
  word-break: break-all;
}
.tag.ok {
  color: var(--ok);
}
.tag.off {
  opacity: 0.55;
}
.icon-like {
  border: none;
  background: transparent;
  padding: 0.35rem;
  color: var(--ink);
  min-width: 36px;
  min-height: 36px;
}
.icon-like.danger {
  color: var(--danger);
}
.remote {
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
  margin-bottom: 0.5rem;
}
.remote .tag {
  cursor: pointer;
}
</style>
