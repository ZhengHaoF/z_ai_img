import { DatabaseSync } from 'node:sqlite';
import { config, ensureDirs } from './config.js';

let db;

export function initDb() {
  ensureDirs();
  db = new DatabaseSync(config.dbPath);
  db.exec(`
    CREATE TABLE IF NOT EXISTS tasks (
      id TEXT PRIMARY KEY,
      type TEXT NOT NULL,
      status TEXT NOT NULL,
      profile_id TEXT,
      params_json TEXT NOT NULL,
      error TEXT,
      created_at INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      finished_at INTEGER,
      remote_task_id TEXT
    );
    CREATE TABLE IF NOT EXISTS results (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      task_id TEXT NOT NULL,
      file_name TEXT NOT NULL,
      created_at INTEGER NOT NULL
    );
    CREATE TABLE IF NOT EXISTS models (
      id TEXT PRIMARY KEY,
      label TEXT NOT NULL,
      base_url TEXT NOT NULL,
      protocol TEXT NOT NULL,
      upstream_model TEXT NOT NULL,
      api_key TEXT NOT NULL DEFAULT '',
      enabled INTEGER NOT NULL DEFAULT 1,
      created_at INTEGER NOT NULL
    );
  `);
  // 旧任务表无 remote_task_id 时补列
  const taskCols = db.prepare('PRAGMA table_info(tasks)').all();
  if (!taskCols.some((c) => c.name === 'remote_task_id')) {
    db.exec('ALTER TABLE tasks ADD COLUMN remote_task_id TEXT');
  }
  // 旧表（profile_id 版）无 base_url 时重建
  const cols = db.prepare('PRAGMA table_info(models)').all();
  if (!cols.some((c) => c.name === 'base_url')) {
    db.exec('DROP TABLE IF EXISTS models');
    db.exec(`
      CREATE TABLE models (
        id TEXT PRIMARY KEY,
        label TEXT NOT NULL,
        base_url TEXT NOT NULL,
        protocol TEXT NOT NULL,
        upstream_model TEXT NOT NULL,
        api_key TEXT NOT NULL DEFAULT '',
        enabled INTEGER NOT NULL DEFAULT 1,
        created_at INTEGER NOT NULL
      );
    `);
  }
  return db;
}

export function getDb() {
  if (!db) initDb();
  return db;
}

