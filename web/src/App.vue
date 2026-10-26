<script setup lang="ts">
import { onMounted, onBeforeUnmount, ref } from 'vue';
import { AuthError, checkAuth, login, logout } from './api/client';
import { activeCount, startTaskEvents, stopTaskEvents } from './api/taskEvents';
import GlobalLoading from './components/GlobalLoading.vue';
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
const loggingOut = ref(false);

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
    // 登录后连 WS：任务状态/活跃数实时推送，断线自动降级轮询
    if (authed.value) startTaskEvents();
    else stopTaskEvents();
  } catch (e) {
    if (e instanceof AuthError) authed.value = false;
    else loadError.value = (e as Error).message;
    stopTaskEvents();
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
  if (loggingOut.value) return;
  loggingOut.value = true;
  try {
    await logout();
  } catch {
    /* 登出接口失败也照常清理本地登录态 */
  } finally {
    authed.value = false;
    password.value = '';
    stopTaskEvents();
    loggingOut.value = false;
  }
}

onMounted(() => {
  applyTheme();
  boot();
});

onBeforeUnmount(stopTaskEvents);
</script>

<template>
  <div class="shell">
    <GlobalLoading />
    <header class="top">
      <div>
        <strong>Z Ai</strong>
        <span class="muted"> · 任务在服务端跑，关页可继续</span>
      </div>
      <div class="top-actions">
        <template v-if="authed">
          <button @click="toggleTheme">{{ dark ? '浅色' : '深色' }}</button>
          <button :disabled="loggingOut" @click="onLogout">
            {{ loggingOut ? '退出中…' : '退出' }}
          </button>
        </template>
        <button v-else @click="toggleTheme">{{ dark ? '浅色' : '深色' }}</button>
      </div>
    </header>

    <div v-if="checking" class="auth-stage">
      <div class="card muted login-card">检查登录状态…</div>
    </div>

    <div v-else-if="!authed" class="auth-stage">
      <div class="card login-card">
        <h2 class="login-title">登录</h2>
        <p class="muted login-desc">个人站，输入访问密码后使用生图 / 编辑。</p>
        <form class="field" @submit.prevent="onLogin">
          <label>密码</label>
          <input v-model="password" type="password" autocomplete="current-password" placeholder="访问密码" />
          <button class="primary" type="submit" :disabled="loggingIn || !password">
            {{ loggingIn ? '登录中…' : '进入' }}
          </button>
        </form>
        <p v-if="loginError" class="error">{{ loginError }}</p>
      </div>
    </div>

    <template v-else>
      <nav class="tabs">
        <button :class="{ primary: tab === 'generate' }" @click="tab = 'generate'">文生图</button>
        <button :class="{ primary: tab === 'edit' }" @click="tab = 'edit'">图编辑</button>
        <button class="tab-btn" :class="{ primary: tab === 'tasks' }" @click="tab = 'tasks'">
          任务
          <span v-if="activeCount > 0" class="badge">{{ activeCount > 99 ? '99+' : activeCount }}</span>
        </button>
        <button :class="{ primary: tab === 'gallery' }" @click="tab = 'gallery'">图库</button>
        <button :class="{ primary: tab === 'models' }" @click="tab = 'models'">模型管理</button>
        <button :class="{ primary: tab === 'logs' }" @click="tab = 'logs'">日志</button>
      </nav>

      <p v-if="loadError" class="error card">{{ loadError }}</p>

      <!-- 外层单根容器 + v-show：页面组件是多根，直接挂在组件上 v-show 无效 -->
      <div v-show="tab === 'generate'" class="page-panel">
        <GeneratePage />
      </div>
      <div v-show="tab === 'edit'" class="page-panel">
        <EditPage />
      </div>
      <TasksPage v-if="tab === 'tasks'" />
      <GalleryPage v-if="tab === 'gallery'" />
      <ModelsPage v-if="tab === 'models'" />
      <LogsPage v-if="tab === 'logs'" />
    </template>
  </div>
</template>

<style scoped>
.shell {
  max-width: 960px;
  min-height: 100vh;
  margin: 0 auto;
  padding: 1rem 1rem 3rem;
  display: flex;
  flex-direction: column;
}
/* 登录/检查态：在剩余视口内水平垂直居中 */
.auth-stage {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1rem 0 3rem;
}
.login-card {
  width: 100%;
  max-width: 360px;
}
.login-title {
  margin: 0 0 0.35rem;
  font-size: 1.25rem;
}
.login-desc {
  margin: 0 0 1rem;
}
.top {
  display: flex;
  justify-content: space-between;
  align-items: center;
  gap: 1rem;
  margin-bottom: 0.85rem;
  flex-wrap: wrap;
}
.top-actions {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  flex: 0 0 auto;
}
.top-actions button {
  min-height: 36px;
  padding: 0.35rem 0.75rem;
  white-space: nowrap;
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
.tab-btn {
  position: relative;
}
.badge {
  position: absolute;
  top: -6px;
  right: -6px;
  min-width: 18px;
  height: 18px;
  padding: 0 4px;
  border-radius: 999px;
  background: var(--danger);
  color: #fff;
  font-size: 11px;
  line-height: 18px;
  text-align: center;
  box-sizing: border-box;
}
@media (max-width: 640px) {
  .shell {
    padding: 0.75rem 0.75rem 2.5rem;
  }
  .auth-stage {
    padding: 0.5rem 0 2rem;
    align-items: flex-start;
  }
  .top {
    gap: 0.5rem;
    margin-bottom: 0.65rem;
  }
  .top-actions {
    gap: 0.4rem;
    margin-left: auto;
  }
  .top-actions button {
    min-height: 32px;
    padding: 0.25rem 0.65rem;
    font-size: 0.85rem;
  }
  .tabs button {
    flex: 1 1 auto;
    min-width: 4.5rem;
    font-size: 0.9rem;
  }
}
</style>
