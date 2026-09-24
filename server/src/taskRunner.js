import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { config } from './config.js';
import { insertResult, updateTask, listUnfinishedTaskRows } from './db.js';
import { callUpstream } from './imageApi.js';
import {
  downloadUrlToBuffer,
  queryDashScopeAsync,
  submitDashScopeAsync,
} from './dashscopeAsync.js';
import {
  downloadUrlToBuffer as downloadUuUrl,
  queryUuapiAsync,
  submitUuapiAsync,
} from './uuapiAsync.js';
import { resolveModel } from './modelRegistry.js';
import { logger } from './logBus.js';
import { describeFetchError } from './fetchLog.js';

const queue = [];
const canceled = new Set();
const inFlight = new Set();
let running = 0;

export function enqueue(task) {
  logger.info(`任务入队 ${task.type} ${task.id}`, {
    modelId: task.modelId,
    protocol: task.params?.protocol,
  });
  queue.push(task);
  pump();
}

export function markCancel(id) {
  canceled.add(id);
  const idx = queue.findIndex((t) => t.id === id);
  if (idx >= 0) {
    queue.splice(idx, 1);
    updateTask(id, {
      status: 'canceled',
      error: '已取消',
      finishedAt: Date.now(),
      updatedAt: Date.now(),
    });
  }
  return true;
}

function pump() {
  while (running < config.concurrentTasks && queue.length > 0) {
    const task = queue.shift();
    running += 1;
    inFlight.add(task.id);
    run(task)
      .catch(() => {})
      .finally(() => {
        running -= 1;
        inFlight.delete(task.id);
        pump();
      });
  }
}

/** 进程重启后，把未完成任务重新入队；已有 remoteTaskId 的走续轮询。 */
export function resumeUnfinished() {
  const rows = listUnfinishedTaskRows();
  for (const row of rows) {
    if (inFlight.has(row.id)) continue;
    const params = JSON.parse(row.params_json);
    enqueue({
      id: row.id,
      type: row.type,
      modelId: params.modelId,
      params,
      remoteTaskId: row.remote_task_id ?? null,
    });
  }
  return rows.length;
}

async function run(task) {
  if (canceled.has(task.id)) return;

  updateTask(task.id, { status: 'running', updatedAt: Date.now() });

  let target;
  try {
    target = resolveModel(task.modelId).target;
  } catch (e) {
    fail(task.id, e.message || String(e));
    return;
  }
  if (!target.apiKey) {
    fail(task.id, '该模型未配置 API Key');
    return;
  }

  try {
    if (target.protocol === 'dashscope') {
      await runDashScope(task, target);
      return;
    }
    if (target.protocol === 'uuapi') {
      await runUuapi(task, target);
      return;
    }

    const files = await callUpstream({
      target,
      taskType: task.type,
      params: task.params,
    });
    finishWithFiles(task.id, files);
  } catch (e) {
    if (canceled.has(task.id)) {
      cancelDone(task.id);
      return;
    }
    logger.error(`任务异常 ${task.id}`, {
      error: e?.message || String(e),
      detail: describeFetchError(e),
    });
    fail(task.id, e.message || String(e));
  }
}

