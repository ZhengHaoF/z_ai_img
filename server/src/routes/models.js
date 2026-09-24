import { Router } from 'express';
import {
  createModel,
  getModel,
  listModels,
  listRemoteModels,
  patchModel,
  removeModel,
  syncModelsFromUrl,
} from '../modelRegistry.js';

const router = Router();

router.get('/', (req, res) => {
  const enabledOnly = req.query.enabled === '1' || req.query.enabled === 'true';
  res.json({ models: listModels({ enabledOnly }) });
});

/** 试拉上游模型列表（不入库）。 */
router.post('/list-remote', async (req, res) => {
  try {
    const { baseUrl, apiKey } = req.body || {};
    const models = await listRemoteModels({ baseUrl, apiKey });
    res.json({ models });
  } catch (e) {
    res.status(400).json({ error: e.message || String(e) });
  }
});

/** 按 URL 同步并入库。 */
router.post('/sync', async (req, res) => {
  try {
    const { baseUrl, apiKey, protocol, enabled } = req.body || {};
    const result = await syncModelsFromUrl({ baseUrl, apiKey, protocol, enabled });
    res.json(result);
  } catch (e) {
    res.status(400).json({ error: e.message || String(e) });
  }
});

router.post('/', (req, res) => {
  try {
    const { label, baseUrl, protocol, upstreamModel, apiKey, enabled } = req.body || {};
    const model = createModel({
      label,
      baseUrl,
      protocol,
      upstreamModel,
      apiKey,
      enabled: enabled !== false,
    });
    res.status(201).json(model);
  } catch (e) {
    res.status(400).json({ error: e.message || String(e) });
  }
});

router.get('/:id', (req, res) => {
  const model = getModel(req.params.id);
  if (!model) return res.status(404).json({ error: '模型不存在' });
  res.json(model);
});

router.patch('/:id', (req, res) => {
  try {
    const model = patchModel(req.params.id, req.body || {});
    res.json(model);
  } catch (e) {
    res.status(400).json({ error: e.message || String(e) });
  }
});

router.delete('/:id', (req, res) => {
  try {
    removeModel(req.params.id);
    res.json({ ok: true });
  } catch (e) {
    res.status(400).json({ error: e.message || String(e) });
  }
});

export default router;
