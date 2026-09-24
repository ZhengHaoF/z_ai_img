import { Router } from 'express';
import { publicProfiles, getProfile } from '../config.js';
import { fetchUpstreamModels } from '../modelList.js';

const router = Router();

router.get('/', (_req, res) => {
  res.json(publicProfiles());
});

/** 模型列表：优先上游 /v1/models，失败回退 config.json。 */
router.get('/:id/models', async (req, res) => {
  const profile = getProfile(req.params.id);
  if (!profile) return res.status(404).json({ error: '配置不存在' });
  const result = await fetchUpstreamModels(profile.id);
  res.json({
    profileId: profile.id,
    source: result.source,
    models: result.models,
    defaultModel: result.models[0] || profile.defaultModel || '',
    error: result.error ?? null,
  });
});

export default router;