/** uuapi：images async 提交 + tasks/{id} 轮询。 */
async function runUuapi(task, target) {
  let remoteTaskId = task.remoteTaskId;
  if (!remoteTaskId) {
    logger.info(`uuapi 提交 ${task.type} ${task.id}`, { model: target.upstreamModel });
    const submitted = await submitUuapiAsync({
      target,
      taskType: task.type,
      params: task.params,
    });
    remoteTaskId = submitted.remoteTaskId;
    updateTask(task.id, { remoteTaskId, updatedAt: Date.now() });
    logger.info(`uuapi 已受理 remoteTaskId=${remoteTaskId}`, { taskId: task.id });
  } else {
    logger.info(`uuapi 续轮询 remoteTaskId=${remoteTaskId}`, { taskId: task.id });
  }

  const deadline = Date.now() + config.upstreamTimeoutMs;
  while (Date.now() < deadline) {
    if (canceled.has(task.id)) {
      cancelDone(task.id);
      return;
    }
    const q = await queryUuapiAsync({ target, remoteTaskId });
    if (q.status === 'succeeded') {
      const files = [];
      if (q.buffers?.length) {
        for (const buffer of q.buffers) {
          files.push({ fileName: `${crypto.randomUUID()}.png`, buffer });
        }
      }
      for (const url of q.urls || []) {
        const buffer = await downloadUuUrl(url);
        files.push({ fileName: `${crypto.randomUUID()}.png`, buffer });
      }
      finishWithFiles(task.id, files);
      return;
    }
    if (q.status === 'failed') {
      fail(task.id, q.error || '上游任务失败');
      return;
    }
    await sleep(5000);
  }
  fail(task.id, '等待上游任务超时');
}

async function runDashScope(task, target) {
  // 异步文档以文生图为主；图编辑暂回退兼容 JSON image
  if (task.type === 'edit') {
    const files = await callUpstream({
      target: { ...target, protocol: 'compatible' },
      taskType: 'edit',
      params: task.params,
    });
    finishWithFiles(task.id, files);
    return;
  }

  let remoteTaskId = task.remoteTaskId;
  if (!remoteTaskId) {
    logger.info(`DashScope 提交 ${task.id}`, { model: target.upstreamModel });
    const submitted = await submitDashScopeAsync({ target, params: task.params });
    remoteTaskId = submitted.remoteTaskId;
    updateTask(task.id, { remoteTaskId, updatedAt: Date.now() });
    logger.info(`DashScope 已受理 remoteTaskId=${remoteTaskId}`, { taskId: task.id });
  } else {
    logger.info(`DashScope 续轮询 remoteTaskId=${remoteTaskId}`, { taskId: task.id });
  }

  const deadline = Date.now() + config.upstreamTimeoutMs;
  while (Date.now() < deadline) {
    if (canceled.has(task.id)) {
      cancelDone(task.id);
      return;
    }
    const q = await queryDashScopeAsync({ target, remoteTaskId });
    logger.debug(`DashScope 轮询 ${remoteTaskId} → ${q.status}`, { taskId: task.id });
    if (q.status === 'succeeded') {
      const files = [];
      for (const url of q.urls) {
        const buffer = await downloadUrlToBuffer(url);
        files.push({ fileName: `${crypto.randomUUID()}.png`, buffer });
      }
      finishWithFiles(task.id, files);
      return;
    }
    if (q.status === 'failed') {
      fail(task.id, q.error || '上游任务失败');
      return;
    }
    if (q.status === 'canceled') {
      cancelDone(task.id);
      return;
    }
    await sleep(10000);
  }
  fail(task.id, '等待上游任务超时');
}

function finishWithFiles(id, files) {
  if (canceled.has(id)) {
    cancelDone(id);
    return;
  }
  for (const f of files) {
    const dest = path.join(config.imagesDir, f.fileName);
    fs.writeFileSync(dest, f.buffer);
    insertResult(id, f.fileName);
  }
  updateTask(id, {
    status: 'succeeded',
    finishedAt: Date.now(),
    updatedAt: Date.now(),
  });
  logger.info(`任务完成 ${id}（${files.length} 张）`);
}

function cancelDone(id) {
  updateTask(id, {
    status: 'canceled',
    error: '已取消',
    finishedAt: Date.now(),
    updatedAt: Date.now(),
  });
}

function fail(id, message) {
  updateTask(id, {
    status: 'failed',
    error: message,
    finishedAt: Date.now(),
    updatedAt: Date.now(),
  });
  logger.error(`任务失败 ${id}: ${message}`);
}

function sleep(ms) {
  return new Promise((r) => setTimeout(r, ms));
}
