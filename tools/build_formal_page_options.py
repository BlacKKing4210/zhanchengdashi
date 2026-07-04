from __future__ import annotations

import shutil
import math
from dataclasses import dataclass
from datetime import date
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Image as PdfImage
from reportlab.platypus import PageBreak, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


ROOT = Path(__file__).resolve().parents[1]
OUT_DIR = ROOT / "output" / "formal_page_options"
PDF_PATH = ROOT / "output" / "pdf" / "formal-page-style-options.pdf"
DOC_PATH = ROOT / "docs" / "FORMAL_PAGE_STYLE_OPTIONS.md"

W, H = 720, 1280

GENERATED_BG_DIR = Path(
    "C:/Users/76398/.codex/generated_images/019f2d94-319e-74c3-bc15-8a69573fe2c9"
)

BG_SOURCES = [
    GENERATED_BG_DIR / "ig_01bf6f6f285a2d64016a491e59b088819897c27be02f11176e.png",
    GENERATED_BG_DIR / "ig_01bf6f6f285a2d64016a491ea3a0188198839c62e78e1dac20.png",
    GENERATED_BG_DIR / "ig_01bf6f6f285a2d64016a491f0e60c8819894db2dde6c284151.png",
    GENERATED_BG_DIR / "ig_0eefe2f64e94c6da016a491fb0a3008198a4da1f8ac9cf0714.png",
]


@dataclass(frozen=True)
class Option:
    key: str
    title: str
    subtitle: str
    bg_name: str
    output_name: str
    palette: dict[str, tuple[int, int, int, int]]
    tags: tuple[str, ...]
    fit: str
    summary: str
    best_for: str
    risk: str


OPTIONS = [
    Option(
        key="A",
        title="田园据点版",
        subtitle="轻松、亲切、低压力",
        bg_name="background_a_farm_meadow.png",
        output_name="formal_page_option_a_farm_meadow.png",
        palette={
            "line": (70, 52, 38, 255),
            "panel": (255, 239, 196, 238),
            "panel_dark": (126, 96, 62, 245),
            "accent": (255, 181, 48, 255),
            "accent2": (77, 178, 118, 255),
            "blue": (69, 144, 218, 255),
            "purple": (111, 91, 178, 255),
            "nav": (98, 75, 52, 238),
            "text": (72, 48, 35, 255),
        },
        tags=("farm", "soft", "cozy"),
        fit="适合把游戏包装成动物小队经营据点，降低策略玩法的压迫感。",
        summary="主场景像可经营的小农场据点，动物在基地周围散开，UI 用木牌和奶油色面板。",
        best_for="第一印象最休闲，适合新手、女性向和低龄泛用户。",
        risk="战斗感最弱，需要靠按钮和关卡入口补一点目标感。",
    ),
    Option(
        key="B",
        title="街机营地版",
        subtitle="清晰、爽快、商业化",
        bg_name="background_b_arcade_jungle.png",
        output_name="formal_page_option_b_arcade_jungle.png",
        palette={
            "line": (18, 23, 40, 255),
            "panel": (38, 55, 118, 236),
            "panel_dark": (23, 31, 70, 245),
            "accent": (255, 196, 42, 255),
            "accent2": (49, 210, 118, 255),
            "blue": (40, 144, 244, 255),
            "purple": (119, 68, 224, 255),
            "nav": (28, 37, 87, 245),
            "text": (255, 255, 255, 255),
        },
        tags=("arcade", "blue", "chunky"),
        fit="适合强化卡牌、养成、商店和后续活动入口，最接近正式商业 UI。",
        summary="用蓝金基地和圆形训练场做第一视觉，粗描边资源条、卡牌栏和底部导航更强。",
        best_for="最适合直接落地到 Godot 当前结构，信息密度和按钮层级都稳。",
        risk="需要控制蓝紫占比，避免和同类产品过像。",
    ),
    Option(
        key="C",
        title="峡谷庆典版",
        subtitle="热闹、明亮、有活动感",
        bg_name="background_c_festival_canyon.png",
        output_name="formal_page_option_c_festival_canyon.png",
        palette={
            "line": (67, 33, 33, 255),
            "panel": (255, 228, 165, 240),
            "panel_dark": (117, 54, 76, 245),
            "accent": (255, 211, 42, 255),
            "accent2": (47, 194, 224, 255),
            "blue": (54, 168, 229, 255),
            "purple": (151, 77, 204, 255),
            "nav": (116, 47, 81, 242),
            "text": (74, 38, 42, 255),
        },
        tags=("festival", "warm", "event"),
        fit="适合把大厅做成赛季活动入口，主页面更有热闹感和奖励驱动力。",
        summary="峡谷舞台承载动物小队，顶部放活动/关卡条，中部给大按钮和模式入口。",
        best_for="活动运营感最强，适合之后接赛季、挑战和限时奖励。",
        risk="暖色多，战斗棋盘页要降一点饱和，避免长期观看疲劳。",
    ),
    Option(
        key="D",
        title="星光露营版",
        subtitle="放松、治愈、夜间氛围",
        bg_name="background_d_twilight_camp.png",
        output_name="formal_page_option_d_twilight_camp.png",
        palette={
            "line": (16, 29, 50, 255),
            "panel": (45, 76, 105, 236),
            "panel_dark": (22, 42, 66, 245),
            "accent": (255, 197, 83, 255),
            "accent2": (87, 224, 180, 255),
            "blue": (55, 146, 218, 255),
            "purple": (137, 98, 224, 255),
            "nav": (22, 38, 64, 248),
            "text": (246, 252, 255, 255),
        },
        tags=("camp", "twilight", "cozy"),
        fit="适合偏治愈和留存向，能让动物卡牌和收集更有陪伴感。",
        summary="夜间露营场景加暖光 UI，资源和按钮做发光边，动物像在营地集合。",
        best_for="差异化最高，适合做晚间登录、休闲收集和轻度社交感。",
        risk="亮度需要谨慎，战斗页必须保证地块和价格足够清楚。",
    ),
]


