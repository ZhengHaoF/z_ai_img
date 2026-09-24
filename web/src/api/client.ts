import type { ModelItem, SubmitPayload, Task } from '../types';

export class AuthError extends Error {
  constructor() {
    super('未登录');
  }
}

async function jsonFetch<T>(url: string, init?: RequestInit): Promise<T> {
  const res = await fetch(url, { credentials: 'same-origin', ...init });
  if (res.status === 401) throw new AuthError();
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    throw new Error((data as { error?: string }).error || `HTTP ${res.status}`);
  }
  return data as T;
}

export function checkAuth() {
  return jsonFetch<{ authenticated: boolean }>('/api/me');
}

export function login(password: string) {
  return jsonFetch<{ ok: boolean }>('/api/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ password }),
  });
}

export function logout() {
  return jsonFetch<{ ok: boolean }>('/api/logout', { method: 'POST' });
}

export function fetchModels(enabledOnly = true) {
  const q = enabledOnly ? '?enabled=1' : '';
  return jsonFetch<{ models: ModelItem[] }>(`/api/models${q}`);
}

export function createModel(body: {
  label?: string;
  baseUrl: string;
  protocol: 'openai' | 'compatible' | 'dashscope' | 'uuapi';
  upstreamModel: string;
  apiKey?: string;
  enabled?: boolean;
}) {
  return jsonFetch<ModelItem>('/api/models', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

export function updateModel(
  id: string,
  body: {
    label?: string;
    baseUrl?: string;
    protocol?: 'openai' | 'compatible' | 'dashscope' | 'uuapi';
    upstreamModel?: string;
    apiKey?: string;
    enabled?: boolean;
  },
) {
  return jsonFetch<ModelItem>(`/api/models/${id}`, {
    method: 'PATCH',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

export function deleteModel(id: string) {
  return jsonFetch<{ ok: boolean }>(`/api/models/${id}`, { method: 'DELETE' });
}

export function listRemoteModels(body: { baseUrl: string; apiKey?: string }) {
  return jsonFetch<{ models: string[] }>('/api/models/list-remote', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

export function syncModels(body: {
  baseUrl: string;
  apiKey?: string;
  protocol: 'openai' | 'compatible';
  enabled?: boolean;
}) {
  return jsonFetch<{
    added: ModelItem[];
    skipped: unknown[];
    models: ModelItem[];
  }>('/api/models/sync', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
  });
}

export function submitTask(payload: SubmitPayload) {
  return jsonFetch<{ id: string; status: string }>('/api/tasks', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
}

export function fetchTask(id: string) {
  return jsonFetch<Task>(`/api/tasks/${id}`);
}

export function cancelTask(id: string) {
  return jsonFetch<Task>(`/api/tasks/${id}/cancel`, { method: 'POST' });
}

export function fetchTasks() {
  return jsonFetch<{ tasks: Task[] }>('/api/tasks');
}

export interface GalleryImage {
  id: number;
  fileName: string;
  taskId: string | null;
  prompt: string;
  type: string;
  createdAt: number;
  url: string;
}

export function fetchGallery(limit = 200) {
  return jsonFetch<{ images: GalleryImage[] }>(`/api/gallery?limit=${limit}`);
}

export function deleteGalleryImage(fileName: string) {
  return jsonFetch<{ ok: boolean }>(
    `/api/gallery/${encodeURIComponent(fileName)}`,
    { method: 'DELETE' },
  );
}

export function deleteGalleryTask(taskId: string) {
  return jsonFetch<{ ok: boolean; deletedImages: number }>(
    `/api/gallery/task/${encodeURIComponent(taskId)}`,
    { method: 'DELETE' },
  );
}

export async function uploadFiles(files: File[]): Promise<string[]> {
  const form = new FormData();
  for (const f of files) form.append('files', f);
  const data = await jsonFetch<{ files: string[] }>('/api/uploads', {
    method: 'POST',
    body: form,
  });
  return data.files;
}