export function insertTask(task) {
  getDb()
    .prepare(
      `INSERT INTO tasks (id, type, status, profile_id, params_json, error, created_at, updated_at, finished_at, remote_task_id)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    )
    .run(
      task.id,
      task.type,
      task.status,
      task.profileId,
      JSON.stringify(task.params),
      task.error ?? null,
      task.createdAt,
      task.updatedAt,
      task.finishedAt ?? null,
      task.remoteTaskId ?? null,
    );
}

export function listUnfinishedTaskRows() {
  return getDb()
    .prepare(`SELECT * FROM tasks WHERE status IN ('queued','running') ORDER BY created_at`)
    .all();
}

export function updateTask(id, fields) {
  const keys = Object.keys(fields);
  if (keys.length === 0) return;
  const sets = keys.map((k) => `${snake(k)} = ?`).join(', ');
  const values = keys.map((k) => {
    const v = fields[k];
    return k === 'params' ? JSON.stringify(v) : v;
  });
  getDb()
    .prepare(`UPDATE tasks SET ${sets} WHERE id = ?`)
    .run(...values, id);
}

export function getTaskRow(id) {
  return getDb().prepare('SELECT * FROM tasks WHERE id = ?').get(id);
}

export function listTaskRows(limit = 50) {
  return getDb()
    .prepare('SELECT * FROM tasks ORDER BY created_at DESC LIMIT ?')
    .all(limit);
}

export function insertResult(taskId, fileName) {
  getDb()
    .prepare('INSERT INTO results (task_id, file_name, created_at) VALUES (?, ?, ?)')
    .run(taskId, fileName, Date.now());
}

export function listResults(taskId) {
  return getDb()
    .prepare('SELECT file_name FROM results WHERE task_id = ? ORDER BY id')
    .all(taskId)
    .map((r) => r.file_name);
}

/** 全部结果图（含任务信息），按时间倒序。 */
export function listAllImages(limit = 200) {
  const rows = getDb()
    .prepare(
      `SELECT r.id, r.file_name, r.task_id, r.created_at,
              t.params_json, t.type, t.status
       FROM results r
       LEFT JOIN tasks t ON t.id = r.task_id
       ORDER BY r.created_at DESC
       LIMIT ?`,
    )
    .all(limit);
  return rows.map((r) => {
    let prompt = '';
    try {
      prompt = JSON.parse(r.params_json || '{}')?.prompt || '';
    } catch {
      /* ignore */
    }
    return { ...r, prompt };
  });
}

export function findResultByFile(fileName) {
  return getDb().prepare('SELECT * FROM results WHERE file_name = ?').get(fileName);
}

export function deleteResultByFile(fileName) {
  getDb().prepare('DELETE FROM results WHERE file_name = ?').run(fileName);
}

export function deleteResultsByTask(taskId) {
  getDb().prepare('DELETE FROM results WHERE task_id = ?').run(taskId);
}

export function deleteTask(id) {
  getDb().prepare('DELETE FROM tasks WHERE id = ?').run(id);
}

export function getTaskRowById(id) {
  return getTaskRow(id);
}

export function rowToTask(row) {
  if (!row) return null;
  return {
    id: row.id,
    type: row.type,
    status: row.status,
    profileId: row.profile_id,
    params: JSON.parse(row.params_json),
    error: row.error,
    remoteTaskId: row.remote_task_id ?? null,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
    finishedAt: row.finished_at,
    images: listResults(row.id).map((f) => `/files/${f}`),
  };
}

export function listModelRows({ enabledOnly = false } = {}) {
  const sql = enabledOnly
    ? 'SELECT * FROM models WHERE enabled = 1 ORDER BY created_at, label'
    : 'SELECT * FROM models ORDER BY created_at, label';
  return getDb().prepare(sql).all();
}

export function getModelRow(id) {
  return getDb().prepare('SELECT * FROM models WHERE id = ?').get(id);
}

export function insertModel(m) {
  getDb()
    .prepare(
      `INSERT INTO models (id, label, base_url, protocol, upstream_model, api_key, enabled, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
    )
    .run(
      m.id,
      m.label,
      m.baseUrl,
      m.protocol,
      m.upstreamModel,
      m.apiKey ?? '',
      m.enabled ? 1 : 0,
      m.createdAt ?? Date.now(),
    );
}

export function updateModel(id, fields) {
  const map = {
    label: 'label',
    baseUrl: 'base_url',
    protocol: 'protocol',
    upstreamModel: 'upstream_model',
    apiKey: 'api_key',
    enabled: 'enabled',
  };
  const sets = [];
  const values = [];
  for (const [k, col] of Object.entries(map)) {
    if (fields[k] === undefined) continue;
    sets.push(`${col} = ?`);
    values.push(k === 'enabled' ? (fields[k] ? 1 : 0) : fields[k]);
  }
  if (!sets.length) return;
  getDb().prepare(`UPDATE models SET ${sets.join(', ')} WHERE id = ?`).run(...values, id);
}

export function deleteModel(id) {
  getDb().prepare('DELETE FROM models WHERE id = ?').run(id);
}

export function findModelByUpstream(baseUrl, upstreamModel) {
  return getDb()
    .prepare('SELECT * FROM models WHERE base_url = ? AND upstream_model = ?')
    .get(baseUrl, upstreamModel);
}

function snake(key) {
  return key.replace(/[A-Z]/g, (c) => `_${c.toLowerCase()}`);
}
