import express from 'express';
import http from 'node:http';
import path from 'node:path';
import fs from 'node:fs';
import { fileURLToPath } from 'node:url';
import { config, ensureDirs } from './config.js';
import { hookConsole, logger } from './logBus.js';
import { attachLogSocket } from './logSocket.js';
import { initDb } from './db.js';
import {
  checkPassword,
  clearSessionCookie,
  createSessionCookie,
  isAuthenticated,
  loginRateLimit,
  recordLoginFail,
  requireAuth,
} from './auth.js';
import { getLogBuffer } from './logBus.js';
import tasksRouter from './routes/tasks.js';
import profilesRouter from './routes/profiles.js';
import filesRouter from './routes/files.js';
import uploadsRouter from './routes/uploads.js';
import modelsRouter from './routes/models.js';
import galleryRouter from './routes/gallery.js';
import { resumeUnfinished } from './taskRunner.js';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const webDist = path.resolve(__dirname, '../../web/dist');

ensureDirs();
initDb();
hookConsole();

const app = express();
app.set('trust proxy', true);
app.use(express.json({ limit: '2mb' }));

app.get('/api/health', (_req, res) => {
  res.json({ ok: true });
});

app.get('/api/logs', requireAuth, (_req, res) => {
  res.json({ logs: getLogBuffer() });
});

app.get('/api/me', (req, res) => {
  res.json({ authenticated: isAuthenticated(req) });
});

app.post('/api/login', (req, res) => {
  if (!loginRateLimit(req)) {
    return res.status(429).json({ error: '尝试过于频繁，请稍后再试' });
  }
  const { password } = req.body || {};
  if (!checkPassword(password)) {
    recordLoginFail(req);
    logger.warn('登录失败', { ip: req.ip });
    return res.status(401).json({ error: '密码错误' });
  }
  res.setHeader('Set-Cookie', createSessionCookie());
  logger.info('登录成功', { ip: req.ip });
  res.json({ ok: true });
});

app.post('/api/logout', (_req, res) => {
  res.setHeader('Set-Cookie', clearSessionCookie());
  res.json({ ok: true });
});

// 以下接口均需登录
app.use('/api/profiles', requireAuth, profilesRouter);
app.use('/api/models', requireAuth, modelsRouter);
app.use('/api/gallery', requireAuth, galleryRouter);
app.use('/api/tasks', requireAuth, tasksRouter);
app.use('/api/uploads', requireAuth, uploadsRouter);
app.use('/files', requireAuth, filesRouter);

// 生产托管前端构建产物（静态资源可匿名，登录页要能打开）
if (fs.existsSync(webDist)) {
  app.use(express.static(webDist));
  app.get('*', (req, res, next) => {
    if (req.path.startsWith('/api') || req.path.startsWith('/files')) return next();
    res.sendFile(path.join(webDist, 'index.html'));
  });
}

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: err.message || '服务器错误' });
});

const server = http.createServer(app);
attachLogSocket(server);

server.listen(config.port, () => {
  console.log(`[z-ai] server listening on http://localhost:${config.port}`);
  console.log(`[z-ai] auth: single password (AUTH_PASSWORD)`);
  console.log(`[z-ai] logs websocket: /ws/logs`);
  const resumed = resumeUnfinished();
  if (resumed > 0) console.log(`[z-ai] resumed ${resumed} unfinished task(s)`);
});
