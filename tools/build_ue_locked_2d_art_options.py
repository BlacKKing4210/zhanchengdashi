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
PREFIX = "current_game_ue_locked_v2"


Color = tuple[int, int, int, int]


@dataclass(frozen=True)
class SkinOption:
  key: str
  slug: str
  title: str
  visual_sentence: str
  summary: str
  best_for: str
  risk: str
  palette: dict[str, Color]


OPTIONS = [
  SkinOption(
    key="A",
    slug="emerald_enamel",
    title="翡翠珐琅",
    visual_sentence="清爽翡翠棋盘 + 深蓝珐琅面板 + 金色 CTA。",
    summary="最稳的正式版方向：块面更干净，描边更精致，信息层级最清楚。",
    best_for="第一版商业化落地，风险最低。",
    risk="个性相对克制，需要后续靠图标家族和微动效建立记忆点。",
    palette={
      "sky_top": (159, 232, 147, 255),
      "sky_bottom": (94, 185, 105, 255),
      "ground_top": (73, 169, 86, 255),
      "ground_bottom": (33, 118, 70, 255),
      "canopy": (27, 102, 62, 255),
      "canopy_light": (91, 189, 95, 255),
      "ink": (8, 17, 30, 255),
      "ink_soft": (24, 44, 64, 255),
      "panel": (29, 61, 119, 244),
      "panel_2": (38, 98, 151, 245),
      "panel_light": (222, 244, 251, 247),
      "panel_warm": (246, 228, 162, 246),
      "scene": (94, 181, 94, 255),
      "scene_2": (119, 204, 102, 255),
      "rank": (37, 33, 101, 248),
      "nav": (34, 33, 96, 250),
      "nav_active": (37, 140, 224, 255),
      "cta": (255, 181, 42, 255),
      "cta_2": (232, 117, 30, 255),
      "gold": (255, 209, 58, 255),
      "blue": (49, 171, 255, 255),
      "green": (99, 220, 91, 255),
      "red": (231, 74, 69, 255),
      "purple": (152, 94, 246, 255),
      "board_outer": (247, 201, 86, 255),
      "board_inner": (95, 185, 77, 255),
      "board_line": (43, 98, 54, 255),
      "tile_enemy": (230, 87, 82, 178),
      "tile_player": (78, 205, 92, 178),
      "tile_neutral": (236, 211, 148, 136),
      "text": (255, 255, 255, 255),
      "dark_text": (13, 22, 33, 255),
      "muted": (167, 181, 188, 255),
    },
  ),
  SkinOption(
    key="B",
    slug="silk_grove",
    title="绢纸林境",
    visual_sentence="绢纸质感 + 柔和林地 + 少量金色交互焦点。",
    summary="最符合 v1.6 简单高品质 2D：少颜色、少层级，但材质和比例更高级。",
    best_for="想要简单、原创、长期耐看的主方向。",
    risk="战斗刺激感不如 A/C，需要保证 CTA 和选中描边足够亮。",
    palette={
      "sky_top": (188, 225, 166, 255),
      "sky_bottom": (117, 178, 121, 255),
      "ground_top": (88, 156, 96, 255),
      "ground_bottom": (56, 121, 82, 255),
      "canopy": (53, 112, 68, 255),
      "canopy_light": (122, 183, 100, 255),
      "ink": (38, 45, 31, 255),
      "ink_soft": (80, 88, 60, 255),
      "panel": (218, 200, 145, 244),
      "panel_2": (119, 146, 84, 245),
      "panel_light": (255, 241, 195, 248),
      "panel_warm": (244, 224, 164, 247),
      "scene": (124, 176, 97, 255),
      "scene_2": (145, 193, 105, 255),
      "rank": (83, 78, 55, 248),
      "nav": (82, 79, 57, 250),
      "nav_active": (50, 141, 166, 255),
      "cta": (242, 176, 47, 255),
      "cta_2": (177, 104, 39, 255),
      "gold": (232, 181, 55, 255),
      "blue": (52, 143, 195, 255),
      "green": (101, 172, 79, 255),
      "red": (184, 78, 56, 255),
      "purple": (149, 93, 181, 255),
      "board_outer": (185, 144, 84, 255),
      "board_inner": (126, 174, 89, 255),
      "board_line": (73, 104, 55, 255),
      "tile_enemy": (176, 104, 70, 164),
      "tile_player": (106, 174, 88, 166),
      "tile_neutral": (226, 207, 153, 126),
      "text": (255, 250, 226, 255),
      "dark_text": (50, 45, 31, 255),
      "muted": (128, 124, 95, 255),
    },
  ),
  SkinOption(
    key="C",
    slug="moonstone_glass",
    title="月石玻璃",
    visual_sentence="夜色月石 + 玻璃边线 + 高亮蓝绿棋盘。",
    summary="品质感最强的高级主题方向，深色更有价值感但仍保持当前 UE。",
    best_for="后续高级皮肤、赛季主题或更强商业包装。",
    risk="深色会压小屏文字，需要严格保持资源条、按钮和选中态亮度。",
    palette={
      "sky_top": (55, 88, 138, 255),
      "sky_bottom": (31, 53, 91, 255),
      "ground_top": (38, 76, 99, 255),
      "ground_bottom": (19, 34, 67, 255),
      "canopy": (35, 87, 101, 255),
      "canopy_light": (69, 131, 148, 255),
      "ink": (5, 10, 22, 255),
      "ink_soft": (21, 44, 65, 255),
      "panel": (20, 34, 70, 244),
      "panel_2": (34, 86, 137, 245),
      "panel_light": (208, 228, 249, 248),
      "panel_warm": (225, 230, 242, 248),
      "scene": (53, 119, 126, 255),
      "scene_2": (61, 139, 141, 255),
      "rank": (20, 28, 76, 250),
      "nav": (20, 30, 66, 250),
      "nav_active": (29, 124, 190, 255),
      "cta": (250, 174, 42, 255),
      "cta_2": (189, 91, 29, 255),
      "gold": (255, 204, 75, 255),
      "blue": (65, 204, 255, 255),
      "green": (91, 226, 173, 255),
      "red": (244, 82, 83, 255),
      "purple": (177, 111, 255, 255),
      "board_outer": (57, 92, 126, 255),
      "board_inner": (48, 111, 118, 255),
      "board_line": (24, 66, 82, 255),
      "tile_enemy": (230, 73, 82, 184),
      "tile_player": (74, 215, 190, 174),
      "tile_neutral": (65, 118, 132, 126),
      "text": (244, 252, 255, 255),
      "dark_text": (8, 16, 28, 255),
      "muted": (157, 182, 207, 255),
    },
  ),
  SkinOption(
    key="D",
    slug="warm_festival",
    title="暖金庆典",
    visual_sentence="暖金边框 + 清爽棋盘 + 活动感按钮。",
    summary="更明亮、更有奖励感，但保持装饰克制，不改变页面信息。",
    best_for="希望主界面更热闹，后续方便接活动、礼包和赛季奖励。",
    risk="暖色容易抢棋盘信息，落地时要控制装饰和饱和度。",
    palette={
      "sky_top": (214, 232, 130, 255),
      "sky_bottom": (131, 202, 103, 255),
      "ground_top": (85, 174, 84, 255),
      "ground_bottom": (54, 131, 76, 255),
      "canopy": (46, 135, 72, 255),
      "canopy_light": (143, 201, 87, 255),
      "ink": (52, 31, 26, 255),
      "ink_soft": (96, 66, 44, 255),
      "panel": (121, 60, 90, 242),
      "panel_2": (215, 113, 87, 245),
      "panel_light": (255, 238, 182, 248),
      "panel_warm": (255, 230, 162, 247),
      "scene": (120, 190, 86, 255),
      "scene_2": (142, 209, 91, 255),
      "rank": (111, 54, 94, 250),
      "nav": (105, 54, 91, 250),
      "nav_active": (46, 142, 204, 255),
      "cta": (255, 193, 45, 255),
      "cta_2": (194, 92, 32, 255),
      "gold": (255, 214, 67, 255),
      "blue": (57, 168, 230, 255),
      "green": (88, 204, 91, 255),
      "red": (220, 70, 72, 255),
      "purple": (169, 84, 216, 255),
      "board_outer": (238, 154, 74, 255),
      "board_inner": (123, 194, 81, 255),
      "board_line": (101, 84, 44, 255),
      "tile_enemy": (218, 77, 73, 176),
      "tile_player": (98, 194, 79, 170),
      "tile_neutral": (240, 211, 138, 126),
      "text": (255, 250, 240, 255),
      "dark_text": (55, 32, 25, 255),
      "muted": (160, 134, 109, 255),
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


def p(option: SkinOption, name: str) -> Color:
  return option.palette[name]


def alpha(color: Color, value: int) -> Color:
  return color[0], color[1], color[2], value


def blend(a: Color, b: Color, t: float, out_alpha: int | None = None) -> Color:
  return (
    round(a[0] + (b[0] - a[0]) * t),
    round(a[1] + (b[1] - a[1]) * t),
    round(a[2] + (b[2] - a[2]) * t),
    a[3] if out_alpha is None else out_alpha,
  )


def lighten(color: Color, amount: float) -> Color:
  return blend(color, (255, 255, 255, color[3]), amount, color[3])


def darken(color: Color, amount: float) -> Color:
  return blend(color, (0, 0, 0, color[3]), amount, color[3])


def text_size(draw: ImageDraw.ImageDraw, value: str, fnt: ImageFont.FreeTypeFont) -> tuple[int, int]:
  box = draw.textbbox((0, 0), value, font=fnt)
  return box[2] - box[0], box[3] - box[1]


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
  fill: Color,
  size: int,
  bold: bool = False,
  stroke: tuple[int, Color] | None = None,
) -> None:
  value = fit_text(draw, value, rect[2] - rect[0] - 8, size, bold)
  fnt = font(size, bold)
  tw, th = text_size(draw, value, fnt)
  x = rect[0] + (rect[2] - rect[0] - tw) / 2
  y = rect[1] + (rect[3] - rect[1] - th) / 2 - 2
  if stroke is None:
    draw.text((x, y), value, font=fnt, fill=fill)
  else:
    draw.text((x, y), value, font=fnt, fill=fill, stroke_width=stroke[0], stroke_fill=stroke[1])


def left_text(draw: ImageDraw.ImageDraw, value: str, rect: tuple[int, int, int, int], fill: Color, size: int, bold: bool = False) -> None:
  value = fit_text(draw, value, rect[2] - rect[0], size, bold)
  fnt = font(size, bold)
  _, th = text_size(draw, value, fnt)
  y = rect[1] + (rect[3] - rect[1] - th) / 2 - 2
  draw.text((rect[0], y), value, font=fnt, fill=fill)


def right_text(draw: ImageDraw.ImageDraw, value: str, rect: tuple[int, int, int, int], fill: Color, size: int, bold: bool = False) -> None:
  value = fit_text(draw, value, rect[2] - rect[0], size, bold)
  fnt = font(size, bold)
  tw, th = text_size(draw, value, fnt)
  y = rect[1] + (rect[3] - rect[1] - th) / 2 - 2
  draw.text((rect[2] - tw, y), value, font=fnt, fill=fill)


def gradient(size: tuple[int, int], top: Color, bottom: Color) -> Image.Image:
  image = Image.new("RGBA", size, top)
  draw = ImageDraw.Draw(image)
  for y in range(size[1]):
    draw.line((0, y, size[0], y), fill=blend(top, bottom, y / max(1, size[1] - 1)))
  return image


def add_noise(image: Image.Image, seed_text: str, amount: int, opacity: int) -> None:
  layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
  pix = layer.load()
  value = sum(ord(ch) for ch in seed_text) + 9173
  for _ in range(amount):
    value = (1103515245 * value + 12345) & 0x7FFFFFFF
    x = value % image.width
    value = (1103515245 * value + 12345) & 0x7FFFFFFF
    y = value % image.height
    pix[x, y] = (255, 255, 255, 8 + value % opacity)
  image.alpha_composite(layer.filter(ImageFilter.GaussianBlur(0.28)))


def add_vignette(image: Image.Image, strength: int = 78) -> None:
  layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
  pix = layer.load()
  cx, cy = image.width * 0.5, image.height * 0.5
  max_dist = math.hypot(cx, cy)
  for y in range(image.height):
    for x in range(image.width):
      d = math.hypot(x - cx, y - cy) / max_dist
      a = int(max(0.0, (d - 0.48) / 0.52) * strength)
      if a:
        pix[x, y] = (0, 0, 0, a)
  image.alpha_composite(layer)


def panel(
  image: Image.Image,
  rect: tuple[int, int, int, int],
  fill: Color,
  line: Color,
  radius: int = 14,
  width: int = 4,
  shadow: int = 72,
  bevel: bool = True,
) -> None:
  layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
  draw = ImageDraw.Draw(layer)
  if shadow:
    draw.rounded_rectangle((rect[0], rect[1] + 7, rect[2], rect[3] + 7), radius=radius, fill=(0, 0, 0, shadow))
    image.alpha_composite(layer.filter(ImageFilter.GaussianBlur(1.4)))
    layer = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
  draw.rounded_rectangle(rect, radius=radius, fill=fill, outline=line, width=width)
  if bevel:
    x1, y1, x2, y2 = rect
    draw.rounded_rectangle((x1 + 7, y1 + 6, x2 - 7, y1 + 23), radius=max(5, radius - 8), fill=(255, 255, 255, 42))
    draw.line((x1 + radius, y2 - 6, x2 - radius, y2 - 6), fill=(0, 0, 0, 44), width=2)
    draw.rounded_rectangle((x1 + width + 3, y1 + width + 3, x2 - width - 3, y2 - width - 3), radius=max(4, radius - 7), outline=(255, 255, 255, 32), width=1)
  image.alpha_composite(layer)


def asset(path: Path, max_size: tuple[int, int]) -> Image.Image:
  image = Image.open(path).convert("RGBA")
  box = image.getbbox()
  if box:
    image = image.crop(box)
  image.thumbnail(max_size, Image.Resampling.LANCZOS)
  return image


def paste_center(base: Image.Image, image: Image.Image, center: tuple[int, int]) -> None:
  base.alpha_composite(image, (round(center[0] - image.width / 2), round(center[1] - image.height / 2)))


def draw_background(option: SkinOption) -> Image.Image:
  image = gradient((W, H), p(option, "ground_top"), p(option, "ground_bottom"))
  draw = ImageDraw.Draw(image)
  draw.rectangle((0, 0, W, 220), fill=p(option, "sky_top"))
  for y in range(220):
    t = y / 219
    draw.line((0, y, W, y), fill=blend(p(option, "sky_top"), p(option, "sky_bottom"), t))
  for i in range(15):
    x = -90 + i * 62
    draw.ellipse((x, 122, x + 190, 268), fill=alpha(p(option, "canopy"), 84))
    draw.arc((x + 10, 134, x + 178, 246), 205, 335, fill=alpha(lighten(p(option, "canopy_light"), 0.05), 120), width=3)
  draw.rectangle((0, 246, W, 382), fill=alpha(p(option, "canopy"), 180))
  draw.rectangle((0, 382, W, 1280), fill=alpha(p(option, "ground_top"), 92))
  for i in range(9):
    y = 448 + i * 74
    draw.arc((40, y, 680, y + 150), 202, 338, fill=alpha(p(option, "canopy_light"), 36), width=3)
  add_noise(image, option.slug, 4600, 16)
  add_vignette(image, 42)
  return image


def coin(draw: ImageDraw.ImageDraw, center: tuple[int, int], option: SkinOption) -> None:
  x, y = center
  draw.ellipse((x - 13, y - 13, x + 13, y + 13), fill=p(option, "gold"), outline=p(option, "ink"), width=3)
  draw.ellipse((x - 7, y - 7, x + 7, y + 7), fill=(255, 244, 142, 238))
  draw.arc((x - 10, y - 10, x + 10, y + 10), 210, 320, fill=(255, 255, 255, 150), width=2)


def ticket(draw: ImageDraw.ImageDraw, center: tuple[int, int], option: SkinOption) -> None:
  x, y = center
  draw.rounded_rectangle((x - 16, y - 10, x + 16, y + 10), radius=5, fill=p(option, "blue"), outline=p(option, "ink"), width=3)
  draw.line((x - 6, y - 8, x - 2, y + 8), fill=(255, 255, 255, 125), width=2)
  draw.line((x + 4, y - 8, x + 8, y + 8), fill=(255, 255, 255, 125), width=2)


def draw_resource_bar(image: Image.Image, option: SkinOption) -> None:
  draw = ImageDraw.Draw(image)
  for rect, label, value, kind in [
    ((46, 18, 232, 62), "金币", "60", "coin"),
    ((488, 18, 674, 62), "券", "10", "ticket"),
  ]:
    panel(image, rect, alpha(p(option, "panel_light"), 241), p(option, "ink"), radius=12, width=3, shadow=58)
    if kind == "coin":
      coin(draw, (rect[0] + 22, (rect[1] + rect[3]) // 2), option)
    else:
      ticket(draw, (rect[0] + 22, (rect[1] + rect[3]) // 2), option)
    left_text(draw, label, (rect[0] + 42, rect[1], rect[0] + 92, rect[3]), p(option, "dark_text"), 16, True)
    right_text(draw, value, (rect[0] + 88, rect[1], rect[2] - 10, rect[3]), p(option, "dark_text"), 20, True)


def paw(draw: ImageDraw.ImageDraw, center: tuple[int, int], option: SkinOption, fill: Color) -> None:
  x, y = center
  draw.ellipse((x - 9, y - 3, x + 9, y + 13), fill=fill, outline=p(option, "ink"), width=2)
  for dx, dy in [(-12, -10), (-4, -15), (5, -15), (13, -9)]:
    draw.ellipse((x + dx - 4, y + dy - 4, x + dx + 4, y + dy + 4), fill=fill, outline=p(option, "ink"), width=1)


def swords(draw: ImageDraw.ImageDraw, center: tuple[int, int], option: SkinOption, fill: Color) -> None:
  x, y = center
  for sx in (-1, 1):
    draw.line((x - 19 * sx, y - 18, x + 19 * sx, y + 20), fill=p(option, "ink"), width=8)
    draw.line((x - 19 * sx, y - 18, x + 19 * sx, y + 20), fill=fill, width=4)


def cards_icon(draw: ImageDraw.ImageDraw, center: tuple[int, int], option: SkinOption, fill: Color) -> None:
  x, y = center
  for i in range(2):
    draw.rounded_rectangle((x - 18 + i * 10, y - 18 + i * 5, x + 8 + i * 10, y + 16 + i * 5), radius=5, fill=fill, outline=p(option, "ink"), width=3)


def shop_icon(draw: ImageDraw.ImageDraw, center: tuple[int, int], option: SkinOption, fill: Color) -> None:
  x, y = center
  draw.rounded_rectangle((x - 24, y - 8, x + 24, y + 20), radius=5, fill=fill, outline=p(option, "ink"), width=3)
  draw.rectangle((x - 29, y - 24, x + 29, y - 7), fill=p(option, "red"), outline=p(option, "ink"), width=3)


def more_icon(draw: ImageDraw.ImageDraw, center: tuple[int, int], option: SkinOption, fill: Color) -> None:
  x, y = center
  for dx in (-15, 0, 15):
    draw.ellipse((x + dx - 5, y - 5, x + dx + 5, y + 5), fill=fill, outline=p(option, "ink"), width=2)


def lock_icon(draw: ImageDraw.ImageDraw, center: tuple[int, int], option: SkinOption) -> None:
  x, y = center
  draw.rounded_rectangle((x - 11, y - 2, x + 11, y + 15), radius=4, fill=p(option, "ink"), outline=(235, 243, 255, 255), width=2)
  draw.arc((x - 9, y - 15, x + 9, y + 5), 180, 360, fill=(235, 243, 255, 255), width=3)


def draw_cta(image: Image.Image, option: SkinOption, rect: tuple[int, int, int, int], label: str, primary: bool = True) -> None:
  draw = ImageDraw.Draw(image)
  fill = p(option, "cta") if primary else p(option, "muted")
  panel(image, rect, fill, p(option, "ink"), radius=18, width=5, shadow=84)
  x1, y1, x2, _ = rect
  draw.rounded_rectangle((x1 + 10, y1 + 9, x2 - 10, y1 + 25), radius=8, fill=(255, 255, 255, 72))
  draw.line((x1 + 18, y1 + 57, x2 - 18, y1 + 57), fill=alpha(p(option, "cta_2"), 160), width=3)
  center_text(draw, label, rect, (255, 255, 255, 255), 26, True, (2, p(option, "ink")))


def draw_nav(image: Image.Image, option: SkinOption) -> None:
  draw = ImageDraw.Draw(image)
  draw.rectangle((0, 1138, W, 1280), fill=p(option, "nav"))
  labels = ["商店", "编组", "战斗", "抽卡", "更多"]
  icon_fns = [shop_icon, cards_icon, swords, paw, more_icon]
  for i, label in enumerate(labels):
    rect = (i * 144 + 3, 1148, i * 144 + 141, 1270)
    active = label == "战斗"
    fill = p(option, "nav_active") if active else p(option, "panel")
    panel(image, rect, fill, p(option, "ink"), radius=13, width=3, shadow=52)
    icon_color = p(option, "gold") if active else p(option, "text")
    icon_fns[i](draw, ((rect[0] + rect[2]) // 2, rect[1] + 42), option, icon_color)
    center_text(draw, label, (rect[0] + 4, rect[1] + 84, rect[2] - 4, rect[1] + 118), p(option, "text"), 23, True)
    if i in (0, 4):
      lock_icon(draw, (rect[2] - 24, rect[1] + 26), option)


def draw_lobby_scene(image: Image.Image, option: SkinOption) -> None:
  draw = ImageDraw.Draw(image)
  scene = (58, 144, 662, 824)
  panel(image, scene, p(option, "scene"), p(option, "ink"), radius=18, width=5, shadow=82)
  inner = (72, 158, 648, 810)
  draw.rounded_rectangle(inner, radius=13, fill=p(option, "scene_2"))
  for i in range(8):
    y = 195 + i * 72
    draw.arc((104, y, 616, y + 140), 205, 335, fill=alpha(darken(p(option, "canopy"), 0.10), 84), width=3)
  for i in range(5):
    x = 118 + i * 118
    draw.line((x, 183, x + 38, 796), fill=alpha(lighten(p(option, "scene_2"), 0.25), 38), width=2)

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
  ids = ["gold_mine_card", "defense_watch_tower", "rabbit", "mouse", "frog", "chicken", "cat", "dog"]
  for index, (card_id, anchor) in enumerate(zip(ids, points, strict=True)):
    x = round(area[0] + (area[2] - area[0]) * anchor[0])
    y = round(area[1] + (area[3] - area[1]) * anchor[1])
    if card_id == "gold_mine_card":
      path = ROOT / "assets" / "art" / "buildings" / "mine.png"
      max_size = (86, 86)
    elif card_id == "defense_watch_tower":
      path = ROOT / "assets" / "art" / "buildings" / "tower.png"
      max_size = (86, 86)
    else:
      path = ROOT / "assets" / "card_art" / "animals" / f"{card_id}.png"
      max_size = (96, 96)
    draw.ellipse((x - 30, y + 24, x + 30, y + 42), fill=(0, 0, 0, 48))
    paste_center(image, asset(path, max_size), (x, y))
    if index < 2:
      draw.rounded_rectangle((x - 18, y + 34, x + 18, y + 42), radius=4, fill=p(option, "gold"), outline=p(option, "ink"), width=2)


def draw_rank_panel(image: Image.Image, option: SkinOption) -> None:
  draw = ImageDraw.Draw(image)
  rect = (58, 842, 662, 934)
  panel(image, rect, p(option, "rank"), p(option, "ink"), radius=14, width=4, shadow=70)
  left_text(draw, "青铜 1星", (80, 852, 332, 886), p(option, "text"), 28, True)
  right_text(draw, "段位赛", (408, 854, 638, 882), alpha(p(option, "text"), 226), 20, True)
  for i in range(3):
    x = 88 + i * 26
    draw.ellipse((x, 896, x + 15, 911), fill=p(option, "gold") if i == 0 else alpha(p(option, "muted"), 190), outline=p(option, "ink"), width=2)
  left_text(draw, "胜 0  负 0", (282, 890, 458, 916), alpha(p(option, "text"), 226), 18, True)


def draw_lobby(option: SkinOption) -> Path:
  image = draw_background(option)
  draw = ImageDraw.Draw(image)
  draw_resource_bar(image, option)
  center_text(draw, "丛林法则", (40, 66, 680, 130), p(option, "text"), 46, True, (3, p(option, "ink")))
  draw_lobby_scene(image, option)
  draw_rank_panel(image, option)
  draw_cta(image, option, (190, 958, 530, 1034), "匹配", True)
  draw_nav(image, option)
  path = OUT / f"{PREFIX}_{option.key.lower()}_{option.slug}_lobby.png"
  image.convert("RGB").save(path, quality=96)
  return path


def hex_center(x: int, y: int) -> tuple[float, float]:
  hex_size = 43.0
  board_width = math.sqrt(3.0) * hex_size * 7.5
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


def draw_hex(draw: ImageDraw.ImageDraw, center: tuple[float, float], fill: Color, line: Color, width: int) -> None:
  pts = hex_points(center)
  draw.polygon(pts, fill=fill)
  draw.line(pts + [pts[0]], fill=line, width=width, joint="curve")
  if width >= 3:
    inner = hex_points(center, 37.0)
    draw.line(inner + [inner[0]], fill=(255, 255, 255, 42), width=1, joint="curve")


def site_icon(draw: ImageDraw.ImageDraw, center: tuple[int, int], option: SkinOption, kind: str, cost: int) -> None:
  x, y = center
  ink = p(option, "ink")
  if kind == "mine":
    draw.polygon([(x - 23, y + 5), (x - 10, y - 22), (x, y - 6), (x + 12, y - 24), (x + 24, y + 5)], fill=p(option, "purple"), outline=ink)
    draw.line((x - 12, y - 4, x - 4, y - 15), fill=p(option, "gold"), width=3)
  elif kind == "tower":
    draw.polygon([(x - 12, y + 8), (x - 8, y - 22), (x, y - 32), (x + 8, y - 22), (x + 12, y + 8)], fill=p(option, "blue"), outline=ink)
    draw.line((x - 14, y - 18, x + 14, y - 18), fill=p(option, "gold"), width=3)
  elif kind == "camp":
    draw.polygon([(x - 24, y - 10), (x, y - 31), (x + 24, y - 10)], fill=p(option, "green"), outline=ink)
    draw.rounded_rectangle((x - 17, y - 10, x + 17, y + 12), radius=4, fill=darken(p(option, "green"), 0.20), outline=ink, width=3)
  else:
    center_text(draw, "?", (x - 18, y - 35, x + 18, y + 4), ink, 31, True)
  coin(draw, (x - 15, y + 20), option)
  center_text(draw, str(cost), (x - 4, y + 8, x + 38, y + 32), p(option, "dark_text"), 15, True)


def draw_battle_board(image: Image.Image, option: SkinOption) -> None:
  draw = ImageDraw.Draw(image)
  panel(image, (36, 82, 684, 1120), p(option, "board_outer"), p(option, "board_line"), radius=18, width=5, shadow=78)
  panel(image, (64, 110, 656, 1092), p(option, "board_inner"), p(option, "board_line"), radius=14, width=4, shadow=0)
  for i in range(8):
    y = 148 + i * 112
    draw.arc((92, y, 628, y + 180), 205, 335, fill=alpha(lighten(p(option, "board_inner"), 0.18), 42), width=3)

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
        fill = p(option, "tile_player")
        line = darken(p(option, "green"), 0.36)
        width = 3
      elif (x, y) == enemy_base:
        fill = p(option, "tile_enemy")
        line = darken(p(option, "red"), 0.36)
        width = 3
      elif (x, y) in unlockables:
        fill = alpha(p(option, "tile_player"), 118)
        line = p(option, "gold")
        width = 4
      elif y >= 6:
        fill = p(option, "tile_player")
        line = alpha(darken(p(option, "green"), 0.32), 145)
        width = 2
      else:
        fill = p(option, "tile_enemy")
        line = alpha(darken(p(option, "red"), 0.26), 145)
        width = 2
      draw_hex(draw, center, fill, line, width)

  for (x, y), (kind, cost) in unlockables.items():
    cx, cy = hex_center(x, y)
    site_icon(draw, (round(cx), round(cy) - 3), option, kind, cost)

  base_image = asset(ROOT / "assets" / "art" / "buildings" / "base.png", (78, 78))
  for key, tint in [(enemy_base, p(option, "red")), (player_base, p(option, "blue"))]:
    cx, cy = hex_center(*key)
    draw.ellipse((cx - 31, cy + 16, cx + 31, cy + 33), fill=(0, 0, 0, 52))
    paste_center(image, base_image, (round(cx), round(cy) - 8))
    draw.rounded_rectangle((cx - 24, cy + 26, cx + 24, cy + 32), radius=3, fill=p(option, "ink"))
    draw.rounded_rectangle((cx - 22, cy + 27, cx + 18, cy + 31), radius=3, fill=tint)


def draw_match_status(image: Image.Image, option: SkinOption) -> None:
  draw = ImageDraw.Draw(image)
  rect = (250, 18, 470, 62)
  panel(image, rect, p(option, "rank"), p(option, "ink"), radius=10, width=3, shadow=58)
  center_text(draw, "青铜 1星  VS  青铜 1星", rect, p(option, "text"), 17, True)


def draw_pause_button(image: Image.Image, option: SkinOption) -> None:
  draw = ImageDraw.Draw(image)
  rect = (610, 78, 672, 134)
  panel(image, rect, alpha(p(option, "panel_light"), 238), p(option, "ink"), radius=10, width=3, shadow=60)
  draw.rounded_rectangle((629, 93, 637, 119), radius=2, fill=p(option, "ink"))
  draw.rounded_rectangle((645, 93, 653, 119), radius=2, fill=p(option, "ink"))


def draw_selection_panel(image: Image.Image, option: SkinOption) -> None:
  draw = ImageDraw.Draw(image)
  rect = (26, 1132, 694, 1250)
  panel(image, rect, p(option, "rank"), p(option, "panel_2"), radius=14, width=4, shadow=70)
  center_text(draw, "点击与己方地块接壤的卡牌地块解锁", (50, 1146, 670, 1178), p(option, "text"), 24, True)
  center_text(draw, "可解锁地块只显示类型和价格，品质会在解锁时随机。", (50, 1184, 670, 1210), alpha(p(option, "text"), 226), 19, False)


def draw_battle(option: SkinOption) -> Path:
  image = draw_background(option)
  draw_resource_bar(image, option)
  draw_match_status(image, option)
  draw_battle_board(image, option)
  draw_selection_panel(image, option)
  draw_pause_button(image, option)
  path = OUT / f"{PREFIX}_{option.key.lower()}_{option.slug}_battle.png"
  image.convert("RGB").save(path, quality=96)
  return path


def draw_sheet(option: SkinOption, lobby: Path, battle: Path) -> Path:
  sheet = Image.new("RGB", (1520, 1600), (238, 244, 248))
  draw = ImageDraw.Draw(sheet)
  center_text(draw, f"方案 {option.key}：{option.title}", (0, 18, 1520, 70), (16, 24, 36, 255), 34, True)
  center_text(draw, option.visual_sentence, (0, 70, 1520, 104), (53, 67, 86, 255), 20, False)
  center_text(draw, "同一 UE：大厅页与战斗页只升级 2D 美术皮肤，页面信息/点击区域/反馈节奏不变", (0, 104, 1520, 130), (86, 99, 117, 255), 17, False)
  sheet.paste(Image.open(lobby).convert("RGB"), (28, 140))
  sheet.paste(Image.open(battle).convert("RGB"), (772, 140))
  center_text(draw, "当前大厅页", (28, 1434, 748, 1468), (16, 24, 36, 255), 24, True)
  center_text(draw, "当前战斗页", (772, 1434, 1492, 1468), (16, 24, 36, 255), 24, True)
  y = 1482
  left_text(draw, f"定位：{option.summary}", (64, y, 1456, y + 28), (16, 24, 36, 255), 17)
  left_text(draw, f"适合：{option.best_for}", (64, y + 28, 1456, y + 56), (16, 24, 36, 255), 17)
  left_text(draw, f"风险：{option.risk}", (64, y + 56, 1456, y + 84), (16, 24, 36, 255), 17)
  path = OUT / f"{PREFIX}_{option.key.lower()}_{option.slug}_sheet.png"
  sheet.save(path, quality=96)
  return path


def rel(path: Path) -> str:
  return path.relative_to(ROOT).as_posix()


def build() -> dict[str, dict[str, Path]]:
  OUT.mkdir(parents=True, exist_ok=True)
  outputs: dict[str, dict[str, Path]] = {}
  for option in OPTIONS:
    lobby = draw_lobby(option)
    battle = draw_battle(option)
    sheet = draw_sheet(option, lobby, battle)
    outputs[option.key] = {"lobby": lobby, "battle": battle, "sheet": sheet}
  return outputs


def write_doc(outputs: dict[str, dict[str, Path]]) -> None:
  lines = [
    "# 当前游戏 2D UE 锁定美术皮肤方案",
    "",
    f"生成日期：{date.today().isoformat()}",
    "",
    "本轮按公共流程 v1.6 的“简单高品质 2D”质量门禁再次迭代：少形状、少颜色、少层级，但提升比例、间距、对比、材质、组件复用和小屏可读性。",
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
    "## 2. v1.6 质量 Gate",
    "",
    "- 每个页面只保留一个主要视觉焦点。",
    "- 控制形状、颜色、层级和状态数量，不通过堆细节显得高级。",
    "- 资源条、CTA、选中态、锁定态和战斗地块必须在 3 秒内读懂。",
    "- UI 覆盖在玩法背景上仍需清晰可读。",
    "- 所有方案都必须能拆成可复用组件：资源条、场景框、段位面板、CTA、底部导航、棋盘框、地块、暂停按钮、选中说明面板。",
    "",
    "## 3. 当前 UE 基线",
    "",
    "| 页面 | 锁定内容 | 本轮允许变化 |",
    "| --- | --- | --- |",
    "| 大厅页 | 顶部金币/券、标题、中央场景、段位面板、匹配按钮、底部五入口 | 背景质感、场景框、面板皮肤、按钮材质、描边、阴影、色彩脚本 |",
    "| 战斗页 | 顶部金币/券、VS 状态、棋盘、可解锁地块提示、选中说明面板、暂停按钮 | 棋盘材质、地块皮肤、建筑/地块图标质感、面板和按钮皮肤 |",
    "",
    "## 4. 方案总览",
    "",
    "| 方案 | 名称 | 视觉句子 | 定位 | 适合 | 风险 | 评审图 |",
    "| --- | --- | --- | --- | --- | --- | --- |",
  ]
  for option in OPTIONS:
    lines.append(
      f"| {option.key} | {option.title} | {option.visual_sentence} | {option.summary} | {option.best_for} | {option.risk} | `{rel(outputs[option.key]['sheet'])}` |"
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
        f"- 视觉句子：{option.visual_sentence}",
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
      "## 5. 推荐选择",
      "",
      "优先推荐：",
      "",
      "1. B 绢纸林境：最符合 v1.6 的“简单高品质 2D”，长期耐看，复杂度最低。",
      "2. A 翡翠珐琅：最稳，最适合第一版商业化落地。",
      "3. C 月石玻璃：品质感强，适合作为高级主题或后续皮肤。",
      "4. D 暖金庆典：活动感强，适合后续运营包装。",
      "",
      "我建议这轮优先在 B / A 之间选主方向：B 更高级克制，A 更稳妥商业化。",
      "",
      "## 6. 审核后下一步",
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
