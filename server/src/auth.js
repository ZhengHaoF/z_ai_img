import crypto from 'node:crypto';
import { config } from './config.js';

const COOKIE_NAME = 'zai_sid';
const failWindow = new Map(); // ip -> { count, resetAt }

function sign(exp) {
  return crypto
    .createHmac('sha256', config.authPassword)
    .update(String(exp))
    .digest('hex');
}

export function createSessionCookie() {
  const exp = Date.now() + config.sessionTtlMs;
  const token = `${exp}.${sign(exp)}`;
  return `${COOKIE_NAME}=${token}; Path=/; HttpOnly; SameSite=Lax; Max-Age=${Math.floor(config.sessionTtlMs / 1000)}`;
}

export function clearSessionCookie() {
  return `${COOKIE_NAME}=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0`;
}

function parseCookie(header) {
  const out = {};
  if (!header) return out;
  for (const part of header.split(';')) {
    const i = part.indexOf('=');
    if (i < 0) continue;
    out[part.slice(0, i).trim()] = decodeURIComponent(part.slice(i + 1).trim());
  }
  return out;
}

export function isAuthenticated(req) {
  const raw = parseCookie(req.headers.cookie)[COOKIE_NAME];
  if (!raw) return false;
  const dot = raw.indexOf('.');
  if (dot < 0) return false;
  const exp = Number(raw.slice(0, dot));
  const sig = raw.slice(dot + 1);
  if (!Number.isFinite(exp) || exp < Date.now()) return false;
  const expected = sign(exp);
  if (sig.length !== expected.length) return false;
  return crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected));
}

export function requireAuth(req, res, next) {
  if (isAuthenticated(req)) return next();
  return res.status(401).json({ error: '未登录或会话已过期' });
}

/** 简单按 IP 失败计数，防止弱口令被狂试。 */
export function loginRateLimit(req) {
  const ip = req.ip || req.socket.remoteAddress || 'unknown';
  const now = Date.now();
  const row = failWindow.get(ip);
  if (!row || row.resetAt < now) {
    failWindow.set(ip, { count: 0, resetAt: now + 10 * 60 * 1000 });
    return true;
  }
  return row.count < 10;
}

export function recordLoginFail(req) {
  const ip = req.ip || req.socket.remoteAddress || 'unknown';
  const now = Date.now();
  const row = failWindow.get(ip) || { count: 0, resetAt: now + 10 * 60 * 1000 };
  row.count += 1;
  failWindow.set(ip, row);
}

export function checkPassword(password) {
  const a = Buffer.from(String(password ?? ''));
  const b = Buffer.from(config.authPassword);
  if (a.length !== b.length) return false;
  return crypto.timingSafeEqual(a, b);
}
