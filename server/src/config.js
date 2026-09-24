import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import dotenv from 'dotenv';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const serverRoot = path.resolve(__dirname, '..');

dotenv.config({ path: path.join(serverRoot, '.env') });

function loadConfig() {
  const raw = fs.readFileSync(path.join(serverRoot, 'config.json'), 'utf8');
  return JSON.parse(raw);
}

const configJson = loadConfig();

export const config = {
  port: Number(process.env.PORT || 3000),
  dataDir: path.resolve(serverRoot, process.env.DATA_DIR || './data'),
  imagesDir: path.resolve(serverRoot, process.env.DATA_DIR || './data', 'images'),
  uploadsDir: path.resolve(serverRoot, process.env.DATA_DIR || './data', 'uploads'),
  dbPath: path.resolve(serverRoot, process.env.DATA_DIR || './data', 'tasks.db'),
  activeProfileId: configJson.activeProfileId,
  profiles: configJson.profiles.map((p) => ({
    ...p,
    apiKey: process.env[p.apiKeyEnv] || '',
    hasKey: Boolean(process.env[p.apiKeyEnv]),
  })),
  maxUploadBytes: 10 * 1024 * 1024,
  concurrentTasks: 2,
  upstreamTimeoutMs: 10 * 60 * 1000,
  /** 个人站单密码；请在 .env 覆盖，勿用弱口令暴露公网 */
  authPassword: process.env.AUTH_PASSWORD || '123456',
  sessionTtlMs: 30 * 24 * 60 * 60 * 1000,
};

export function ensureDirs() {
  for (const dir of [config.dataDir, config.imagesDir, config.uploadsDir]) {
    fs.mkdirSync(dir, { recursive: true });
  }
}

export function getProfile(profileId) {
  const id = profileId || config.activeProfileId;
  return config.profiles.find((p) => p.id === id) || null;
}

/** 返回给前端的配置元数据（无密钥）。 */
export function publicProfiles() {
  return {
    activeProfileId: config.activeProfileId,
    profiles: config.profiles.map((p) => ({
      id: p.id,
      name: p.name,
      protocol: p.protocol,
      defaultModel: p.defaultModel,
      models: p.models,
      defaultSize: p.defaultSize,
      defaultCount: p.defaultCount,
      hasKey: p.hasKey,
    })),
  };
}
