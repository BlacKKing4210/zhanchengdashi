from __future__ import annotations

import math
from dataclasses import dataclass
from datetime import date
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "visual_concepts"
DOC = ROOT / "docs" / "CURRENT_GAME_2D_UE_LOCKED_ART_OPTIONS.md"
W, H = 720, 1280


@dataclass(frozen=True)
class SkinOption:
  key: str
  slug: str
  title: str
  summary: str
  best_for: str
  risk: str
  palette: dict[str, tuple[int, int, int, int]]


OPTIONS = [
  SkinOption(
    key="A",
    slug="arcade_jungle",
    title="街机丛林",
    summary="当前 UE 上最稳的商业化升级：厚描边、蓝绿棋盘、黄色 CTA，信息层级最清楚。",
    best_for="优先落地到 Godot 的第一版正式皮肤。",
    risk="风格相对安全，需要靠图标细节和背景层次拉开记忆点。",
    palette={
      "bg_top": (122, 215, 119, 255),
      "bg_bottom": (55, 143, 88, 255),
      "sky": (146, 225, 130, 255),
      "grass": (43, 120, 61, 255),
      "line": (9, 18, 32, 255),
      "panel": (28, 58, 111, 238),
      "panel_light": (224, 242, 255, 246),
      "panel_mid": (53, 118, 173, 245),
      "scene": (95, 176, 94, 255),
      "scene_inner": (109, 196, 92, 255),
      "rank": (42, 34, 104, 244),
      "nav": (41, 35, 108, 248),
      "nav_active": (45, 132, 228, 255),
      "cta": (255, 176, 35, 255),
      "cta_dark": (189, 105, 24, 255),
      "gold": (255, 205, 59, 255),
      "blue": (55, 166, 255, 255),
      "green": (104, 218, 86, 255),
      "red": (232, 73, 67, 255),
      "purple": (156, 95, 255, 255),
      "enemy_tile": (229, 101, 91, 210),
      "player_tile": (93, 190, 82, 225),
      "neutral_tile": (235, 212, 146, 188),
      "territory_enemy": (240, 96, 86, 86),
      "territory_player": (95, 212, 89, 88),
      "board_outer": (250, 198, 83, 255),
      "board_inner": (102, 192, 80, 255),
      "board_line": (45, 96, 52, 255),
      "text": (255, 255, 255, 255),
      "dark_text": (11, 18, 28, 255),
      "muted": (171, 183, 191, 255),
    },
  ),
  SkinOption(
    key="B",
    slug="premium_leaf",
    title="高级叶脉",
    summary="更简单、更 2D：低噪声纸感、叶脉暗纹、柔和绿色主场景，整体更高级但不复杂。",
    best_for="想要简单、高品质、原创 2D 感更强的方向。",
    risk="战斗冲击力弱一点，需要保留清晰的黄 CTA 和选中描边。",
    palette={
      "bg_top": (142, 208, 132, 255),
      "bg_bottom": (67, 132, 78, 255),
      "sky": (180, 225, 150, 255),
      "grass": (53, 112, 66, 255),
      "line": (41, 49, 32, 255),
      "panel": (232, 214, 163, 242),
      "panel_light": (255, 239, 188, 246),
      "panel_mid": (138, 162, 87, 245),
      "scene": (116, 172, 91, 255),
      "scene_inner": (131, 188, 93, 255),
      "rank": (87, 78, 55, 246),
      "nav": (86, 81, 58, 248),
      "nav_active": (50, 142, 170, 255),
      "cta": (242, 176, 47, 255),
      "cta_dark": (158, 93, 37, 255),
      "gold": (232, 180, 56, 255),
      "blue": (51, 139, 198, 255),
      "green": (96, 170, 77, 255),
      "red": (184, 78, 56, 255),
      "purple": (148, 93, 181, 255),
      "enemy_tile": (177, 110, 70, 212),
      "player_tile": (112, 166, 84, 225),
      "neutral_tile": (226, 207, 153, 192),
      "territory_enemy": (180, 88, 60, 72),
      "territory_player": (104, 175, 83, 84),
      "board_outer": (185, 143, 82, 255),
      "board_inner": (126, 174, 89, 255),
      "board_line": (74, 103, 52, 255),
      "text": (255, 250, 225, 255),
      "dark_text": (50, 45, 31, 255),
      "muted": (117, 115, 92, 255),
    },
  ),
  SkinOption(
    key="C",
    slug="crystal_night",
    title="晶石夜战",
    summary="品质感最强：深色面板、晶石蓝高光、清晰发光边，适合高阶主题或赛季皮肤。",
    best_for="需要明显高级感、夜色主题或后续商业皮肤方向。",
    risk="深色会压小屏可读性，必须严格保持资源、按钮和选中态亮度。",
    palette={
      "bg_top": (50, 82, 129, 255),
      "bg_bottom": (23, 38, 72, 255),
      "sky": (52, 91, 141, 255),
      "grass": (42, 92, 102, 255),
      "line": (5, 11, 22, 255),
      "panel": (20, 36, 69, 242),
      "panel_light": (206, 225, 247, 246),
      "panel_mid": (35, 86, 138, 245),
      "scene": (43, 92, 108, 255),
      "scene_inner": (58, 121, 127, 255),
      "rank": (19, 25, 70, 246),
      "nav": (19, 28, 62, 248),
      "nav_active": (30, 117, 185, 255),
      "cta": (248, 170, 42, 255),
      "cta_dark": (168, 86, 26, 255),
      "gold": (255, 202, 72, 255),
      "blue": (59, 199, 255, 255),
      "green": (91, 225, 151, 255),
      "red": (244, 83, 82, 255),
      "purple": (177, 109, 255, 255),
      "enemy_tile": (114, 84, 103, 214),
      "player_tile": (55, 132, 140, 225),
      "neutral_tile": (65, 112, 126, 196),
      "territory_enemy": (232, 80, 82, 70),
      "territory_player": (77, 220, 195, 74),
      "board_outer": (47, 80, 110, 255),
      "board_inner": (46, 104, 111, 255),
      "board_line": (22, 60, 75, 255),
      "text": (244, 252, 255, 255),
      "dark_text": (8, 17, 29, 255),
      "muted": (155, 180, 205, 255),
    },
  ),
  SkinOption(
    key="D",
    slug="festival_board",
    title="庆典棋盘",
    summary="更明亮、更有活动感：暖色边框、清爽绿色棋盘、按钮更有吸引力。",
    best_for="希望首页更热闹、后续方便接活动与奖励包装。",
    risk="暖色多时容易抢棋盘信息，需要控制装饰密度。",
    palette={
      "bg_top": (156, 218, 118, 255),
      "bg_bottom": (75, 154, 84, 255),
      "sky": (207, 230, 122, 255),
      "grass": (50, 135, 72, 255),
      "line": (52, 31, 26, 255),
      "panel": (124, 61, 88, 240),
      "panel_light": (255, 236, 177, 246),
      "panel_mid": (220, 116, 88, 245),
      "scene": (111, 181, 86, 255),
      "scene_inner": (133, 203, 92, 255),
      "rank": (109, 51, 93, 246),
      "nav": (105, 53, 91, 248),
      "nav_active": (47, 139, 202, 255),
      "cta": (255, 192, 44, 255),
      "cta_dark": (178, 91, 33, 255),
      "gold": (255, 212, 64, 255),
      "blue": (56, 166, 231, 255),
      "green": (82, 200, 91, 255),
      "red": (219, 68, 72, 255),
      "purple": (169, 84, 216, 255),
      "enemy_tile": (211, 91, 76, 214),
      "player_tile": (100, 181, 78, 225),
      "neutral_tile": (240, 211, 138, 192),
      "territory_enemy": (220, 81, 74, 78),
      "territory_player": (98, 190, 80, 88),
      "board_outer": (239, 155, 74, 255),
      "board_inner": (123, 192, 82, 255),
      "board_line": (96, 82, 44, 255),
      "text": (255, 250, 240, 255),
      "dark_text": (55, 32, 25, 255),
      "muted": (159, 133, 109, 255),
    },
  ),
]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
  candidates = [
    Path("C:/Windows/Fonts/NotoSansSC-VF.ttf"),
    Path("C:/Windows/Fonts/msyhbd.ttc" if bold else "C:/Windows/Fonts/msyh.ttc"),
    Path("C:/Windows/Fonts/simhei.ttf"),
  ]
  for path in candidates:
    if path.exists():
      return ImageFont.truetype(str(path), size=size)
  return ImageFont.load_default()


