import fs from 'node:fs';
import path from 'node:path';
import { config } from './config.js';
import { deleteResultsByTask, deleteTask, getTaskRow, listResults } from './db.js';
import { logger } from './logBus.js';

/**
 * 删除任务及其结果图（磁盘文件 + results 记录 + 任务行）。
 * 仅允许终态任务（succeeded/failed/canceled）；未终态需先取消。
 * 返回 { httpStatus, ok?, deletedImages?, error? }，由路由层直接映射响应。
 */
export function deleteTaskWithImages(taskId) {
  const row = getTaskRow(taskId);
  if (!row) {
    return { httpStatus: 404, error: '任务不存在' };
  }
  if (row.status === 'queued' || row.status === 'running') {
    return { httpStatus: 409, error: '任务进行中，请先取消后再删除' };
  }
  try {
    const names = listResults(taskId);
    for (const name of names) {
      const p = path.join(config.imagesDir, path.basename(name));
      if (p.startsWith(config.imagesDir) && fs.existsSync(p)) fs.unlinkSync(p);
    }
    deleteResultsByTask(taskId);
    deleteTask(taskId);
    logger.info(`删除任务 ${taskId}（含 ${names.length} 张图）`);
    return { httpStatus: 200, ok: true, deletedImages: names.length };
  } catch (e) {
    return { httpStatus: 500, error: e.message || String(e) };
  }
}
