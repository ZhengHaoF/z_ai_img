import { Router } from 'express';
import fs from 'node:fs';
import path from 'node:path';
import { config } from '../config.js';
import {
  deleteResultByFile,
  findResultByFile,
  listAllImages,
} from '../db.js';
import { deleteTaskWithImages } from '../taskDelete.js';
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

/** 删除整个任务及其图片（未终态任务拒绝，需先取消）。 */
router.delete('/task/:taskId', (req, res) => {
  const result = deleteTaskWithImages(req.params.taskId);
  if (result.error) {
    return res.status(result.httpStatus).json({ error: result.error });
  }
  res.json({ ok: true, deletedImages: result.deletedImages });
});

export default router;
