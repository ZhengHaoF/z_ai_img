import { Router } from 'express';
import crypto from 'node:crypto';
import { getTaskRow, insertTask, listTaskRows, rowToTask } from '../db.js';
import { markCancel, enqueue } from '../taskRunner.js';
import { resolveModel } from '../modelRegistry.js';

const router = Router();

router.post('/', (req, res) => {
  const { type, prompt, modelId, size, n, images, mask } = req.body || {};
  if (type !== 'generate' && type !== 'edit') {
    return res.status(400).json({ error: 'type 必须是 generate 或 edit' });
  }
  if (!prompt || typeof prompt !== 'string' || !prompt.trim()) {
    return res.status(400).json({ error: 'prompt 不能为空' });
  }
  if (!modelId) {
    return res.status(400).json({ error: 'modelId 不能为空' });
  }
  if (type === 'edit' && (!Array.isArray(images) || images.length === 0)) {
    return res.status(400).json({ error: '编辑任务需要至少一张源图' });
  }

  let resolved;
  try {
    resolved = resolveModel(modelId);
  } catch (e) {
    return res.status(400).json({ error: e.message || String(e) });
  }

  const now = Date.now();
  const task = {
    id: crypto.randomUUID(),
    type,
    status: 'queued',
    profileId: resolved.modelId,
    params: {
      prompt: prompt.trim(),
      modelId: resolved.modelId,
      model: resolved.target.upstreamModel,
      protocol: resolved.target.protocol,
      size,
      n: Number(n) || 1,
      images: Array.isArray(images) ? images.map(String) : [],
      mask: mask ? String(mask) : null,
    },
    createdAt: now,
    updatedAt: now,
    finishedAt: null,
  };

  insertTask(task);
  enqueue({
    id: task.id,
    type: task.type,
    modelId: resolved.modelId,
    params: task.params,
  });
  return res.status(202).json({ id: task.id, status: task.status });
});

router.get('/', (req, res) => {
  const rows = listTaskRows(50);
  res.json({ tasks: rows.map(rowToTask) });
});

router.get('/:id', (req, res) => {
  const task = rowToTask(getTaskRow(req.params.id));
  if (!task) return res.status(404).json({ error: '任务不存在' });
  res.json(task);
});

router.post('/:id/cancel', (req, res) => {
  const task = rowToTask(getTaskRow(req.params.id));
  if (!task) return res.status(404).json({ error: '任务不存在' });
  if (task.status === 'succeeded' || task.status === 'failed' || task.status === 'canceled') {
    return res.json(task);
  }
  markCancel(task.id);
  const updated = rowToTask(getTaskRow(task.id));
  res.json(updated);
});

export default router;
