import { WebSocketServer } from 'ws';
import { getLogBuffer, onLog } from './logBus.js';
import { onTaskEvent } from './taskBus.js';
import { isAuthenticated } from './auth.js';
import { listTaskRows, rowToTask } from './db.js';

/**
 * 统一 WS 通道：日志 + 任务事件。
 * 路径兼容 /ws/logs（旧）与 /ws/app（新），消息按 type 分发：
 *   { type: 'snapshot', logs }                 日志快照（保持旧格式，Logs.vue 兼容）
 *   { type: 'log', log }                       单条日志
 *   { type: 'tasks:snapshot', tasks, activeCount }  任务快照
 *   { type: 'task', task }                     任务新建/更新
 *   { type: 'task:removed', id }               任务删除
 */
export function attachLogSocket(server) {
  const wss = new WebSocketServer({ noServer: true });

  server.on('upgrade', (req, socket, head) => {
    const url = req.url || '';
    if (!url.startsWith('/ws/logs') && !url.startsWith('/ws/app')) {
      return;
    }
    // 复用 Cookie 会话鉴权
    const fakeReq = { headers: req.headers, ip: req.socket.remoteAddress };
    if (!isAuthenticated(fakeReq)) {
      socket.write('HTTP/1.1 401 Unauthorized\r\nConnection: close\r\n\r\n');
      socket.destroy();
      return;
    }
    wss.handleUpgrade(req, socket, head, (ws) => {
      wss.emit('connection', ws, req);
    });
  });

  wss.on('connection', (ws) => {
    // 连接即推快照：补上断线期间错过的事件
    const tasks = listTaskRows(50).map(rowToTask);
    const activeCount = tasks.filter((t) => t.status === 'queued' || t.status === 'running').length;
    ws.send(JSON.stringify({ type: 'snapshot', logs: getLogBuffer() }));
    ws.send(JSON.stringify({ type: 'tasks:snapshot', tasks, activeCount }));

    const offLog = onLog((entry) => {
      if (ws.readyState === ws.OPEN) {
        ws.send(JSON.stringify({ type: 'log', log: entry }));
      }
    });

    const offTask = onTaskEvent((event) => {
      if (ws.readyState === ws.OPEN) {
        ws.send(JSON.stringify(event));
      }
    });

    const cleanup = () => {
      offLog();
      offTask();
    };
    ws.on('close', cleanup);
    ws.on('error', cleanup);
  });

  return wss;
}
