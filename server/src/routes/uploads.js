import { Router } from 'express';
import multer from 'multer';
import path from 'node:path';
import crypto from 'node:crypto';
import { config } from '../config.js';

const router = Router();

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, config.uploadsDir),
  filename: (_req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.png';
    cb(null, `${crypto.randomUUID()}${ext}`);
  },
});

const upload = multer({
  storage,
  limits: { fileSize: config.maxUploadBytes },
  fileFilter: (_req, file, cb) => {
    if (/^image\//.test(file.mimetype)) cb(null, true);
    else cb(new Error('仅支持图片文件'));
  },
});

router.post('/', upload.array('files', 8), (req, res) => {
  const files = (req.files || []).map((f) => f.filename);
  if (files.length === 0) {
    return res.status(400).json({ error: '未收到文件' });
  }
  res.json({ files });
});

export default router;
