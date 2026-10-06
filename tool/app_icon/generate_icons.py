"""生成 Now Todo 的 Android 图标资源。

用法（在仓库根目录跑）：

    python tool/app_icon/generate_icons.py

产物**会提交进仓库**（`android/app/src/main/res/` 下的 PNG 与商店用的
`docs/store/icon-512.png`），所以克隆后不跑这个脚本也能构建。
它的价值是「这个图标是怎么来的」可复现、可微调，而不是每次构建都要跑一遍。

设计：一个开口朝上的环 ＋ 中心一个勾。
环是专注计时的进度环，勾是「做完了」——应用的两个子系统各出一个符号，
合起来仍然是一个 48px 下能认出来的形状。

**自适应图标的安全区**：Android 的前景层是 108dp 画布，可见区只有中间的
72dp，而**保证**不被任何启动器遮罩切掉的是中间直径 66dp 的圆。所以前景层
里环的外径取 60dp（0.5556 画布），小于 66dp。传统图标（非自适应）没有遮罩
问题，环取 0.62 画布，视觉重量更足。

需要 Pillow（`pip install pillow`）。
"""

from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw

REPO_ROOT = Path(__file__).resolve().parents[2]
RES_DIR = REPO_ROOT / "android" / "app" / "src" / "main" / "res"
STORE_DIR = REPO_ROOT / "docs" / "store"

# 与 `lib/core/theme/app_theme.dart` 的 `AppTheme.seed` 同源：
# 低饱和深青。图标跟着主题走，应用内外是同一个颜色。
BRAND_TOP = (0x35, 0x7A, 0x6B)
BRAND_BOTTOM = (0x1F, 0x4B, 0x42)
RING = (0x8F, 0xE0, 0xC8)
CHECK = (0xFF, 0xFF, 0xFF)

# 每档密度：传统图标边长 / 自适应前景层画布边长（108dp）。单位都是 px。
DENSITIES = (
    ("mdpi", 48, 108),
    ("hdpi", 72, 162),
    ("xhdpi", 96, 216),
    ("xxhdpi", 144, 324),
    ("xxxhdpi", 192, 432),
)

SUPERSAMPLE = 8  # 先画大图再缩小，当作抗锯齿
RING_SWEEP_DEGREES = 300.0  # 开口 60°，缺口在正上方（12 点）


def _vertical_gradient(size: int, top: tuple[int, int, int], bottom: tuple[int, int, int]) -> Image.Image:
    """画一张竖直渐变。逐行填色，行数就是边长，成本可以忽略。"""
    image = Image.new("RGB", (size, size))
    draw = ImageDraw.Draw(image)
    for y in range(size):
        ratio = y / max(size - 1, 1)
        color = tuple(round(top[i] + (bottom[i] - top[i]) * ratio) for i in range(3))
        draw.line([(0, y), (size, y)], fill=color)
    return image


def _polar(cx: float, cy: float, radius: float, degrees: float) -> tuple[float, float]:
    """极坐标转直角坐标。Pillow 的角度定义：0° 在 3 点方向，顺时针增大。"""
    radians = math.radians(degrees)
    return cx + radius * math.cos(radians), cy + radius * math.sin(radians)


def draw_mark(
    canvas: Image.Image,
    *,
    center: tuple[float, float],
    box: float,
    ring_color: tuple[int, int, int, int] | tuple[int, int, int],
    check_color: tuple[int, int, int, int] | tuple[int, int, int],
) -> None:
    """在 `canvas` 上画「环 + 勾」。

    [box] 是符号的外接正方形边长：环的外径就等于它，勾画在它里面。
    """
    draw = ImageDraw.Draw(canvas)
    cx, cy = center

    outer_radius = box / 2
    stroke = box * 0.115
    ring_radius = outer_radius - stroke / 2  # 环的**中心线**半径
    arc_box = (
        (cx - ring_radius, cy - ring_radius),
        (cx + ring_radius, cy + ring_radius),
    )

    # 缺口居中在正上方（12 点，Pillow 里是 270°）：环从缺口右侧起笔，逆时针绕回来。
    # 缺口朝上而不是朝右，是因为应用图标会被各种形状的遮罩切——缺口朝上在圆形、
    # 方形、水滴形遮罩下都对称，朝右则会在方形遮罩里显得偏。
    start = 270.0 + (360.0 - RING_SWEEP_DEGREES) / 2
    end = start + RING_SWEEP_DEGREES
    draw.arc(arc_box, start=start, end=end, fill=ring_color, width=round(stroke))
    # 两端补圆头。`arc` 只画方头，圆头得自己补两个圆。
    for degrees in (start, end):
        px, py = _polar(cx, cy, ring_radius, degrees)
        draw.ellipse(
            (px - stroke / 2, py - stroke / 2, px + stroke / 2, py + stroke / 2),
            fill=ring_color,
        )

    # 勾：三条点连成的折线，加圆头与圆角关节。
    # 比环细一点点（0.105 对 0.115）：环是容器、勾是内容，粗细相等会互相抢，
    # 勾更粗则整张图会显得头重脚轻。
    check_stroke = box * 0.105
    points = [
        (cx - box * 0.135, cy + box * 0.005),
        (cx - box * 0.035, cy + box * 0.105),
        (cx + box * 0.145, cy - box * 0.095),
    ]
    draw.line(points, fill=check_color, width=round(check_stroke), joint="curve")
    for px, py in (points[0], points[-1]):
        draw.ellipse(
            (
                px - check_stroke / 2,
                py - check_stroke / 2,
                px + check_stroke / 2,
                py + check_stroke / 2,
            ),
            fill=check_color,
        )


