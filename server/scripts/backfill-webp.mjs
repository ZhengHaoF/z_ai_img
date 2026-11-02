/**
 * 存量结果图转 WebP（一次性回填）。
 * 遍历 results 表：data/images 下的 .png/.jpg → 转码 .webp → 更新 DB file_name → 删原图。
 * 用法：cd server && node scripts/backfill-webp.mjs
 */
import fs from 'node:fs';
import path from 'node:path';
import { config, ensureDirs } from '../src/config.js';
import { initDb, listAllImages, updateResultFileName } from '../src/db.js';
import { toWebpOrOriginal } from '../src/imageConvert.js';

ensureDirs();
initDb();

const rows = listAllImages(2000);
let ok = 0;
let skip = 0;
let fail = 0;
let savedBytes = 0;

for (const r of rows) {
  const name = path.basename(r.file_name);
  const src = path.join(config.imagesDir, name);
  if (name.endsWith('.webp')) {
    skip++;
    continue;
  }
  if (!fs.existsSync(src)) {
    skip++;
    continue;
  }
  try {
    const buf = fs.readFileSync(src);
    const out = await toWebpOrOriginal(buf, name);
    if (out.fileName === name) {
      // 转码失败回退，原样保留
      skip++;
      console.log('SKIP(转码失败)', name);
      continue;
    }
    fs.writeFileSync(path.join(config.imagesDir, out.fileName), out.buffer);
    updateResultFileName(name, out.fileName);
    fs.unlinkSync(src);
    savedBytes += buf.length - out.buffer.length;
    ok++;
    console.log(
      'OK',
      name,
      '→',
      out.fileName,
      (buf.length / 1048576).toFixed(2) + 'MB',
      '→',
      (out.buffer.length / 1024).toFixed(0) + 'KB',
    );
  } catch (e) {
    fail++;
    console.error('FAIL', name, e.message);
  }
}

console.log(
  `done: ok=${ok} skip=${skip} fail=${fail}, 节省 ${(savedBytes / 1048576).toFixed(1)}MB`,
);