def c(option: SkinOption, name: str) -> tuple[int, int, int, int]:
  return option.palette[name]


def with_alpha(color: tuple[int, int, int, int], alpha: int) -> tuple[int, int, int, int]:
  return color[0], color[1], color[2], alpha


def mix(
  a: tuple[int, int, int, int],
  b: tuple[int, int, int, int],
  t: float,
  alpha: int | None = None,
) -> tuple[int, int, int, int]:
  return (
    round(a[0] + (b[0] - a[0]) * t),
    round(a[1] + (b[1] - a[1]) * t),
    round(a[2] + (b[2] - a[2]) * t),
    a[3] if alpha is None else alpha,
  )


def text_size(draw: ImageDraw.ImageDraw, value: str, fnt: ImageFont.FreeTypeFont) -> tuple[int, int]:
  bbox = draw.textbbox((0, 0), value, font=fnt)
  return bbox[2] - bbox[0], bbox[3] - bbox[1]


def fit_text(draw: ImageDraw.ImageDraw, value: str, max_width: int, size: int, bold: bool = False) -> str:
  fnt = font(size, bold)
  if text_size(draw, value, fnt)[0] <= max_width:
    return value
  clipped = value
  while clipped:
    candidate = clipped + "..."
    if text_size(draw, candidate, fnt)[0] <= max_width:
      return candidate
    clipped = clipped[:-1]
  return "..."


