export type TaskStatus = 'queued' | 'running' | 'succeeded' | 'failed' | 'canceled';

export type Protocol = 'openai' | 'compatible' | 'dashscope' | 'uuapi';

export interface ModelItem {
  id: string;
  label: string;
  baseUrl: string;
  protocol: Protocol;
  upstreamModel: string;
  enabled: boolean;
  hasKey: boolean;
}

export interface Task {
  id: string;
  type: 'generate' | 'edit';
  status: TaskStatus;
  profileId: string | null;
  params: {
    prompt: string;
    modelId?: string;
    model?: string;
    protocol?: string;
    size?: string;
    n?: number;
    images?: string[];
    mask?: string | null;
  };
  error: string | null;
  remoteTaskId?: string | null;
  createdAt: number;
  updatedAt: number;
  finishedAt: number | null;
  images: string[];
}

export interface SubmitPayload {
  type: 'generate' | 'edit';
  prompt: string;
  modelId: string;
  size?: string;
  n?: number;
  images?: string[];
  mask?: string | null;
}