ANIMAL_IDS = ["rabbit", "mouse", "frog", "chicken", "cat", "dog", "wolf", "bear"]
CARD_NAMES = {
    "rabbit": "兔子",
    "mouse": "老鼠",
    "frog": "青蛙",
    "chicken": "鸡",
    "cat": "猫",
    "dog": "狗",
    "wolf": "狼",
    "bear": "熊",
}
RARITY = {
    "rabbit": "common",
    "mouse": "common",
    "frog": "common",
    "chicken": "common",
    "cat": "common",
    "dog": "common",
    "wolf": "rare",
    "bear": "epic",
}


def color(hex_value: str, alpha: int = 255) -> tuple[int, int, int, int]:
    value = hex_value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    path = Path("C:/Windows/Fonts/NotoSansSC-VF.ttf")
    if not path.exists():
        path = Path("C:/Windows/Fonts/msyhbd.ttc" if bold else "C:/Windows/Fonts/msyh.ttc")
    return ImageFont.truetype(str(path), size=size)


def cover_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    image = image.convert("RGBA")
    scale = max(size[0] / image.width, size[1] / image.height)
    resized = image.resize((int(image.width * scale), int(image.height * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - size[0]) // 2
    top = (resized.height - size[1]) // 2
    return resized.crop((left, top, left + size[0], top + size[1]))


def fit_asset(image: Image.Image, max_size: tuple[int, int]) -> Image.Image:
    image = image.convert("RGBA")
    bbox = image.getbbox()
    if bbox:
        image = image.crop(bbox)
    image.thumbnail(max_size, Image.Resampling.LANCZOS)
    return image


def paste_center(base: Image.Image, asset: Image.Image, center: tuple[int, int]) -> None:
    x = int(center[0] - asset.width / 2)
    y = int(center[1] - asset.height / 2)
    base.alpha_composite(asset, (x, y))


def rect_shadow(
    canvas: Image.Image,
    rect: tuple[int, int, int, int],
    radius: int,
    shadow: tuple[int, int, int, int] = (0, 0, 0, 70),
    offset: tuple[int, int] = (0, 6),
) -> None:
    layer = Image.new("RGBA", canvas.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    shifted = (rect[0] + offset[0], rect[1] + offset[1], rect[2] + offset[0], rect[3] + offset[1])
    d.rounded_rectangle(shifted, radius=radius, fill=shadow)
    canvas.alpha_composite(layer.filter(ImageFilter.GaussianBlur(1.0)))


def round_rect(
    draw: ImageDraw.ImageDraw,
    rect: tuple[int, int, int, int],
    fill: tuple[int, int, int, int],
    outline: tuple[int, int, int, int],
    width: int = 4,
    radius: int = 18,
) -> None:
    draw.rounded_rectangle(rect, radius=radius, fill=fill, outline=outline, width=width)


def centered_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    rect: tuple[int, int, int, int],
    fill: tuple[int, int, int, int],
    size: int,
    bold: bool = False,
    stroke: tuple[int, tuple[int, int, int, int]] | None = None,
) -> None:
    fnt = font(size, bold)
    bbox = draw.textbbox((0, 0), text, font=fnt)
    x = rect[0] + (rect[2] - rect[0] - (bbox[2] - bbox[0])) / 2
    y = rect[1] + (rect[3] - rect[1] - (bbox[3] - bbox[1])) / 2 - 2
    if stroke:
        draw.text((x, y), text, font=fnt, fill=fill, stroke_width=stroke[0], stroke_fill=stroke[1])
    else:
        draw.text((x, y), text, font=fnt, fill=fill)


def left_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    xy: tuple[int, int],
    fill: tuple[int, int, int, int],
    size: int,
    bold: bool = False,
    stroke: tuple[int, tuple[int, int, int, int]] | None = None,
) -> None:
    fnt = font(size, bold)
    if stroke:
        draw.text(xy, text, font=fnt, fill=fill, stroke_width=stroke[0], stroke_fill=stroke[1])
    else:
        draw.text(xy, text, font=fnt, fill=fill)


def asset_path(kind: str, name: str) -> Path:
    if kind == "animal":
        return ROOT / "assets" / "card_art" / "animals" / f"{name}.png"
    return ROOT / "assets" / "art" / "buildings" / f"{name}.png"


def load_asset(kind: str, name: str, max_size: tuple[int, int]) -> Image.Image:
    return fit_asset(Image.open(asset_path(kind, name)), max_size)


def tint_overlay(base: Image.Image, fill: tuple[int, int, int, int]) -> None:
    layer = Image.new("RGBA", base.size, fill)
    base.alpha_composite(layer)


def draw_resource_bar(draw: ImageDraw.ImageDraw, option: Option, dark: bool = False) -> None:
    p = option.palette
    top = (26, 18, 694, 82)
    fill = p["panel_dark"] if dark else p["panel"]
    round_rect(draw, top, fill, p["line"], width=4, radius=18)
    left_text(draw, "战城大师", (48, 28), p["text"], 28, True, (2, p["line"]) if dark else None)
    pills = [
        (384, 29, 494, 71, "金币", "9750", p["accent"]),
        (506, 29, 616, 71, "券", "10", p["blue"]),
        (628, 29, 674, 71, "+", "", p["accent2"]),
    ]
    for x1, y1, x2, y2, label, value, c in pills:
        round_rect(draw, (x1, y1, x2, y2), (255, 255, 255, 230), p["line"], width=3, radius=15)
        draw.ellipse((x1 + 8, y1 + 9, x1 + 30, y1 + 31), fill=c, outline=p["line"], width=2)
        if value:
            left_text(draw, value, (x1 + 36, y1 + 8), p["line"], 20, True)
        else:
            centered_text(draw, label, (x1, y1, x2, y2), p["line"], 28, True)


def draw_bottom_nav(draw: ImageDraw.ImageDraw, option: Option) -> None:
    p = option.palette
    draw.rounded_rectangle((14, 1141, 706, 1273), radius=22, fill=(0, 0, 0, 80))
    round_rect(draw, (14, 1134, 706, 1266), p["nav"], p["line"], width=5, radius=22)
    items = ["商店", "编组", "战斗", "抽卡", "更多"]
    slot_w = 128
    start = 40
    for i, label in enumerate(items):
        x1 = start + i * 128
        active = label == "战斗"
        item_rect = (x1, 1150 if active else 1160, x1 + slot_w - 16, 1248)
        fill = p["accent"] if active else p["panel_dark"]
        round_rect(draw, item_rect, fill, p["line"], width=4, radius=18)
        icon_color = p["line"] if active else (255, 255, 255, 255)
        draw_nav_symbol(draw, item_rect, i, icon_color, p["line"] if not active else icon_color)
        centered_text(draw, label, (item_rect[0], item_rect[1] + 46, item_rect[2], item_rect[3] - 4), icon_color, 19, True)


def draw_nav_symbol(
    draw: ImageDraw.ImageDraw,
    rect: tuple[int, int, int, int],
    index: int,
    fill: tuple[int, int, int, int],
    line: tuple[int, int, int, int],
) -> None:
    cx = (rect[0] + rect[2]) // 2
    cy = rect[1] + 28
    if index == 0:
        draw.polygon([(cx, cy - 15), (cx + 16, cy), (cx, cy + 15), (cx - 16, cy)], fill=fill)
    elif index == 1:
        draw.rounded_rectangle((cx - 18, cy - 15, cx + 8, cy + 16), radius=4, fill=None, outline=fill, width=4)
        draw.rounded_rectangle((cx - 5, cy - 18, cx + 21, cy + 13), radius=4, fill=None, outline=fill, width=4)
    elif index == 2:
        draw.line((cx - 18, cy - 17, cx + 16, cy + 17), fill=fill, width=6)
        draw.line((cx + 18, cy - 17, cx - 16, cy + 17), fill=fill, width=6)
        draw.ellipse((cx - 6, cy - 6, cx + 6, cy + 6), fill=line)
    elif index == 3:
        points = []
        for i in range(10):
            angle = -1.5708 + i * 0.6283
            radius = 18 if i % 2 == 0 else 8
            points.append((cx + int(radius * math.cos(angle)), cy + int(radius * math.sin(angle))))
        draw.polygon(points, fill=fill)
    else:
        for j in range(3):
            y = cy - 12 + j * 12
            draw.rounded_rectangle((cx - 18, y, cx + 18, y + 4), radius=2, fill=fill)


def draw_cta(draw: ImageDraw.ImageDraw, option: Option, rect: tuple[int, int, int, int], label: str, secondary: bool = False) -> None:
    p = option.palette
    fill = p["blue"] if secondary else p["accent"]
    round_rect(draw, (rect[0], rect[1] + 7, rect[2], rect[3] + 7), p["line"], p["line"], width=0, radius=20)
    round_rect(draw, rect, fill, p["line"], width=5, radius=20)
    centered_text(draw, label, rect, (255, 255, 255, 255), 30, True, (2, p["line"]))


def draw_card(draw: ImageDraw.ImageDraw, base: Image.Image, option: Option, animal_id: str, rect: tuple[int, int, int, int], selected: bool = False) -> None:
    p = option.palette
    rarity_fill = {
        "common": (89, 203, 105, 245),
        "rare": (68, 158, 255, 245),
        "epic": (174, 86, 231, 245),
    }.get(RARITY.get(animal_id, "common"), p["accent"])
    shadow_rect = (rect[0], rect[1] + 5, rect[2], rect[3] + 5)
    round_rect(draw, shadow_rect, (0, 0, 0, 72), (0, 0, 0, 0), width=0, radius=14)
    round_rect(draw, rect, rarity_fill, p["line"], width=4, radius=14)
    if selected:
        draw.rounded_rectangle((rect[0] - 5, rect[1] - 5, rect[2] + 5, rect[3] + 5), radius=18, outline=p["accent"], width=5)
    asset = load_asset("animal", animal_id, (86, 86))
    paste_center(base, asset, ((rect[0] + rect[2]) // 2, rect[1] + 50))
    name_rect = (rect[0] + 8, rect[3] - 34, rect[2] - 8, rect[3] - 10)
    draw.rounded_rectangle(name_rect, radius=8, fill=(0, 0, 0, 86))
    centered_text(draw, CARD_NAMES.get(animal_id, animal_id), name_rect, (255, 255, 255, 255), 15, True)


def draw_animals_on_scene(base: Image.Image, positions: list[tuple[str, tuple[int, int], tuple[int, int]]]) -> None:
    shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    for _, center, size in positions:
        sd.ellipse((center[0] - size[0] // 4, center[1] + size[1] // 3, center[0] + size[0] // 4, center[1] + size[1] // 2), fill=(0, 0, 0, 50))
    base.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(2)))
    for animal_id, center, size in positions:
        asset = load_asset("animal", animal_id, size)
        paste_center(base, asset, center)


def draw_option_a(base: Image.Image, option: Option) -> Image.Image:
    draw = ImageDraw.Draw(base)
    p = option.palette
    tint_overlay(base, (255, 244, 205, 22))
    draw_resource_bar(draw, option)
    centered_text(draw, "动物据点", (74, 96, 646, 152), (255, 255, 255, 255), 44, True, (3, p["line"]))
    left_text(draw, "第 1 章  草地试炼", (92, 166), p["text"], 22, True)

    base_art = load_asset("building", "base", (218, 218))
    paste_center(base, base_art, (360, 360))
    draw_animals_on_scene(
        base,
        [
            ("rabbit", (240, 515), (105, 105)),
            ("mouse", (338, 555), (82, 82)),
            ("frog", (461, 520), (94, 94)),
            ("chicken", (224, 650), (88, 88)),
            ("cat", (358, 680), (100, 100)),
            ("dog", (486, 650), (110, 110)),
            ("wolf", (300, 775), (112, 112)),
            ("bear", (430, 785), (126, 126)),
        ],
    )
    round_rect(draw, (58, 826, 662, 946), p["panel"], p["line"], width=5, radius=24)
    left_text(draw, "今日小队", (88, 848), p["text"], 24, True)
    for i, animal_id in enumerate(ANIMAL_IDS[:5]):
        draw_card(draw, base, option, animal_id, (86 + i * 108, 884, 174 + i * 108, 980), i == 0)
    draw_cta(draw, option, (176, 1004, 544, 1078), "开始战斗")
    draw_bottom_nav(draw, option)
    return base


def draw_option_b(base: Image.Image, option: Option) -> Image.Image:
    draw = ImageDraw.Draw(base)
    p = option.palette
    tint_overlay(base, (21, 35, 82, 24))
    draw_resource_bar(draw, option, dark=True)
    centered_text(draw, "战城大师", (64, 92, 656, 150), (255, 255, 255, 255), 48, True, (3, p["line"]))

    round_rect(draw, (36, 158, 684, 258), p["panel"], p["line"], width=5, radius=20)
    left_text(draw, "荣耀之路", (72, 178), (255, 255, 255, 255), 24, True)
    round_rect(draw, (246, 190, 628, 232), (34, 42, 86, 230), p["line"], width=3, radius=13)
    draw.rounded_rectangle((254, 198, 485, 224), radius=9, fill=p["accent"])
    centered_text(draw, "76 / 100", (246, 188, 628, 236), (255, 255, 255, 255), 20, True, (2, p["line"]))

    base_art = load_asset("building", "base", (190, 190))
    paste_center(base, base_art, (360, 470))
    draw_animals_on_scene(
        base,
        [
            ("rabbit", (221, 616), (94, 94)),
            ("mouse", (293, 642), (76, 76)),
            ("frog", (378, 628), (84, 84)),
            ("chicken", (474, 606), (76, 76)),
            ("cat", (265, 735), (92, 92)),
            ("dog", (372, 760), (98, 98)),
            ("wolf", (480, 724), (104, 104)),
            ("bear", (360, 800), (104, 104)),
        ],
    )
    round_rect(draw, (52, 820, 668, 930), p["panel_dark"], p["line"], width=5, radius=22)
    left_text(draw, "出战编组", (80, 840), (255, 255, 255, 255), 24, True)
    for i, animal_id in enumerate(ANIMAL_IDS[:4]):
        draw_card(draw, base, option, animal_id, (106 + i * 126, 870, 204 + i * 126, 982), i == 1)
    draw_cta(draw, option, (102, 1008, 422, 1080), "开始战斗")
    draw_cta(draw, option, (446, 1008, 618, 1080), "编组", True)
    draw_bottom_nav(draw, option)
    return base


def draw_option_c(base: Image.Image, option: Option) -> Image.Image:
    draw = ImageDraw.Draw(base)
    p = option.palette
    tint_overlay(base, (255, 232, 160, 18))
    draw_resource_bar(draw, option)
    centered_text(draw, "季节锦标赛", (48, 92, 672, 148), (255, 255, 255, 255), 42, True, (3, p["line"]))

    round_rect(draw, (62, 164, 658, 268), p["panel_dark"], p["line"], width=5, radius=18)
    left_text(draw, "草地联赛进行中", (90, 184), (255, 255, 255, 255), 25, True)
    round_rect(draw, (88, 226, 518, 254), (255, 255, 255, 230), p["line"], width=3, radius=10)
    draw.rounded_rectangle((94, 232, 374, 248), radius=8, fill=p["accent"])
    centered_text(draw, "650", (526, 212, 626, 266), (255, 255, 255, 255), 28, True, (2, p["line"]))

    draw_animals_on_scene(
        base,
        [
            ("rabbit", (212, 532), (100, 100)),
            ("chicken", (298, 496), (82, 82)),
            ("frog", (394, 518), (96, 96)),
            ("cat", (498, 548), (100, 100)),
            ("mouse", (254, 672), (78, 78)),
            ("dog", (372, 694), (108, 108)),
            ("wolf", (492, 682), (106, 106)),
            ("bear", (352, 812), (130, 130)),
        ],
    )
    for i, label in enumerate(["1", "2", "3"]):
        r = (232 + i * 92, 830, 300 + i * 92, 892)
        round_rect(draw, r, p["accent"] if i == 0 else (240, 240, 255, 240), p["line"], width=4, radius=8)
        centered_text(draw, label, r, p["line"], 30, True)
    draw_cta(draw, option, (68, 934, 340, 1010), "竞技场")
    draw_cta(draw, option, (380, 934, 652, 1010), "合作模式", True)
    draw_bottom_nav(draw, option)
    return base


def draw_option_d(base: Image.Image, option: Option) -> Image.Image:
    draw = ImageDraw.Draw(base)
    p = option.palette
    tint_overlay(base, (5, 18, 35, 34))
    draw_resource_bar(draw, option, dark=True)
    centered_text(draw, "星光营地", (64, 96, 656, 152), (250, 255, 255, 255), 44, True, (3, p["line"]))

    round_rect(draw, (74, 166, 646, 270), p["panel"], p["line"], width=5, radius=22)
    left_text(draw, "今晚巡逻", (106, 186), (255, 255, 255, 255), 25, True)
    for i in range(6):
        x = 260 + i * 48
        draw.ellipse((x, 214, x + 28, 242), fill=p["accent2"], outline=p["line"], width=3)
    centered_text(draw, "1 / 6", (540, 198, 620, 250), (255, 255, 255, 255), 24, True, (2, p["line"]))

    tower = load_asset("building", "tower", (112, 148))
    mine = load_asset("building", "mine", (116, 116))
    paste_center(base, tower, (220, 444))
    paste_center(base, mine, (500, 450))
    draw_animals_on_scene(
        base,
        [
            ("rabbit", (215, 604), (96, 96)),
            ("mouse", (308, 630), (78, 78)),
            ("frog", (414, 606), (94, 94)),
            ("chicken", (512, 638), (82, 82)),
            ("cat", (258, 762), (98, 98)),
            ("dog", (372, 778), (106, 106)),
            ("wolf", (488, 750), (110, 110)),
            ("bear", (365, 812), (112, 112)),
        ],
    )
    round_rect(draw, (54, 866, 666, 964), p["panel_dark"], p["line"], width=5, radius=22)
    left_text(draw, "篝火小队", (88, 888), (255, 255, 255, 255), 25, True)
    for i, animal_id in enumerate(["rabbit", "frog", "dog", "wolf"]):
        draw_card(draw, base, option, animal_id, (154 + i * 104, 924, 238 + i * 104, 1020), i == 3)
    draw_cta(draw, option, (172, 1038, 548, 1108), "继续冒险")
    draw_bottom_nav(draw, option)
    return base


DRAWERS = {
    "A": draw_option_a,
    "B": draw_option_b,
    "C": draw_option_c,
    "D": draw_option_d,
}


def copy_backgrounds() -> dict[str, Path]:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    copied: dict[str, Path] = {}
    for option, src in zip(OPTIONS, BG_SOURCES, strict=True):
        if not src.exists():
            raise FileNotFoundError(src)
        dest = OUT_DIR / option.bg_name
        shutil.copy2(src, dest)
        copied[option.key] = dest
    return copied


def build_mockups() -> dict[str, Path]:
    backgrounds = copy_backgrounds()
    outputs: dict[str, Path] = {}
    for option in OPTIONS:
        bg = cover_resize(Image.open(backgrounds[option.key]), (W, H))
        mockup = DRAWERS[option.key](bg, option)
        path = OUT_DIR / option.output_name
        mockup.save(path)
        outputs[option.key] = path
    return outputs


def write_markdown(outputs: dict[str, Path]) -> None:
    DOC_PATH.parent.mkdir(parents=True, exist_ok=True)
    today = date.today().isoformat()
    lines = [
        "# 正式页面视觉方向选择稿",
        "",
        f"生成日期：{today}",
        "",
        "## 目标",
        "",
        "- 当前页面仍是 demo 版，本稿用于在不改变当前动物资产、不改变现有 UE/交互主结构的前提下选择正式页面方向。",
        "- 页面覆盖大厅第一屏、场景包装、资源条、底部导航、出战动物展示和战斗入口。",
        "- 动物使用项目已有 PNG 资产；AI 仅用于无角色、无文字、无 UI 的场景底图，避免改变当前动物。",
        "",
        "## 共通约束",
        "",
        "- 竖屏 720x1280。",
        "- 保留底部五入口：商店、编组、战斗、抽卡、更多。",
        "- 保留核心主按钮：开始战斗/继续冒险。",
        "- 保留当前动物卡牌作为编组展示，不替换动物外形。",
        "- 氛围为轻松休闲，避免硬核战争、恐怖、写实暴力。",
        "",
        "## 方案总览",
        "",
        "| 方案 | 名称 | 方向 | 适合 | 风险 | 预览 |",
        "| --- | --- | --- | --- | --- | --- |",
    ]
    for option in OPTIONS:
        rel = outputs[option.key].relative_to(ROOT).as_posix()
        lines.append(
            f"| {option.key} | {option.title} | {option.summary} | {option.best_for} | {option.risk} | `{rel}` |"
        )
    lines.extend(["", "## 选择建议", ""])
    lines.extend(
        [
            "- 如果想最快从 demo 过渡到商业化正式页，优先选 B 街机营地版。",
            "- 如果希望游戏更休闲、更亲切，优先选 A 田园据点版。",
            "- 如果下一步要突出活动/赛季/奖励，优先选 C 峡谷庆典版。",
            "- 如果希望差异化和治愈陪伴感更强，优先选 D 星光露营版。",
            "",
            "## 后续落地范围",
            "",
            "选定方向后，建议下一步只做视觉与 UI 包装落地，不改玩法规则：",
            "",
            "1. 把选中方向拆成大厅背景、顶部资源条、模式卡、出战编组条、底部导航、主 CTA。",
            "2. 在 `scripts/app/main.gd` 中先按现有绘制模式替换大厅 UI 和背景包装。",
            "3. 再同步处理战斗页：棋盘外框、资源条、地块价格牌、选择面板、暂停/结算弹窗。",
            "4. 最后抽出可复用 UI 函数或独立 UI 脚本，避免 `main.gd` 继续膨胀。",
        ]
    )
    DOC_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def register_pdf_font() -> str:
    candidates = [
        Path("C:/Windows/Fonts/NotoSansSC-VF.ttf"),
        Path("C:/Windows/Fonts/msyh.ttc"),
        Path("C:/Windows/Fonts/simhei.ttf"),
    ]
    for path in candidates:
        if path.exists():
            name = "FormalPageSans"
            if name not in pdfmetrics.getRegisteredFontNames():
                pdfmetrics.registerFont(TTFont(name, str(path)))
            return name
    return "Helvetica"


def write_pdf(outputs: dict[str, Path]) -> None:
    PDF_PATH.parent.mkdir(parents=True, exist_ok=True)
    font_name = register_pdf_font()
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle("TitleCN", parent=styles["Title"], fontName=font_name, fontSize=22, leading=28)
    h_style = ParagraphStyle("HeadingCN", parent=styles["Heading2"], fontName=font_name, fontSize=14, leading=18)
    body_style = ParagraphStyle("BodyCN", parent=styles["BodyText"], fontName=font_name, fontSize=9.5, leading=14)
    cell_style = ParagraphStyle("CellCN", parent=styles["BodyText"], fontName=font_name, fontSize=8.2, leading=11)

    doc = SimpleDocTemplate(
        str(PDF_PATH),
        pagesize=landscape(A4),
        rightMargin=12 * mm,
        leftMargin=12 * mm,
        topMargin=10 * mm,
        bottomMargin=10 * mm,
        title="Formal page visual options",
        author="Codex",
    )
    story = [
        Paragraph("正式页面视觉方向选择稿", title_style),
        Paragraph(f"生成日期：{date.today().isoformat()}", body_style),
        Spacer(1, 4 * mm),
        Paragraph("目标", h_style),
        Paragraph("在不改变当前动物资产、不改变现有 UE/交互主结构的前提下，提供 4 个正式页面方向供选择。动物使用项目已有 PNG；AI 仅用于无角色、无文字、无 UI 的场景底图。", body_style),
        Spacer(1, 4 * mm),
    ]
    rows = [["方案", "名称", "适合", "主要风险"]]
    for option in OPTIONS:
        rows.append(
            [
                option.key,
                option.title,
                Paragraph(option.best_for, cell_style),
                Paragraph(option.risk, cell_style),
            ]
        )
    table = Table(rows, colWidths=[18 * mm, 36 * mm, 108 * mm, 92 * mm], repeatRows=1)
    table.setStyle(
        TableStyle(
            [
                ("FONTNAME", (0, 0), (-1, -1), font_name),
                ("FONTSIZE", (0, 0), (-1, -1), 8.5),
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1f5f8b")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#b9c4d0")),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f7fafc")]),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    story.append(table)

    for option in OPTIONS:
        story.append(PageBreak())
        story.append(Paragraph(f"{option.key}. {option.title}", title_style))
        story.append(Paragraph(option.summary, body_style))
        story.append(Spacer(1, 3 * mm))
        image_path = outputs[option.key]
        preview = PdfImage(str(image_path), width=76 * mm, height=135.1 * mm)
        notes = [
            Paragraph(f"定位：{option.subtitle}", h_style),
            Spacer(1, 4 * mm),
            Paragraph(f"适合：{option.best_for}", body_style),
            Spacer(1, 3 * mm),
            Paragraph(f"风险：{option.risk}", body_style),
            Spacer(1, 3 * mm),
            Paragraph(f"落地：{option.fit}", body_style),
        ]
        option_table = Table([[preview, notes]], colWidths=[84 * mm, 158 * mm])
        option_table.setStyle(
            TableStyle(
                [
                    ("VALIGN", (0, 0), (-1, -1), "TOP"),
                    ("LEFTPADDING", (0, 0), (-1, -1), 0),
                    ("RIGHTPADDING", (0, 0), (-1, -1), 8),
                    ("TOPPADDING", (0, 0), (-1, -1), 0),
                    ("BOTTOMPADDING", (0, 0), (-1, -1), 0),
                ]
            )
        )
        story.append(option_table)

    doc.build(story)


def main() -> int:
    outputs = build_mockups()
    write_markdown(outputs)
    write_pdf(outputs)
    print(f"Wrote {DOC_PATH.relative_to(ROOT)}")
    print(f"Wrote {PDF_PATH.relative_to(ROOT)}")
    for path in outputs.values():
        print(f"Wrote {path.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
