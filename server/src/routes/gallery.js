import { Router } from 'express';
import fs from 'node:fs';
import path from 'node:path';
import { config } from '../config.js';
import {
  deleteResultByFile,
  deleteResultsByTask,
  deleteTask,
  findResultByFile,
  getTaskRow,
  listAllImages,
  listResults,
} from '../db.js';
import { logger } from '../logBus.js';

const router = Router();

/** 历史结果图列表（进页面加载）。 */
router.get('/', (req, res) => {
  const limit = Math.min(Number(req.query.limit) || 200, 500);
  const rows = listAllImages(limit);
  res.json({
    images: rows.map((r) => ({
      id: r.id,
      fileName: r.file_name,
      taskId: r.task_id,
      prompt: r.prompt || '',
      type: r.type || 'generate',
      createdAt: r.created_at,
      url: `/files/${r.file_name}`,
    })),
  });
});

/** 删除单张结果图（磁盘 + 记录）。 */
router.delete('/:fileName', (req, res) => {
  const fileName = path.basename(req.params.fileName);
  const row = findResultByFile(fileName);
  const filePath = path.join(config.imagesDir, fileName);
  try {
    if (filePath.startsWith(config.imagesDir) && fs.existsSync(filePath)) {
      fs.unlinkSync(filePath);
    }
    if (row) deleteResultByFile(fileName);
    logger.info(`删除图片 ${fileName}`);
    res.json({ ok: true });
  } catch (e) {
    res.status(500).json({ error: e.message || String(e) });
  }
});

/** 删除整个任务及其图片。 */
router.delete('/task/:taskId', (req, res) => {
  const taskId = req.params.taskId;
  const task = getTaskRow(taskId);
  if (!task) return res.status(404).json({ error: '任务不存在' });
  try {
    const names = listResults(taskId);
    for (const name of names) {
      const p = path.join(config.imagesDir, path.basename(name));
      if (p.startsWith(config.imagesDir) && fs.existsSync(p)) fs.unlinkSync(p);
    }
    deleteResultsByTask(taskId);
    deleteTask(taskId);
    logger.info(`删除任务 ${taskId}（含 ${names.length} 张图）`);
    res.json({ ok: true, deletedImages: names.length });
  } catch (e) {
    res.status(500).json({ error: e.message || String(e) });
  }
});

export default router;