def center_text(
  draw: ImageDraw.ImageDraw,
  value: str,
  rect: tuple[int, int, int, int],
  fill: tuple[int, int, int, int],
  size: int,
  bold: bool = False,
  stroke: tuple[int, tuple[int, int, int, int]] | None = None,
) -> None:
  value = fit_text(draw, value, rect[2] - rect[0] - 8, size, bold)
  fnt = font(size, bold)
  tw, th = text_size(draw, value, fnt)
  x = rect[0] + (rect[2] - rect[0] - tw) / 2
  y = rect[1] + (rect[3] - rect[1] - th) / 2 - 2
  if stroke:
    draw.text((x, y), value, font=fnt, fill=fill, stroke_width=stroke[0], stroke_fill=stroke[1])
  else:
    draw.text((x, y), value, font=fnt, fill=fill)


def left_text(
  draw: ImageDraw.ImageDraw,
  value: str,
  rect: tuple[int, int, int, int],
  fill: tuple[int, int, int, int],
  size: int,
  bold: bool = False,
) -> None:
  value = fit_text(draw, value, rect[2] - rect[0], size, bold)
  fnt = font(size, bold)
  _, th = text_size(draw, value, fnt)
  y = rect[1] + (rect[3] - rect[1] - th) / 2 - 2
  draw.text((rect[0], y), value, font=fnt, fill=fill)


def right_text(
  draw: ImageDraw.ImageDraw,
  value: str,
  rect: tuple[int, int, int, int],
  fill: tuple[int, int, int, int],
  size: int,
  bold: bool = False,
) -> None:
  value = fit_text(draw, value, rect[2] - rect[0], size, bold)
  fnt = font(size, bold)
  tw, th = text_size(draw, value, fnt)
  y = rect[1] + (rect[3] - rect[1] - th) / 2 - 2
  draw.text((rect[2] - tw, y), value, font=fnt, fill=fill)


def rounded(
  image: Image.Image,
  rect: tuple[int, int, int, int],
  fill: tuple[int, int, int, int],
  outline: tuple[int, int, int, int],
  width: int = 4,
  radius: int = 14,
  shadow: bool = True,
  gloss: bool = True,
) -> None:
  layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
  draw = ImageDraw.Draw(layer)
  if shadow:
    sx1, sy1, sx2, sy2 = rect[0], rect[1] + 6, rect[2], rect[3] + 6
    draw.rounded_rectangle((sx1, sy1, sx2, sy2), radius=radius, fill=(0, 0, 0, 76))
    image.alpha_composite(layer.filter(ImageFilter.GaussianBlur(1.1)))
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
  draw.rounded_rectangle(rect, radius=radius, fill=fill, outline=outline, width=width)
  if gloss:
    x1, y1, x2, y2 = rect
    draw.rounded_rectangle((x1 + 6, y1 + 5, x2 - 6, min(y1 + 22, y2 - 5)), radius=max(5, radius - 7), fill=(255, 255, 255, 34))
  image.alpha_composite(layer)


def draw_gradient(size: tuple[int, int], top: tuple[int, int, int, int], bottom: tuple[int, int, int, int]) -> Image.Image:
  image = Image.new("RGBA", size, top)
  draw = ImageDraw.Draw(image)
  for y in range(size[1]):
    t = y / max(1, size[1] - 1)
    draw.line((0, y, size[0], y), fill=mix(top, bottom, t))
  return image


def asset(path: Path, max_size: tuple[int, int]) -> Image.Image:
  image = Image.open(path).convert("RGBA")
  bbox = image.getbbox()
  if bbox:
    image = image.crop(bbox)
  image.thumbnail(max_size, Image.Resampling.LANCZOS)
  return image


def paste_center(base: Image.Image, image: Image.Image, center: tuple[int, int]) -> None:
  base.alpha_composite(image, (round(center[0] - image.width / 2), round(center[1] - image.height / 2)))


def add_paper_texture(image: Image.Image, option: SkinOption, amount: int = 1800) -> None:
  layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
  pix = layer.load()
  seed = sum(ord(ch) for ch in option.slug)
  value = seed
  for _ in range(amount):
    value = (1103515245 * value + 12345) & 0x7FFFFFFF
    x = value % image.width
    value = (1103515245 * value + 12345) & 0x7FFFFFFF
    y = value % image.height
    alpha = 12 + value % 22
    pix[x, y] = (255, 255, 255, alpha)
  image.alpha_composite(layer.filter(ImageFilter.GaussianBlur(0.35)))


