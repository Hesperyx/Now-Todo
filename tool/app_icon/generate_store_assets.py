"""生成商店用的特色图片（Google Play 的 feature graphic，1024×500）。

用法（在仓库根目录跑）：

    python tool/app_icon/generate_store_assets.py
    python tool/app_icon/generate_store_assets.py --font "C:\\Windows\\Fonts\\msyhbd.ttc"

产物 `docs/store/feature-graphic.png` **会提交进仓库**，和图标一样：克隆后不跑
脚本也有素材可用，脚本的作用是「这张图怎么来的」可复现。

画的是同一套品牌语言：`generate_icons.py` 里的渐变 + 标记（环 + 勾），
右边放应用名与一句话说明。颜色不在这里另写一份，直接引用那个模块的常量，
免得哪天主题色改了、图标变了、特色图片还是旧颜色。

**中文字体是硬要求**：特色图片上有中文，找不到字体会直接报错退出，而不是悄悄
生成一张英文的——那样仓库里会出现两份风格不一致的素材，谁都不会注意到。
换机器生成时用 `--font` 指定一份中文字体即可。
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

# 同目录的图标脚本：常量与画标记的函数都从那里来，只有一份定义。
sys.path.insert(0, str(Path(__file__).resolve().parent))
import generate_icons as icons  # noqa: E402

REPO_ROOT = Path(__file__).resolve().parents[2]
OUT_PATH = REPO_ROOT / "docs" / "store" / "feature-graphic.png"

WIDTH, HEIGHT = 1024, 500

# 常见的中文字体位置。找不到就报错，让调用方用 `--font` 显式指定。
FONT_CANDIDATES = (
    r"C:\Windows\Fonts\msyhbd.ttc",  # Windows：微软雅黑 Bold
    r"C:\Windows\Fonts\msyh.ttc",
    r"C:\Windows\Fonts\simhei.ttf",
    "/System/Library/Fonts/PingFang.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/truetype/wqy/wqy-zenhei.ttc",
)

TITLE = "Now Todo"
TAGLINE = "离线优先的待办与专注计时"
SUBTLINE = "无需账号 · 没有联网权限"

PADDING = 72
MARK_BOX = 208
TEXT_GAP = 60
RULE_WIDTH = 132

TITLE_SIZE = 84
TAGLINE_SIZE = 34
SUBLINE_SIZE = 28
RULE_HEIGHT = 4
RULE_GAP = 22
LINE_GAP = 14

MINT = (*icons.RING, 255)
WHITE = (255, 255, 255, 255)
SOFT_WHITE = (255, 255, 255, 200)


def gradient(size: tuple[int, int]) -> Image.Image:
    """整幅竖直渐变，取的是图标那套品牌色。逐行填，1024×500 的成本可以忽略。"""
    width, height = size
    image = Image.new("RGB", size)
    draw = ImageDraw.Draw(image)
    for y in range(height):
        ratio = y / max(height - 1, 1)
        color = tuple(
            round(
                icons.BRAND_TOP[i]
                + (icons.BRAND_BOTTOM[i] - icons.BRAND_TOP[i]) * ratio
            )
            for i in range(3)
        )
        draw.line([(0, y), (width, y)], fill=color)
    return image


def find_font(explicit: str | None) -> Path:
    """挑一份中文字体。显式指定优先，否则按候选列表找，都没有就退出。"""
    if explicit:
        path = Path(explicit)
        if not path.is_file():
            raise SystemExit(f"--font 指向的文件不存在：{path}")
        return path
    for candidate in FONT_CANDIDATES:
        path = Path(candidate)
        if path.is_file():
            return path
    raise SystemExit(
        "找不到中文字体。用 `--font <字体文件>` 指定一份再跑：\n  "
        + "\n  ".join(FONT_CANDIDATES)
    )


def load_font(font_path: Path, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(font_path), size)


def text_bbox(font: ImageFont.FreeTypeFont, text: str) -> tuple[int, int, int, int]:
    """量一行字的包围盒。

    原点用 Pillow 默认的「左边 + 上伸部顶」：这样 `textbbox` 与 `draw.text` 的
    坐标系一致，量出来的 `[1]` 就是字形顶相对基线的空隙，排版时能直接减掉。
    """
    scratch = ImageDraw.Draw(Image.new("RGBA", (1, 1)))
    return scratch.textbbox((0, 0), text, font=font)


def text_height(font: ImageFont.FreeTypeFont, text: str) -> int:
    box = text_bbox(font, text)
    return box[3] - box[1]


def draw_text(
    canvas: Image.Image,
    font: ImageFont.FreeTypeFont,
    *,
    text: str,
    xy: tuple[int, int],
    fill: tuple[int, int, int, int],
) -> None:
    ImageDraw.Draw(canvas).text(xy, text, font=font, fill=fill)


def main() -> None:
    parser = argparse.ArgumentParser(description="生成商店特色图片")
    parser.add_argument("--font", help="中文字体文件；不传则在常见位置里找")
    args = parser.parse_args()

    font_path = find_font(args.font)
    title_font = load_font(font_path, TITLE_SIZE)
    tagline_font = load_font(font_path, TAGLINE_SIZE)
    subline_font = load_font(font_path, SUBLINE_SIZE)

    canvas = gradient((WIDTH, HEIGHT)).convert("RGBA")

    # 左边：品牌标记。右边：应用名 + 分隔线 + 两行说明，整体竖直居中。
    #
    # 横向按「标记 + 间隔 + 最宽的一行字」整体居中，而不是从固定边距往右排：
    # 说明文字只有十几字，从左边距排会让右边空出一大块，看着像没排完。
    widest_text = max(
        text_bbox(font, line)[2]
        for font, line in (
            (title_font, TITLE),
            (tagline_font, TAGLINE),
            (subline_font, SUBTLINE),
        )
    )
    block_width = MARK_BOX + TEXT_GAP + widest_text
    block_left = max(PADDING, (WIDTH - block_width) / 2)

    icons.draw_mark(
        canvas,
        center=(block_left + MARK_BOX / 2, HEIGHT / 2),
        box=MARK_BOX,
        ring_color=MINT,
        check_color=WHITE,
    )

    text_left = int(block_left + MARK_BOX + TEXT_GAP)
    block_height = (
        text_height(title_font, TITLE)
        + RULE_GAP
        + RULE_HEIGHT
        + RULE_GAP
        + text_height(tagline_font, TAGLINE)
        + LINE_GAP
        + text_height(subline_font, SUBTLINE)
    )
    top = int((HEIGHT - block_height) / 2)

    draw_text(
        canvas,
        title_font,
        text=TITLE,
        xy=(text_left, top - text_bbox(title_font, TITLE)[1]),
        fill=WHITE,
    )

    rule_y = top + text_height(title_font, TITLE) + RULE_GAP
    ImageDraw.Draw(canvas).rectangle(
        (text_left, rule_y, text_left + RULE_WIDTH, rule_y + RULE_HEIGHT),
        fill=MINT,
    )

    tagline_y = rule_y + RULE_HEIGHT + RULE_GAP
    draw_text(
        canvas,
        tagline_font,
        text=TAGLINE,
        xy=(text_left, tagline_y),
        fill=MINT,
    )
    draw_text(
        canvas,
        subline_font,
        text=SUBTLINE,
        xy=(text_left, tagline_y + text_height(tagline_font, TAGLINE) + LINE_GAP),
        fill=SOFT_WHITE,
    )

    # 商店要的是 24 位 PNG / JPEG，不能带透明通道。
    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(OUT_PATH, format="PNG", optimize=True)

    saved = Image.open(OUT_PATH)
    if saved.size != (WIDTH, HEIGHT) or saved.mode != "RGB":
        raise SystemExit(f"产物不对：{saved.size} {saved.mode}")
    print(f"特色图片已写入 {OUT_PATH}（{saved.size[0]}×{saved.size[1]}，{saved.mode}）")
    print(f"中文字体：{font_path}")


if __name__ == "__main__":
    main()
