<script setup lang="ts">
import { onMounted, ref } from 'vue';
import { AuthError, checkAuth, login, logout } from './api/client';
import GeneratePage from './pages/Generate.vue';
import EditPage from './pages/Edit.vue';
import TasksPage from './pages/Tasks.vue';
import ModelsPage from './pages/Models.vue';
import LogsPage from './pages/Logs.vue';
import GalleryPage from './pages/Gallery.vue';

const tab = ref<'generate' | 'edit' | 'tasks' | 'models' | 'logs' | 'gallery'>('generate');
const dark = ref(localStorage.getItem('theme') === 'dark');
const loadError = ref('');
const authed = ref(false);
const checking = ref(true);
const password = ref('');
const loginError = ref('');
const loggingIn = ref(false);

function applyTheme() {
  document.documentElement.classList.toggle('dark', dark.value);
  localStorage.setItem('theme', dark.value ? 'dark' : 'light');
}

function toggleTheme() {
  dark.value = !dark.value;
  applyTheme();
}

async function boot() {
  checking.value = true;
  loadError.value = '';
  try {
    const me = await checkAuth();
    authed.value = me.authenticated;
  } catch (e) {
    if (e instanceof AuthError) authed.value = false;
    else loadError.value = (e as Error).message;
  } finally {
    checking.value = false;
  }
}

async function onLogin() {
  loggingIn.value = true;
  loginError.value = '';
  try {
    await login(password.value);
    password.value = '';
    await boot();
  } catch (e) {
    loginError.value = (e as Error).message;
  } finally {
    loggingIn.value = false;
  }
}

async function onLogout() {
  try {
    await logout();
  } finally {
    authed.value = false;
    password.value = '';
  }
}

onMounted(() => {
  applyTheme();
  boot();
});
</script>

<template>
  <div class="shell">
    <header class="top">
      <div>
        <strong>Z Ai</strong>
        <span class="muted"> · 任务在服务端跑，关页可继续</span>
      </div>
      <div class="row" style="flex: 0">
        <template v-if="authed">
          <button @click="toggleTheme">{{ dark ? '浅色' : '深色' }}</button>
          <button @click="onLogout">退出</button>
        </template>
        <button v-else @click="toggleTheme">{{ dark ? '浅色' : '深色' }}</button>
      </div>
    </header>

    <div v-if="checking" class="card muted">检查登录状态…</div>

    <div v-else-if="!authed" class="card login">
      <h2 style="margin-top: 0">登录</h2>
      <p class="muted">个人站，输入访问密码后使用生图 / 编辑。</p>
      <form class="field" @submit.prevent="onLogin">
        <label>密码</label>
        <input v-model="password" type="password" autocomplete="current-password" placeholder="访问密码" />
        <button class="primary" type="submit" :disabled="loggingIn || !password">
          {{ loggingIn ? '登录中…' : '进入' }}
        </button>
      </form>
      <p v-if="loginError" class="error">{{ loginError }}</p>
    </div>

    <template v-else>
      <nav class="tabs">
        <button :class="{ primary: tab === 'generate' }" @click="tab = 'generate'">文生图</button>
        <button :class="{ primary: tab === 'edit' }" @click="tab = 'edit'">图编辑</button>
        <button :class="{ primary: tab === 'tasks' }" @click="tab = 'tasks'">任务</button>
        <button :class="{ primary: tab === 'gallery' }" @click="tab = 'gallery'">图库</button>
        <button :class="{ primary: tab === 'models' }" @click="tab = 'models'">模型管理</button>
        <button :class="{ primary: tab === 'logs' }" @click="tab = 'logs'">日志</button>
      </nav>

      <p v-if="loadError" class="error card">{{ loadError }}</p>

      <GeneratePage v-if="tab === 'generate'" />
      <EditPage v-else-if="tab === 'edit'" />
      <TasksPage v-else-if="tab === 'tasks'" />
      <GalleryPage v-else-if="tab === 'gallery'" />
      <ModelsPage v-else-if="tab === 'models'" />
      <LogsPage v-else />
    </template>
  </div>
</template>

<style scoped>
.shell {
  max-width: 960px;
  margin: 0 auto;
  padding: 1rem 1rem 3rem;
}
.top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 1rem;
  margin-bottom: 0.85rem;
  flex-wrap: wrap;
}
.tabs {
  display: flex;
  gap: 0.45rem;
  margin-bottom: 1rem;
  flex-wrap: wrap;
}
.tabs button {
  min-height: 40px;
  padding: 0.45rem 0.75rem;
}
.login {
  max-width: 360px;
}
@media (max-width: 640px) {
  .shell {
    padding: 0.75rem 0.75rem 2.5rem;
  }
  .top {
    gap: 0.5rem;
    margin-bottom: 0.65rem;
  }
  .tabs button {
    flex: 1 1 auto;
    min-width: 4.5rem;
    font-size: 0.9rem;
  }
}
</style>
