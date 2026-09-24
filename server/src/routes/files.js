import { Router } from 'express';
import path from 'node:path';
import fs from 'node:fs';
import { config } from '../config.js';

const router = Router();

router.get('/:name', (req, res) => {
  const safe = path.basename(req.params.name);
  const file = path.join(config.imagesDir, safe);
  if (!file.startsWith(config.imagesDir) || !fs.existsSync(file)) {
    return res.status(404).json({ error: '文件不存在' });
  }
  res.sendFile(file);
});

export default router;