def draw_leaf_pattern(image: Image.Image, option: SkinOption) -> None:
  draw = ImageDraw.Draw(image)
  line = with_alpha(c(option, "grass"), 38)
  for i in range(12):
    x = 40 + i * 64
    draw.arc((x - 52, 82, x + 52, 232), 210, 330, fill=line, width=3)
    draw.arc((x - 40, 96, x + 40, 216), 30, 150, fill=line, width=2)


def draw_background(option: SkinOption) -> Image.Image:
  image = draw_gradient((W, H), c(option, "bg_top"), c(option, "bg_bottom"))
  draw = ImageDraw.Draw(image)
  draw.rectangle((0, 0, W, 220), fill=c(option, "sky"))
  for i in range(17):
    x = -60 + i * 58
    draw.ellipse((x, 118, x + 190, 255), fill=with_alpha(c(option, "grass"), 64))
  draw_leaf_pattern(image, option)
  add_paper_texture(image, option)
  return image


def draw_coin(draw: ImageDraw.ImageDraw, center: tuple[int, int], option: SkinOption, color_name: str = "gold") -> None:
  x, y = center
  draw.ellipse((x - 13, y - 13, x + 13, y + 13), fill=c(option, color_name), outline=c(option, "line"), width=3)
  draw.ellipse((x - 6, y - 6, x + 6, y + 6), fill=(255, 245, 151, 230))


def draw_ticket(draw: ImageDraw.ImageDraw, center: tuple[int, int], option: SkinOption) -> None:
  x, y = center
  draw.rounded_rectangle((x - 16, y - 10, x + 16, y + 10), radius=5, fill=c(option, "blue"), outline=c(option, "line"), width=3)
  draw.line((x - 6, y - 8, x - 2, y + 8), fill=(255, 255, 255, 105), width=2)
  draw.line((x + 4, y - 8, x + 8, y + 8), fill=(255, 255, 255, 105), width=2)


def draw_paw(draw: ImageDraw.ImageDraw, center: tuple[int, int], option: SkinOption, fill: tuple[int, int, int, int]) -> None:
  x, y = center
  draw.ellipse((x - 9, y - 3, x + 9, y + 13), fill=fill, outline=c(option, "line"), width=2)
  for dx, dy in [(-12, -10), (-4, -15), (5, -15), (13, -9)]:
    draw.ellipse((x + dx - 4, y + dy - 4, x + dx + 4, y + dy + 4), fill=fill, outline=c(option, "line"), width=1)


def draw_swords(draw: ImageDraw.ImageDraw, center: tuple[int, int], option: SkinOption, fill: tuple[int, int, int, int]) -> None:
  x, y = center
  draw.line((x - 20, y - 19, x + 20, y + 21), fill=c(option, "line"), width=8)
  draw.line((x - 20, y - 19, x + 20, y + 21), fill=fill, width=4)
  draw.line((x + 20, y - 19, x - 20, y + 21), fill=c(option, "line"), width=8)
  draw.line((x + 20, y - 19, x - 20, y + 21), fill=fill, width=4)


def draw_cards_icon(draw: ImageDraw.ImageDraw, center: tuple[int, int], option: SkinOption, fill: tuple[int, int, int, int]) -> None:
  x, y = center
  for i in range(2):
    draw.rounded_rectangle((x - 18 + i * 10, y - 18 + i * 5, x + 8 + i * 10, y + 16 + i * 5), radius=5, fill=fill, outline=c(option, "line"), width=3)


def draw_shop_icon(draw: ImageDraw.ImageDraw, center: tuple[int, int], option: SkinOption, fill: tuple[int, int, int, int]) -> None:
  x, y = center
  draw.rounded_rectangle((x - 24, y - 8, x + 24, y + 20), radius=5, fill=fill, outline=c(option, "line"), width=3)
  draw.rectangle((x - 29, y - 24, x + 29, y - 7), fill=c(option, "red"), outline=c(option, "line"), width=3)
  draw.line((x - 16, y - 24, x - 19, y - 7), fill=(255, 255, 255, 90), width=2)


def draw_more_icon(draw: ImageDraw.ImageDraw, center: tuple[int, int], option: SkinOption, fill: tuple[int, int, int, int]) -> None:
  x, y = center
  for dx in (-15, 0, 15):
    draw.ellipse((x + dx - 5, y - 5, x + dx + 5, y + 5), fill=fill, outline=c(option, "line"), width=2)


def draw_lock(draw: ImageDraw.ImageDraw, center: tuple[int, int], option: SkinOption) -> None:
  x, y = center
  draw.rounded_rectangle((x - 11, y - 2, x + 11, y + 15), radius=4, fill=c(option, "line"), outline=(235, 243, 255, 255), width=2)
  draw.arc((x - 9, y - 15, x + 9, y + 5), 180, 360, fill=(235, 243, 255, 255), width=3)


