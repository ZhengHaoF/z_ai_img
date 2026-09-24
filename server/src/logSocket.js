import { WebSocketServer } from 'ws';
import { getLogBuffer, onLog } from './logBus.js';
import { isAuthenticated } from './auth.js';

export function attachLogSocket(server) {
  const wss = new WebSocketServer({ noServer: true });

  server.on('upgrade', (req, socket, head) => {
    const url = req.url || '';
    if (!url.startsWith('/ws/logs')) {
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
    ws.send(
      JSON.stringify({
        type: 'snapshot',
        logs: getLogBuffer(),
      }),
    );

    const off = onLog((entry) => {
      if (ws.readyState === ws.OPEN) {
        ws.send(JSON.stringify({ type: 'log', log: entry }));
      }
    });

    ws.on('close', () => off());
    ws.on('error', () => off());
  });

  return wss;
}
