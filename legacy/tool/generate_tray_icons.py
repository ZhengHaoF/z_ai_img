# -*- coding: utf-8 -*-
"""生成 Z Ai 应用托盘图标。

为 tray_manager 生成以下文件：
- assets/icons/tray_idle.png        (32x32, macOS/Linux)
- assets/icons/tray_loading.png
- assets/icons/tray_completed.png
- assets/icons/tray_error.png
- assets/icons/tray_idle.ico        (多尺寸, Windows)
- assets/icons/tray_loading.ico
- assets/icons/tray_completed.ico
- assets/icons/tray_error.ico

图标设计：圆角深紫底色 + 白色图形。
- idle:      画笔轮廓（灰色调，空闲）
- loading:   画笔 + 半透明外圈（蓝色调）
- completed: 白色对勾（绿色调）
- error:     白色感叹号（红色调）
"""
import os
from PIL import Image, ImageDraw

# 输出到项目根目录的 assets/icons（脚本位于 <项目根>/tool/ 下）
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT_DIR = os.path.join(PROJECT_ROOT, 'assets', 'icons')

# (名称, 底色, 图形颜色, 形态)
VARIANTS = [
    ('idle',      (0x66, 0x66, 0x66), 'idle'),
    ('loading',   (0x1E, 0x88, 0xE5), 'loading'),
    ('completed', (0x43, 0xA0, 0x47), 'completed'),
    ('error',     (0xE5, 0x39, 0x35), 'error'),
]

def draw_icon(size, bg, fg, shape):
    """绘制单个尺寸的托盘图标。"""
    # 4x 超采样抗锯齿
    s = size * 4
    img = Image.new('RGBA', (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # 圆角矩形背景（radius 约 22%）
    radius = int(s * 0.22)
    d.rounded_rectangle(
        [0, 0, s - 1, s - 1],
        radius=radius,
        fill=bg + (255,),
    )

    # 内边距
    pad = int(s * 0.22)
    x0, y0 = pad, pad
    x1, y1 = s - pad, s - pad
    cx, cy = s / 2, s / 2

    if shape == 'idle':
        # 画笔：斜放的铅笔轮廓
        # 用矩形 + 三角组合成一支画笔
        body_w = int(s * 0.20)
        body_h = int(s * 0.44)
        bx0 = int(cx - body_w / 2)
        by0 = int(cy - body_h / 2)
        bx1 = bx0 + body_w
        by1 = by0 + body_h
        # 笔身
        d.rounded_rectangle(
            [bx0, by0, bx1, by1],
            radius=int(body_w * 0.25),
            fill=fg + (255,),
        )
        # 笔尖（三角）
        tip_h = int(s * 0.14)
        d.polygon(
            [
                (bx0, by1 - 1),
                (bx1, by1 - 1),
                (cx, by1 + tip_h),
            ],
            fill=fg + (255,),
        )
        # 笔尖斜切
        d.line(
            [(bx0, by1 - 1), (cx, by1 + tip_h)],
            fill=bg + (255,),
            width=max(2, s // 64),
        )
        # 笔身装饰线
        d.line(
            [(bx0 + int(body_w * 0.3), by0 + int(body_h * 0.25)),
             (bx0 + int(body_w * 0.3), by1 - 1)],
            fill=bg + (180,),
            width=max(2, s // 64),
        )
    elif shape == 'loading':
        # 时钟：外圆 + 指针
        r = int(s * 0.26)
        bbox = [cx - r, cy - r, cx + r, cy + r]
        d.ellipse(bbox, outline=fg + (255,), width=max(3, s // 24))
        # 指针
        d.line(
            [(cx, cy), (cx, int(cy - r * 0.5))],
            fill=fg + (255,),
            width=max(3, s // 28),
        )
        d.line(
            [(cx, cy), (int(cx + r * 0.4), cy)],
            fill=fg + (255,),
            width=max(3, s // 28),
        )
        # 中心点
        d.ellipse(
            [cx - max(3, s // 28), cy - max(3, s // 28),
             cx + max(3, s // 28), cy + max(3, s // 28)],
            fill=fg + (255,),
        )
    elif shape == 'completed':
        # 对勾
        r = int(s * 0.26)
        lw = max(5, s // 14)
        d.line(
            [(int(cx - r * 0.4), cy), (int(cx - r * 0.05), int(cy + r * 0.35)),
             (int(cx + r * 0.45), int(cy - r * 0.35))],
            fill=fg + (255,),
            width=lw,
            joint='curve',
        )
    elif shape == 'error':
        # 感叹号
        lw = max(5, s // 14)
        r = int(s * 0.24)
        # 竖线
        d.line(
            [(cx, int(cy - r * 0.45)), (cx, int(cy + r * 0.3))],
            fill=fg + (255,),
            width=lw,
        )
        # 点
        dot_r = max(3, s // 26)
        d.ellipse(
            [cx - dot_r, int(cy + r * 0.62) - dot_r,
             cx + dot_r, int(cy + r * 0.62) + dot_r],
            fill=fg + (255,),
        )

    # 缩小到目标尺寸（LANCZOS 高质量）
    return img.resize((size, size), Image.LANCZOS)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    for name, bg, shape in VARIANTS:
        # 多尺寸 ICO（Windows）：16/24/32/48/64/128/256
        sizes = [16, 24, 32, 48, 64, 128, 256]
        ico_frames = [draw_icon(sz, bg, (255, 255, 255), shape) for sz in sizes]
        ico_path = os.path.join(OUT_DIR, f'tray_{name}.ico')
        ico_frames[0].save(
            ico_path,
            format='ICO',
            sizes=[(sz, sz) for sz in sizes],
            append_images=ico_frames[1:],
        )
        print(f'生成 {ico_path}')

    print('全部图标生成完成')


if __name__ == '__main__':
    main()