def legacy_icon(size: int) -> Image.Image:
    """传统启动图标：铺满画布的圆角方块（各家的矩形遮罩会自己再切一次）。"""
    canvas_size = size * SUPERSAMPLE
    base = _vertical_gradient(canvas_size, BRAND_TOP, BRAND_BOTTOM)

    # 先画成圆角，再贴到透明底上——旧版 Android 不做遮罩，圆角就是最终的形状。
    mask = Image.new("L", (canvas_size, canvas_size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, canvas_size - 1, canvas_size - 1),
        radius=round(canvas_size * 0.22),
        fill=255,
    )
    icon = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    icon.paste(base, (0, 0), mask)

    draw_mark(
        icon,
        center=(canvas_size / 2, canvas_size / 2),
        box=canvas_size * 0.62,
        ring_color=RING,
        check_color=CHECK,
    )
    return icon.resize((size, size), Image.LANCZOS)


def adaptive_foreground(size: int, *, color: tuple[int, int, int]) -> Image.Image:
    """自适应图标的前景 / 单色层：透明底，符号收在 66dp 安全圆内。

    单色层（[color] 传白色）由系统按用户主题染色，形状必须和前景层一致，
    否则开「主题图标」之后应用的样子跟别人不一样。
    """
    canvas_size = size * SUPERSAMPLE
    layer = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    draw_mark(
        layer,
        center=(canvas_size / 2, canvas_size / 2),
        box=canvas_size * (60.0 / 108.0),
        ring_color=color,
        check_color=color,
    )
    return layer.resize((size, size), Image.LANCZOS)


def safe_zone_check(layer: Image.Image) -> float:
    """返回前景层里「离中心最远的非透明像素」的半径（相对画布边长的比例）。

    Android 保证不被裁的是直径 66dp 的圆，也就是半径 33/108 ≈ 0.3056 画布。
    超过它就会被某些启动器的遮罩切到，所以这里直接量出来。
    """
    alpha = layer.getchannel("A")
    width, height = layer.size
    cx, cy = width / 2, height / 2
    farthest = 0.0
    pixels = alpha.load()
    for y in range(height):
        for x in range(width):
            if pixels[x, y] > 8:
                farthest = max(farthest, math.hypot(x - cx, y - cy))
    return farthest / width


def write_png(image: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, format="PNG", optimize=True)


def main() -> None:
    for name, legacy_size, foreground_size in DENSITIES:
        target = RES_DIR / f"mipmap-{name}"
        write_png(legacy_icon(legacy_size), target / "ic_launcher.png")
        foreground = adaptive_foreground(foreground_size, color=(*RING, 255))
        write_png(foreground, target / "ic_launcher_foreground.png")
        write_png(
            adaptive_foreground(foreground_size, color=(255, 255, 255, 255)),
            target / "ic_launcher_monochrome.png",
        )

    # Google Play 要一张 512×512 的方图，不能有圆角也不能有透明边。
    # 用 RGB 而不是 RGBA 保存：商店那张图的透明通道只会带来风险
    # （有些工具会拿 alpha 当遮罩），而它本来就该是不透明的方块。
    store_size = 512
    canvas_size = store_size * SUPERSAMPLE
    store = _vertical_gradient(canvas_size, BRAND_TOP, BRAND_BOTTOM)
    draw_mark(
        store,
        center=(canvas_size / 2, canvas_size / 2),
        box=canvas_size * 0.62,
        ring_color=RING,
        check_color=CHECK,
    )
    write_png(store.resize((store_size, store_size), Image.LANCZOS), STORE_DIR / "icon-512.png")

    # 自检：安全区是硬约束，靠眼睛看不出来（差几个像素在 48px 上没区别，
    # 在圆角遮罩上就是缺一角），所以每次生成都量一遍。
    probe = adaptive_foreground(432, color=(*RING, 255))
    ratio = safe_zone_check(probe)
    limit = 33.0 / 108.0
    print(f"前景层最远像素半径 {ratio:.4f} 画布（上限 {limit:.4f}）：{'OK' if ratio <= limit else '超了'}")
    if ratio > limit:
        raise SystemExit("符号超出了自适应图标的安全圆，启动器遮罩会切到它。")

    print(f"图标已写入 {RES_DIR}（{len(DENSITIES)} 档密度）与 {STORE_DIR / 'icon-512.png'}")


if __name__ == "__main__":
    main()
