/**
 * 结果图落盘前重编码为 WebP（q80）。
 * 上游返回的 PNG 单张 2-3MB，重编码后约 250KB，网格/大图全场景省带宽。
 * sharp 懒加载：依赖缺失时回退原图直存，服务照常跑，只影响压缩率。
 */

let sharpPromise = null;
let sharpUnavailable = false;

function loadSharp() {
  if (sharpUnavailable) return Promise.resolve(null);
  if (!sharpPromise) {
    sharpPromise = import('sharp')
      .then((m) => m.default)
      .catch(() => {
        sharpUnavailable = true;
        return null;
      });
  }
  return sharpPromise;
}

/**
 * buffer → WebP（q80），文件名扩展名归一为 .webp。
 * 失败（sharp 不可用 / 解码失败）时原样返回，宁可大也不丢图。
 * 返回 { buffer, fileName }。
 */
export async function toWebpOrOriginal(buffer, fileName) {
  const sharp = await loadSharp();
  if (!sharp) return { buffer, fileName };
  try {
    const out = await sharp(buffer).webp({ quality: 80 }).toBuffer();
    return { buffer: out, fileName: fileName.replace(/\.[^.]+$/, '') + '.webp' };
  } catch {
    return { buffer, fileName };
  }
}