def draw_resource_bar(image: Image.Image, option: SkinOption) -> None:
  draw = ImageDraw.Draw(image)
  for rect, label, value, icon in [
    ((46, 18, 232, 62), "金币", "60", "coin"),
    ((488, 18, 674, 62), "券", "10", "ticket"),
  ]:
    rounded(image, rect, with_alpha(c(option, "panel_light"), 238), c(option, "line"), width=3, radius=12)
    if icon == "coin":
      draw_coin(draw, (rect[0] + 22, (rect[1] + rect[3]) // 2), option)
    else:
      draw_ticket(draw, (rect[0] + 22, (rect[1] + rect[3]) // 2), option)
    left_text(draw, label, (rect[0] + 42, rect[1], rect[0] + 92, rect[3]), c(option, "dark_text"), 16, True)
    right_text(draw, value, (rect[0] + 88, rect[1], rect[2] - 10, rect[3]), c(option, "dark_text"), 20, True)


def draw_cta(image: Image.Image, option: SkinOption, rect: tuple[int, int, int, int], label: str, primary: bool = True) -> None:
  draw = ImageDraw.Draw(image)
  fill = c(option, "cta") if primary else with_alpha(c(option, "muted"), 235)
  rounded(image, rect, fill, c(option, "line"), width=5, radius=18)
  draw.rounded_rectangle((rect[0] + 9, rect[1] + 9, rect[2] - 9, rect[1] + 22), radius=7, fill=(255, 255, 255, 52))
  center_text(draw, label, rect, (255, 255, 255, 255), 26, True, (2, c(option, "line")))


def draw_nav(image: Image.Image, option: SkinOption) -> None:
  draw = ImageDraw.Draw(image)
  draw.rectangle((0, 1138, W, 1280), fill=c(option, "nav"))
  labels = ["商店", "编组", "战斗", "抽卡", "更多"]
  icon_fns = [draw_shop_icon, draw_cards_icon, draw_swords, draw_paw, draw_more_icon]
  for i, label in enumerate(labels):
    rect = (i * 144 + 3, 1148, i * 144 + 141, 1270)
    active = label == "战斗"
    fill = c(option, "nav_active") if active else c(option, "panel")
    rounded(image, rect, fill, c(option, "line"), width=3, radius=13)
    icon_color = c(option, "gold") if active else c(option, "text")
    icon_fns[i](draw, ((rect[0] + rect[2]) // 2, rect[1] + 42), option, icon_color)
    center_text(draw, label, (rect[0] + 4, rect[1] + 84, rect[2] - 4, rect[1] + 118), c(option, "text"), 23, True)
    if i in (0, 4):
      draw_lock(draw, (rect[2] - 24, rect[1] + 26), option)


def draw_rank_panel(image: Image.Image, option: SkinOption) -> None:
  draw = ImageDraw.Draw(image)
  rect = (58, 842, 662, 934)
  rounded(image, rect, c(option, "rank"), c(option, "line"), width=4, radius=14)
  left_text(draw, "青铜 1星", (80, 852, 332, 886), c(option, "text"), 28, True)
  right_text(draw, "段位赛", (408, 854, 638, 882), (229, 235, 255, 255), 20, True)
  for i in range(3):
    x = 88 + i * 26
    draw.ellipse((x, 896, x + 15, 911), fill=c(option, "gold") if i == 0 else (92, 89, 121, 255), outline=c(option, "line"), width=2)
  left_text(draw, "胜 0  负 0", (282, 890, 458, 916), (229, 235, 255, 255), 18, True)


def draw_lobby_scene(image: Image.Image, option: SkinOption) -> None:
  scene = (58, 144, 662, 824)
  draw = ImageDraw.Draw(image)
  rounded(image, scene, c(option, "scene"), c(option, "line"), width=5, radius=18)
  inner = (72, 158, 648, 810)
  draw.rounded_rectangle(inner, radius=13, fill=c(option, "scene_inner"))
  for i in range(7):
    y = 194 + i * 78
    draw.arc((94, y, 626, y + 150), 200, 340, fill=with_alpha(c(option, "grass"), 72), width=4)
  base = asset(ROOT / "assets" / "art" / "buildings" / "base.png", (200, 200))
  image.alpha_composite(base, (260, 260))

  area = (92, 178, 628, 790)
  points = [
    (0.28, 0.68),
    (0.50, 0.70),
    (0.72, 0.68),
    (0.38, 0.56),
    (0.62, 0.56),
    (0.22, 0.82),
    (0.50, 0.84),
    (0.78, 0.82),
  ]
  animals = ["gold_mine_card", "defense_watch_tower", "rabbit", "mouse", "frog", "chicken", "cat", "dog"]
  for i, (aid, anchor) in enumerate(zip(animals, points, strict=True)):
    x = round(area[0] + (area[2] - area[0]) * anchor[0])
    y = round(area[1] + (area[3] - area[1]) * anchor[1])
    max_size = (86, 86) if aid in ("gold_mine_card", "defense_watch_tower") else (96, 96)
    if aid == "gold_mine_card":
      path = ROOT / "assets" / "art" / "buildings" / "mine.png"
    elif aid == "defense_watch_tower":
      path = ROOT / "assets" / "art" / "buildings" / "tower.png"
    else:
      path = ROOT / "assets" / "card_art" / "animals" / f"{aid}.png"
    draw.ellipse((x - 26, y + 24, x + 26, y + 40), fill=(0, 0, 0, 46))
    paste_center(image, asset(path, max_size), (x, y))
    if i < 2:
      draw.rounded_rectangle((x - 18, y + 34, x + 18, y + 42), radius=4, fill=c(option, "gold"), outline=c(option, "line"), width=2)


def draw_lobby(option: SkinOption) -> Path:
  image = draw_background(option)
  draw = ImageDraw.Draw(image)
  draw_resource_bar(image, option)
  center_text(draw, "丛林法则", (40, 66, 680, 130), c(option, "text"), 46, True, (3, c(option, "line")))
  draw_lobby_scene(image, option)
  draw_rank_panel(image, option)
  draw_cta(image, option, (190, 958, 530, 1034), "匹配", True)
  draw_nav(image, option)
  path = OUT / f"current_game_ue_locked_{option.key.lower()}_{option.slug}_lobby.png"
  image.convert("RGB").save(path, quality=96)
  return path


def hex_center(x: int, y: int) -> tuple[float, float]:
  hex_size = 43.0
  board_width = math.sqrt(3.0) * hex_size * (7 + 0.5)
  origin_x = (W - board_width) * 0.5 + hex_size * 0.72
  origin_y = 120.0
  return origin_x + math.sqrt(3.0) * hex_size * (x + 0.5 * (y % 2)), origin_y + hex_size * 1.5 * y


def hex_points(center: tuple[float, float], radius: float = 43.0) -> list[tuple[float, float]]:
  cx, cy = center
  return [
    (
      cx + math.cos(math.radians(60 * i - 30)) * radius,
      cy + math.sin(math.radians(60 * i - 30)) * radius,
    )
    for i in range(6)
  ]


def draw_hex(
  draw: ImageDraw.ImageDraw,
  center: tuple[float, float],
  fill: tuple[int, int, int, int],
  outline: tuple[int, int, int, int],
  width: int,
) -> None:
  points = hex_points(center)
  draw.polygon(points, fill=fill)
  draw.line(points + [points[0]], fill=outline, width=width, joint="curve")


def draw_site_icon(draw: ImageDraw.ImageDraw, center: tuple[int, int], option: SkinOption, kind: str, cost: int, affordable: bool) -> None:
  x, y = center
  ink = c(option, "line")
  if kind == "mine":
    draw.polygon([(x - 23, y + 4), (x - 10, y - 22), (x, y - 6), (x + 12, y - 24), (x + 24, y + 4)], fill=c(option, "purple"), outline=ink)
    draw.line((x - 12, y - 4, x - 4, y - 15), fill=c(option, "gold"), width=3)
  elif kind == "tower":
    draw.polygon([(x - 12, y + 8), (x - 8, y - 22), (x, y - 32), (x + 8, y - 22), (x + 12, y + 8)], fill=c(option, "blue"), outline=ink)
    draw.line((x - 14, y - 18, x + 14, y - 18), fill=c(option, "gold"), width=3)
  elif kind == "camp":
    draw.polygon([(x - 24, y - 10), (x, y - 31), (x + 24, y - 10)], fill=c(option, "green"), outline=ink)
    draw.rounded_rectangle((x - 17, y - 10, x + 17, y + 12), radius=4, fill=mix(c(option, "green"), ink, 0.18), outline=ink, width=3)
  else:
    center_text(draw, "?", (x - 18, y - 35, x + 18, y + 4), ink, 31, True)
  coin_color = c(option, "gold") if affordable else with_alpha(c(option, "muted"), 255)
  draw_coin(draw, (x - 15, y + 20), option, "gold")
  center_text(draw, str(cost), (x - 4, y + 8, x + 38, y + 32), c(option, "dark_text") if affordable else c(option, "line"), 15, True)


def draw_battle_board(image: Image.Image, option: SkinOption) -> None:
  draw = ImageDraw.Draw(image)
  rounded(image, (36, 82, 684, 1120), c(option, "board_outer"), c(option, "board_line"), width=5, radius=18)
  rounded(image, (64, 110, 656, 1092), c(option, "board_inner"), c(option, "board_line"), width=4, radius=14, shadow=False)

  player_base = (3, 11)
  enemy_base = (3, 1)
  unlockables = {
    (3, 10): ("mystery", 25),
    (4, 10): ("camp", 50),
    (2, 11): ("tower", 50),
    (4, 11): ("mine", 50),
    (3, 12): ("mystery", 25),
    (4, 12): ("camp", 50),
  }
  for y in range(13):
    for x in range(7):
      center = hex_center(x, y)
      if (x, y) == player_base:
        fill = c(option, "player_tile")
        outline = mix(c(option, "player_tile"), c(option, "line"), 0.35)
        width = 3
      elif (x, y) == enemy_base:
        fill = c(option, "enemy_tile")
        outline = mix(c(option, "enemy_tile"), c(option, "line"), 0.35)
        width = 3
      elif (x, y) in unlockables:
        fill = c(option, "territory_player")
        outline = c(option, "gold")
        width = 4
      elif y >= 6:
        fill = c(option, "territory_player")
        outline = mix(c(option, "green"), c(option, "line"), 0.28, 148)
        width = 2
      else:
        fill = c(option, "territory_enemy")
        outline = mix(c(option, "red"), c(option, "line"), 0.25, 148)
        width = 2
      draw_hex(draw, center, fill, outline, width)

  for (x, y), (kind, cost) in unlockables.items():
    cx, cy = hex_center(x, y)
    draw_site_icon(draw, (round(cx), round(cy) - 3), option, kind, cost, cost <= 60)

  base_image = asset(ROOT / "assets" / "art" / "buildings" / "base.png", (78, 78))
  for key, tint in [(enemy_base, c(option, "red")), (player_base, c(option, "blue"))]:
    cx, cy = hex_center(*key)
    draw.ellipse((cx - 31, cy + 16, cx + 31, cy + 33), fill=(0, 0, 0, 48))
    paste_center(image, base_image, (round(cx), round(cy) - 8))
    draw.rounded_rectangle((cx - 24, cy + 26, cx + 24, cy + 32), radius=3, fill=c(option, "line"))
    draw.rounded_rectangle((cx - 22, cy + 27, cx + 18, cy + 31), radius=3, fill=tint)


def draw_match_status(image: Image.Image, option: SkinOption) -> None:
  draw = ImageDraw.Draw(image)
  rect = (250, 18, 470, 62)
  rounded(image, rect, c(option, "rank"), c(option, "line"), width=3, radius=10)
  center_text(draw, "青铜 1星  VS  青铜 1星", rect, c(option, "text"), 17, True)


def draw_pause_button(image: Image.Image, option: SkinOption) -> None:
  draw = ImageDraw.Draw(image)
  rect = (610, 78, 672, 134)
  rounded(image, rect, with_alpha(c(option, "panel_light"), 235), c(option, "line"), width=3, radius=10)
  draw.rounded_rectangle((629, 93, 637, 119), radius=2, fill=c(option, "line"))
  draw.rounded_rectangle((645, 93, 653, 119), radius=2, fill=c(option, "line"))


def draw_selection_panel(image: Image.Image, option: SkinOption) -> None:
  draw = ImageDraw.Draw(image)
  rect = (26, 1132, 694, 1250)
  rounded(image, rect, c(option, "rank"), c(option, "panel_mid"), width=4, radius=14)
  center_text(draw, "点击与己方地块接壤的卡牌地块解锁", (50, 1146, 670, 1178), c(option, "text"), 24, True)
  center_text(draw, "可解锁地块只显示类型和价格，品质会在解锁时随机。", (50, 1184, 670, 1210), (219, 229, 255, 255), 19, False)


def draw_battle(option: SkinOption) -> Path:
  image = draw_background(option)
  draw_resource_bar(image, option)
  draw_match_status(image, option)
  draw_battle_board(image, option)
  draw_selection_panel(image, option)
  draw_pause_button(image, option)
  path = OUT / f"current_game_ue_locked_{option.key.lower()}_{option.slug}_battle.png"
  image.convert("RGB").save(path, quality=96)
  return path


def draw_sheet(option: SkinOption, lobby_path: Path, battle_path: Path) -> Path:
  sheet = Image.new("RGB", (1520, 1570), (238, 244, 248))
  draw = ImageDraw.Draw(sheet)
  center_text(draw, f"方案 {option.key}：{option.title}", (0, 20, 1520, 76), (16, 24, 36, 255), 34, True)
  center_text(draw, "同一 UE：大厅页与战斗页只换 2D 美术皮肤，页面信息/点击区域/反馈节奏不变", (0, 76, 1520, 118), (71, 84, 103, 255), 18, False)
  sheet.paste(Image.open(lobby_path).convert("RGB"), (28, 128))
  sheet.paste(Image.open(battle_path).convert("RGB"), (772, 128))
  center_text(draw, "当前大厅页", (28, 1422, 748, 1460), (16, 24, 36, 255), 24, True)
  center_text(draw, "当前战斗页", (772, 1422, 1492, 1460), (16, 24, 36, 255), 24, True)
  y = 1472
  left_text(draw, f"定位：{option.summary}", (64, y, 1456, y + 28), (16, 24, 36, 255), 17)
  left_text(draw, f"适合：{option.best_for}", (64, y + 28, 1456, y + 56), (16, 24, 36, 255), 17)
  left_text(draw, f"风险：{option.risk}", (64, y + 56, 1456, y + 84), (16, 24, 36, 255), 17)
  path = OUT / f"current_game_ue_locked_{option.key.lower()}_{option.slug}_sheet.png"
  sheet.save(path, quality=96)
  return path


def build() -> dict[str, dict[str, Path]]:
  OUT.mkdir(parents=True, exist_ok=True)
  outputs: dict[str, dict[str, Path]] = {}
  for option in OPTIONS:
    lobby = draw_lobby(option)
    battle = draw_battle(option)
    sheet = draw_sheet(option, lobby, battle)
    outputs[option.key] = {"lobby": lobby, "battle": battle, "sheet": sheet}
  return outputs


def rel(path: Path) -> str:
  return path.relative_to(ROOT).as_posix()


def write_doc(outputs: dict[str, dict[str, Path]]) -> None:
  lines = [
    "# 当前游戏 2D UE 锁定美术皮肤方案",
    "",
    f"生成日期：{date.today().isoformat()}",
    "",
    "本轮只做页面美术皮肤升级，不重新设计页面，不调整 UE。",
    "",
    "## 1. 硬性锁定",
    "",
    "- 页面信息不变：大厅仍是金币、券、标题、场景、段位、匹配、底部五入口；战斗仍是金币、券、对战状态、棋盘、选中说明、暂停。",
    "- 页面布局不变：所有矩形坐标来自 `scripts/app/main.gd` 的当前绘制结构。",
    "- 点击目标不变：匹配按钮、底部导航、战斗地块、暂停按钮、选中信息区的范围不变。",
    "- 点击反馈不变：不新增动效节奏，不改变当前按钮、选中、呼吸、弹出、toast 和地块 pulse 的语义。",
    "- 维度不变：只做 2D，不使用 3D、2.5D、透视重构或等距重画。",
    "- 资产不变：动物、建筑仍优先使用项目现有 PNG；本轮只比较面板、背景、描边、材质、色彩和图标质感。",
    "",
    "## 2. 当前 UE 基线",
    "",
    "| 页面 | 锁定内容 | 这轮允许变化 |",
    "| --- | --- | --- |",
    "| 大厅页 | 顶部金币/券、标题、中央场景、段位面板、匹配按钮、底部五入口 | 背景质感、场景框、面板皮肤、按钮材质、描边和阴影 |",
    "| 战斗页 | 顶部金币/券、VS 状态、棋盘、可解锁地块提示、选中说明面板、暂停按钮 | 棋盘材质、地块皮肤、建筑/地块图标质感、面板和按钮皮肤 |",
    "",
    "## 3. 方案总览",
    "",
    "| 方案 | 名称 | 定位 | 适合 | 风险 | 评审图 |",
    "| --- | --- | --- | --- | --- | --- |",
  ]
  for option in OPTIONS:
    lines.append(
      f"| {option.key} | {option.title} | {option.summary} | {option.best_for} | {option.risk} | `{rel(outputs[option.key]['sheet'])}` |"
    )
  for option in OPTIONS:
    paths = outputs[option.key]
    lines.extend(
      [
        "",
        f"## 方案 {option.key}：{option.title}",
        "",
        f"![方案 {option.key}：{option.title}](../{rel(paths['sheet'])})",
        "",
        f"- 定位：{option.summary}",
        f"- 适合：{option.best_for}",
        f"- 风险：{option.risk}",
        f"- 大厅页单图：`{rel(paths['lobby'])}`",
        f"- 战斗页单图：`{rel(paths['battle'])}`",
      ]
    )
  lines.extend(
    [
      "",
      "## 4. 推荐选择",
      "",
      "优先推荐：",
      "",
      "1. B 高级叶脉：最符合“足够简单，又能体现高品质高质量”。",
      "2. A 街机丛林：最稳，最适合快速落地。",
      "3. C 晶石夜战：品质感强，但更适合高级主题或后续皮肤。",
      "4. D 庆典棋盘：活动感强，适合后续运营包装。",
      "",
      "我建议这轮优先在 A / B 之间选主方向：A 偏稳妥商业化，B 偏原创高级 2D。",
      "",
      "## 5. 审核后下一步",
      "",
      "用户选定方向后再推进：",
      "",
      "1. 拆出 UI 组件状态：普通、选中、禁用、可点击、不可点击、点击反馈。",
      "2. 按当前 Godot 坐标替换绘制皮肤，不改输入逻辑和页面流程。",
      "3. 做小屏可读性 QA：金币、券、选中说明、可解锁地块、暂停按钮、底部导航。",
      "4. 再进入 2D Technical Artist handoff：九宫格、atlas、导入设置、锚点、层级。",
    ]
  )
  DOC.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
  outputs = build()
  write_doc(outputs)
  for group in outputs.values():
    for path in group.values():
      print(f"Wrote {rel(path)}")
  print(f"Wrote {rel(DOC)}")
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
