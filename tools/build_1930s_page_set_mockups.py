from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont, ImageOps


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "visual_concepts"
MAIN_BASE = OUT / "current_game_1930s_v7_e_ai_painted_full_ui_base_with_icons.png"
DECK_BASE = OUT / "current_game_1930s_v10_h_deck_ui_base.png"
BATTLE_BASE = OUT / "current_game_1930s_v10_h_battle_ui_base.png"
MAIN_FINAL = OUT / "current_game_1930s_v14_l_uiux_pro_max_reviewed_lobby_mockup.png"
PREFIX = "current_game_1930s_v14_l_uiux_pro_max_reviewed"
W, H = 720, 1280

INK = (48, 30, 22, 255)
LIGHT = (255, 250, 222, 255)
RED = (172, 55, 45, 255)
BLUE = (38, 112, 139, 255)
GOLD = (202, 128, 31, 255)
GREEN = (42, 115, 74, 255)
WHITE = (255, 255, 245, 255)
PAPER_MUTED = (242, 219, 166, 255)
DISABLED_WASH = (218, 203, 166, 28)

TOP_VALUE_RECTS = ((103, 30, 222, 70), (554, 30, 678, 70))
NAV_LABELS = [
  ((20, 1200, 128, 1237), "商店"),
  ((166, 1200, 274, 1237), "编组"),
  ((310, 1200, 418, 1237), "战斗"),
  ((456, 1200, 564, 1237), "抽卡"),
  ((592, 1200, 700, 1237), "更多"),
]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
  candidates = [
    Path("C:/Windows/Fonts/msyhbd.ttc" if bold else "C:/Windows/Fonts/simkai.ttf"),
    Path("C:/Windows/Fonts/simhei.ttf"),
    Path("C:/Windows/Fonts/msyh.ttc"),
    Path("C:/Windows/Fonts/STXINGKA.TTF"),
  ]
  for path in candidates:
    if path.exists():
      return ImageFont.truetype(str(path), size=size)
  return ImageFont.load_default()


def fit_font(
  draw: ImageDraw.ImageDraw,
  value: str,
  max_width: int,
  size: int,
  bold: bool,
  minimum: int = 12,
) -> ImageFont.FreeTypeFont:
  current = size
  while current > minimum:
    fnt = font(current, bold)
    box = draw.textbbox((0, 0), value, font=fnt)
    if box[2] - box[0] <= max_width:
      return fnt
    current -= 1
  return font(minimum, bold)


def center_text(
  draw: ImageDraw.ImageDraw,
  value: str,
  rect: tuple[int, int, int, int],
  fill: tuple[int, int, int, int] = INK,
  size: int = 24,
  bold: bool = False,
  stroke_width: int = 0,
  stroke_fill: tuple[int, int, int, int] = LIGHT,
) -> None:
  fnt = fit_font(draw, value, rect[2] - rect[0] - 8, size, bold)
  box = draw.textbbox((0, 0), value, font=fnt, stroke_width=stroke_width)
  x = (rect[0] + rect[2]) / 2 - (box[0] + box[2]) / 2
  y = (rect[1] + rect[3]) / 2 - (box[1] + box[3]) / 2
  draw.text((x, y), value, font=fnt, fill=fill, stroke_width=stroke_width, stroke_fill=stroke_fill)


def left_text(
  draw: ImageDraw.ImageDraw,
  value: str,
  rect: tuple[int, int, int, int],
  fill: tuple[int, int, int, int] = INK,
  size: int = 20,
  bold: bool = False,
  stroke_width: int = 0,
  stroke_fill: tuple[int, int, int, int] = LIGHT,
) -> None:
  fnt = fit_font(draw, value, rect[2] - rect[0] - 8, size, bold)
  box = draw.textbbox((0, 0), value, font=fnt, stroke_width=stroke_width)
  y = (rect[1] + rect[3]) / 2 - (box[1] + box[3]) / 2
  draw.text((rect[0] + 4, y), value, font=fnt, fill=fill, stroke_width=stroke_width, stroke_fill=stroke_fill)


def cover_resize(image: Image.Image, size: tuple[int, int] = (W, H)) -> Image.Image:
  image = image.convert("RGBA")
  src_ratio = image.width / image.height
  dst_ratio = size[0] / size[1]
  if src_ratio > dst_ratio:
    new_w = round(image.height * dst_ratio)
    left = (image.width - new_w) // 2
    image = image.crop((left, 0, left + new_w, image.height))
  else:
    new_h = round(image.width / dst_ratio)
    top = (image.height - new_h) // 2
    image = image.crop((0, top, image.width, top + new_h))
  return image.resize(size, Image.Resampling.LANCZOS)


def load_base(path: Path) -> Image.Image:
  return cover_resize(Image.open(path))


def component(source: Image.Image, rect: tuple[int, int, int, int], size: tuple[int, int]) -> Image.Image:
  return source.crop(rect).resize(size, Image.Resampling.LANCZOS)


def animal(name: str, max_size: tuple[int, int]) -> Image.Image:
  image = Image.open(ROOT / "assets" / "card_art" / "animals" / f"{name}.png").convert("RGBA")
  box = image.getbbox()
  if box:
    image = image.crop(box)
  image.thumbnail(max_size, Image.Resampling.LANCZOS)
  return image


def paste_center(base: Image.Image, image: Image.Image, center: tuple[int, int]) -> None:
  base.alpha_composite(image, (round(center[0] - image.width / 2), round(center[1] - image.height / 2)))


def paste_animal(base: Image.Image, name: str, center: tuple[int, int], max_size: tuple[int, int]) -> None:
  img = animal(name, max_size)
  shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
  sd = ImageDraw.Draw(shadow)
  shadow_y = center[1] + img.height // 2 - 5
  sd.ellipse((center[0] - img.width * 0.32, shadow_y - 4, center[0] + img.width * 0.32, shadow_y + 5), fill=(0, 0, 0, 48))
  base.alpha_composite(shadow)
  paste_center(base, img, center)


def add_top_values(draw: ImageDraw.ImageDraw, left: str = "60", right: str = "10") -> None:
  center_text(draw, left, TOP_VALUE_RECTS[0], INK, 22, True)
  center_text(draw, right, TOP_VALUE_RECTS[1], INK, 21, True)


def add_bottom_nav(draw: ImageDraw.ImageDraw, active: str) -> None:
  for rect, label in NAV_LABELS:
    center_text(draw, label, rect, RED if label == active else INK, 20, True, 1, LIGHT)
  active_index = [label for _, label in NAV_LABELS].index(active)
  active_rect = NAV_LABELS[active_index][0]
  draw.line((active_rect[0] + 24, 1240, active_rect[2] - 24, 1240), fill=INK, width=5)
  draw.line((active_rect[0] + 26, 1239, active_rect[2] - 26, 1239), fill=GOLD, width=2)
  center_x = 72 + active_index * 144
  draw.ellipse((center_x - 16, 1245, center_x + 16, 1275), fill=(236, 183, 50, 255), outline=INK, width=3)
  draw.ellipse((center_x - 8, 1253, center_x + 8, 1269), fill=(255, 235, 120, 255))


def paste_status_strip(base: Image.Image, rect: tuple[int, int, int, int]) -> None:
  source = load_base(MAIN_BASE)
  width = rect[2] - rect[0]
  height = rect[3] - rect[1]
  strip = nine_slice(source, (92, 868, 628, 928), (width, height), (58, 15, 58, 15))
  base.alpha_composite(strip, (rect[0], rect[1]))


def add_status_header(base: Image.Image, left: str, right: str) -> None:
  for rect in ((92, 279, 304, 317), (416, 279, 628, 317)):
    paste_status_strip(base, rect)
  draw = ImageDraw.Draw(base)
  center_text(draw, left, (100, 283, 296, 313), INK, 19, True, 1, LIGHT)
  center_text(draw, right, (424, 283, 620, 313), INK, 19, True, 1, LIGHT)


def add_section_label(base: Image.Image, label: str) -> None:
  rect = (92, 756, 286, 792)
  paste_status_strip(base, rect)
  center_text(ImageDraw.Draw(base), label, (100, 760, 278, 789), INK, 18, True, 1, LIGHT)


def paste_masked_component(
  base: Image.Image,
  source: Image.Image,
  src_rect: tuple[int, int, int, int],
  dst_rect: tuple[int, int, int, int],
  kind: str = "rounded",
) -> None:
  width = dst_rect[2] - dst_rect[0]
  height = dst_rect[3] - dst_rect[1]
  item = component(source, src_rect, (width, height))
  mask = Image.new("L", (width, height), 0)
  md = ImageDraw.Draw(mask)
  if kind == "ellipse":
    md.ellipse((2, 2, width - 3, height - 3), fill=255)
  elif kind == "banner":
    md.polygon([(42, 12), (width - 42, 12), (width - 5, 62), (width - 30, height - 20), (30, height - 20), (5, 62)], fill=255)
  else:
    md.rounded_rectangle((2, 2, width - 3, height - 3), radius=min(22, height // 3), fill=255)
  mask = mask.filter(ImageFilter.GaussianBlur(0.65))
  base.paste(item, (dst_rect[0], dst_rect[1]), mask)


def paste_button(
  base: Image.Image,
  rect: tuple[int, int, int, int],
  label: str,
  size: int = 24,
  variant: str = "primary",
) -> None:
  source = load_base(MAIN_BASE)
  width = rect[2] - rect[0]
  height = rect[3] - rect[1]
  item = component(source, (176, 938, 550, 1076), (width, height)).convert("RGBA")
  alpha = item.getchannel("A")
  if variant == "secondary":
    item = ImageEnhance.Color(item).enhance(0.66)
    item = Image.blend(item, Image.new("RGBA", item.size, (185, 214, 205, 255)), 0.28)
  elif variant == "disabled":
    item = ImageEnhance.Color(item).enhance(0.18)
    item = ImageEnhance.Brightness(item).enhance(0.78)
  else:
    item = ImageEnhance.Contrast(item).enhance(1.04)
  item.putalpha(alpha)
  mask = Image.new("L", (width, height), 0)
  ImageDraw.Draw(mask).ellipse((2, 2, width - 3, height - 3), fill=255)
  base.paste(item, (rect[0], rect[1]), mask.filter(ImageFilter.GaussianBlur(0.65)))
  fill = INK if variant != "disabled" else (74, 65, 55, 255)
  center_text(ImageDraw.Draw(base), label, rect, fill, size, True, 1, LIGHT)


def apply_disabled_wash(base: Image.Image, rect: tuple[int, int, int, int]) -> None:
  crop = base.crop(rect).convert("RGBA")
  crop = ImageEnhance.Color(crop).enhance(0.38)
  crop = ImageEnhance.Brightness(crop).enhance(0.9)
  crop = Image.alpha_composite(crop, Image.new("RGBA", crop.size, DISABLED_WASH))
  mask = Image.new("L", crop.size, 0)
  ImageDraw.Draw(mask).rounded_rectangle((0, 0, crop.width - 1, crop.height - 1), radius=16, fill=255)
  base.paste(crop, (rect[0], rect[1]), mask.filter(ImageFilter.GaussianBlur(3.0)))


def paste_ticket(base: Image.Image, rect: tuple[int, int, int, int]) -> None:
  source = load_base(MAIN_BASE)
  paste_masked_component(base, source, (91, 869, 630, 932), rect, "rounded")


def masked_icon(
  source: Image.Image,
  src_rect: tuple[int, int, int, int],
  size: tuple[int, int],
  shape: str = "ellipse",
) -> Image.Image:
  icon = component(source, src_rect, size)
  mask = Image.new("L", size, 0)
  draw = ImageDraw.Draw(mask)
  if shape == "rounded":
    draw.rounded_rectangle((0, 0, size[0] - 1, size[1] - 1), radius=max(3, min(size) // 5), fill=255)
  else:
    draw.ellipse((0, 0, size[0] - 1, size[1] - 1), fill=255)
  icon.putalpha(mask.filter(ImageFilter.GaussianBlur(0.35)))
  return icon


def refresh_icon(size: tuple[int, int]) -> Image.Image:
  icon = Image.new("RGBA", (96, 72), (0, 0, 0, 0))
  draw = ImageDraw.Draw(icon)
  for width, color in ((13, INK), (7, (53, 125, 77, 255))):
    draw.arc((10, 7, 86, 65), 198, 350, fill=color, width=width)
  for width, color in ((13, INK), (7, (224, 165, 54, 255))):
    draw.arc((10, 7, 86, 65), 18, 170, fill=color, width=width)
  draw.polygon([(79, 10), (93, 18), (78, 28)], fill=INK)
  draw.polygon([(79, 14), (88, 19), (79, 24)], fill=(53, 125, 77, 255))
  draw.polygon([(17, 62), (3, 54), (18, 44)], fill=INK)
  draw.polygon([(17, 58), (8, 53), (17, 48)], fill=(224, 165, 54, 255))
  return icon.resize(size, Image.Resampling.LANCZOS)


def paste_shop_art(base: Image.Image, kind: str, center: tuple[int, int], scale: float = 1.0) -> None:
  main = load_base(MAIN_BASE)
  deck = load_base(DECK_BASE)
  coin = masked_icon(main, (44, 31, 94, 79), (round(32 * scale), round(32 * scale)))
  ticket = masked_icon(main, (499, 28, 551, 78), (round(34 * scale), round(30 * scale)), "rounded")

  if kind in {"coins", "coin_box"}:
    for dx, dy in ((-18, 9), (17, 9), (0, -12)):
      paste_center(base, coin, (center[0] + round(dx * scale), center[1] + round(dy * scale)))
    return
  if kind in {"tickets", "ticket_box"}:
    for dx, dy in ((-15, 8), (14, 8), (0, -12)):
      paste_center(base, ticket, (center[0] + round(dx * scale), center[1] + round(dy * scale)))
    return
  if kind == "starter":
    cards = masked_icon(main, (176, 1110, 282, 1196), (round(72 * scale), round(58 * scale)), "rounded")
    paste_center(base, cards, (center[0] - round(8 * scale), center[1]))
    paste_center(base, coin, (center[0] + round(27 * scale), center[1] + round(18 * scale)))
    return
  if kind in {"shards", "shard_box"}:
    crops = [(142, 322, 178, 358), (342, 322, 378, 358), (542, 322, 578, 358)]
    for (crop, dx, dy) in zip(crops, (-20, 0, 20), (9, -9, 9), strict=True):
      gem = masked_icon(deck, crop, (round(30 * scale), round(30 * scale)))
      paste_center(base, gem, (center[0] + round(dx * scale), center[1] + round(dy * scale)))
    return
  if kind in {"rare", "rare_box"}:
    crest = masked_icon(deck, (330, 263, 390, 323), (round(58 * scale), round(58 * scale)))
    paste_center(base, ticket, (center[0] - round(18 * scale), center[1] + round(10 * scale)))
    paste_center(base, crest, (center[0] + round(10 * scale), center[1] - round(4 * scale)))
    return
  if kind == "refresh":
    icon = refresh_icon((round(70 * scale), round(54 * scale)))
    paste_center(base, icon, center)


def paste_button_zone(base: Image.Image, rect: tuple[int, int, int, int]) -> None:
  source = load_base(MAIN_BASE)
  width = rect[2] - rect[0]
  height = rect[3] - rect[1]
  item = component(source, (91, 869, 630, 932), (width, height)).convert("RGB")
  item = ImageEnhance.Color(item).enhance(0.68)
  item = Image.blend(item, Image.new("RGB", item.size, (236, 210, 148)), 0.10).convert("RGBA")
  mask = Image.new("L", item.size, 0)
  ImageDraw.Draw(mask).rounded_rectangle((2, 2, width - 3, height - 3), radius=min(20, height // 3), fill=255)
  base.paste(item, (rect[0], rect[1]), mask.filter(ImageFilter.GaussianBlur(0.6)))


def clear_lower_action_area(base: Image.Image) -> None:
  source = load_base(MAIN_BASE)
  patch = paper_patch(source, (556, 174), (235, 211, 157), 811)
  mask = Image.new("L", patch.size, 0)
  ImageDraw.Draw(mask).rounded_rectangle((0, 0, 555, 173), radius=18, fill=255)
  base.paste(patch, (82, 944), mask.filter(ImageFilter.GaussianBlur(0.7)))
  ImageDraw.Draw(base).rounded_rectangle((82, 944, 638, 1118), radius=18, outline=(46, 91, 66, 255), width=4)


def build_lobby() -> Path:
  if not MAIN_FINAL.exists():
    raise FileNotFoundError(f"Run build_1930s_ai_painted_main_page_mockup.py first: {MAIN_FINAL}")
  return MAIN_FINAL


def build_deck() -> Path:
  base = load_base(DECK_BASE)
  draw = ImageDraw.Draw(base)
  add_top_values(draw)
  center_text(draw, "编组", (154, 116, 566, 204), INK, 45, False, 1, LIGHT)
  add_status_header(base, "出战 6/6", "战力 1280")

  slots = [
    ("mouse", 160, 394, "Lv.1 老鼠", "近战"),
    ("frog", 360, 394, "Lv.1 青蛙", "远程"),
    ("rabbit", 560, 394, "Lv.1 兔子", "速攻"),
    ("chicken", 160, 611, "Lv.1 鸡", "召唤"),
    ("cat", 360, 611, "Lv.1 猫", "突袭"),
    ("dog", 560, 611, "Lv.1 狗", "守护"),
  ]
  for name, x, y, title, role in slots:
    paste_animal(base, name, (x, y), (96, 96))
    center_text(draw, title, (x - 76, y + 48, x + 76, y + 76), INK, 16, True, 1, LIGHT)
    center_text(draw, role, (x - 62, y + 80, x + 62, y + 108), INK, 16, True, 1, LIGHT)

  add_section_label(base, "所有卡牌")
  collection = [
    ("bear", "熊"), ("fox", "狐"), ("wolf", "狼"), ("deer", "鹿"), ("duck", "鸭"),
    ("tiger", "虎"), ("eagle", "鹰"), ("cow", "牛"), ("sheep", "羊"), ("pig", "猪"),
  ]
  x_positions = [116, 238, 360, 482, 604]
  for index, (name, title) in enumerate(collection):
    row = index // 5
    x = x_positions[index % 5]
    y = 858 + row * 158
    draw.ellipse((x - 31, y - 31, x + 31, y + 31), fill=(255, 244, 203, 210), outline=(210, 155, 50, 255), width=2)
    paste_animal(base, name, (x, y), (58, 58))
    center_text(draw, title, (x - 42, y + 54, x + 42, y + 79), INK, 16, True, 1, LIGHT)
  add_bottom_nav(draw, "编组")
  path = OUT / f"{PREFIX}_deck_page_mockup.png"
  base.convert("RGB").save(path, quality=96)
  return path


def paper_patch(source: Image.Image, size: tuple[int, int], tint: tuple[int, int, int], seed: int) -> Image.Image:
  sample = source.crop((250, 205, 470, 260)).convert("RGB")
  rng = random.Random(seed)
  left = rng.randint(0, max(0, sample.width - 120))
  crop = sample.crop((left, 0, min(sample.width, left + 150), sample.height))
  patch = ImageOps.fit(crop, size, method=Image.Resampling.LANCZOS)
  patch = Image.blend(patch, Image.new("RGB", size, tint), 0.54)
  patch = ImageEnhance.Brightness(patch).enhance(0.95 + rng.random() * 0.09)
  return patch.convert("RGBA")


def hex_points(center: tuple[float, float], radius: float) -> list[tuple[float, float]]:
  return [
    (
      center[0] + math.cos(math.radians(60 * index - 30)) * radius,
      center[1] + math.sin(math.radians(60 * index - 30)) * radius,
    )
    for index in range(6)
  ]


def board_origin(cols: int, rows: int, radius: float) -> tuple[float, float]:
  width = math.sqrt(3) * radius
  points: list[tuple[float, float]] = []
  for row in range(rows):
    for col in range(cols):
      center = (width * (col + 0.5 * (row % 2)), radius * 1.5 * row)
      points.extend(hex_points(center, radius))
  min_x = min(point[0] for point in points)
  max_x = max(point[0] for point in points)
  min_y = min(point[1] for point in points)
  max_y = max(point[1] for point in points)
  return 360 - (min_x + max_x) / 2, 601 - (min_y + max_y) / 2


def paste_polygon_texture(
  base: Image.Image,
  polygon: list[tuple[float, float]],
  texture: Image.Image,
) -> None:
  min_x = math.floor(min(point[0] for point in polygon))
  min_y = math.floor(min(point[1] for point in polygon))
  max_x = math.ceil(max(point[0] for point in polygon))
  max_y = math.ceil(max(point[1] for point in polygon))
  mask = Image.new("L", (max_x - min_x + 1, max_y - min_y + 1), 0)
  local = [(point[0] - min_x, point[1] - min_y) for point in polygon]
  ImageDraw.Draw(mask).polygon(local, fill=255)
  texture = ImageOps.fit(texture, mask.size, method=Image.Resampling.LANCZOS)
  base.paste(texture, (min_x, min_y), mask)


def paste_battle_resource(base: Image.Image, center: tuple[int, int], value: str) -> None:
  source = load_base(MAIN_BASE)
  icon = masked_icon(source, (44, 31, 94, 79), (34, 34))
  paste_center(base, icon, (center[0], center[1] - 7))
  center_text(ImageDraw.Draw(base), value, (center[0] - 28, center[1] + 10, center[0] + 28, center[1] + 36), LIGHT, 18, True, 2, INK)


def paste_battle_unit(base: Image.Image, name: str, center: tuple[int, int], team: str) -> None:
  draw = ImageDraw.Draw(base)
  team_color = (187, 70, 51, 225) if team == "enemy" else (62, 132, 73, 225)
  draw.ellipse((center[0] - 31, center[1] - 27, center[0] + 31, center[1] + 35), fill=team_color, outline=INK, width=3)
  draw.ellipse((center[0] - 25, center[1] - 21, center[0] + 25, center[1] + 29), fill=(255, 244, 205, 210), outline=(230, 178, 68, 255), width=2)
  paste_animal(base, name, center, (60, 60))


def draw_exact_battle_grid(base: Image.Image) -> dict[tuple[int, int], tuple[int, int]]:
  draw = ImageDraw.Draw(base)
  main_source = load_base(MAIN_BASE)
  radius = 43.0
  cols, rows = 7, 13
  origin = board_origin(cols, rows, radius)
  centers: dict[tuple[int, int], tuple[int, int]] = {}

  field = paper_patch(main_source, (592, 982), (143, 118, 73), 99)
  field_mask = Image.new("L", field.size, 0)
  ImageDraw.Draw(field_mask).rounded_rectangle((0, 0, 591, 981), radius=18, fill=255)
  base.paste(field, (64, 110), field_mask.filter(ImageFilter.GaussianBlur(0.8)))
  inner_shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
  shadow_draw = ImageDraw.Draw(inner_shadow)
  for inset, alpha in ((1, 74), (5, 48), (10, 28)):
    shadow_draw.rounded_rectangle(
      (64 + inset, 110 + inset, 656 - inset, 1092 - inset),
      radius=18,
      outline=(62, 34, 22, alpha),
      width=4,
    )
  base.alpha_composite(inner_shadow.filter(ImageFilter.GaussianBlur(4.0)))

  for row in range(rows):
    for col in range(cols):
      center = (
        origin[0] + math.sqrt(3) * radius * (col + 0.5 * (row % 2)),
        origin[1] + radius * 1.5 * row,
      )
      centers[(col, row)] = (round(center[0]), round(center[1]))
      points = hex_points(center, radius)
      tint = (157, 68, 52) if row < 6 else (70, 111, 67)
      texture = paper_patch(main_source, (84, 84), tint, row * 31 + col * 7)
      paste_polygon_texture(base, points, texture)

      rng = random.Random(row * 113 + col * 17)
      wobble = [
        (point[0] + rng.uniform(-0.7, 0.7), point[1] + rng.uniform(-0.7, 0.7))
        for point in points
      ]
      wobble.append(wobble[0])
      draw.line(wobble, fill=INK, width=4, joint="curve")
      draw.line(wobble, fill=(230, 181, 89, 255), width=1, joint="curve")

  for col in (0, 2, 4, 6):
    center = centers[(col, 5)]
    paste_battle_resource(base, center, "25")

  for col in (1, 3, 5):
    center = centers[(col, 7)]
    center_text(draw, "?", (center[0] - 18, center[1] - 25, center[0] + 18, center[1] + 25), LIGHT, 24, True, 2, INK)
  return centers


def paste_battle_frame(base: Image.Image) -> None:
  source = load_base(BATTLE_BASE)
  layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
  draw = ImageDraw.Draw(layer)
  draw.rounded_rectangle((36, 82, 684, 1120), radius=28, outline=INK, width=8)
  layer.alpha_composite(component(source, (74, 282, 646, 360), (648, 92)), (36, 82))
  layer.alpha_composite(component(source, (18, 350, 105, 845), (70, 886)), (36, 158))
  layer.alpha_composite(component(source, (608, 350, 702, 845), (70, 886)), (614, 158))
  layer.alpha_composite(component(source, (68, 845, 652, 920), (648, 90)), (36, 1030))
  alpha = layer.getchannel("A")
  ImageDraw.Draw(alpha).rectangle((64, 110, 655, 1091), fill=0)
  layer.putalpha(alpha)
  base.alpha_composite(layer)


def paste_battle_castles(base: Image.Image, centers: dict[tuple[int, int], tuple[int, int]]) -> None:
  source = load_base(BATTLE_BASE)
  enemy = component(source, (105, 350, 195, 455), (72, 84))
  player = component(source, (105, 675, 195, 790), (72, 84))
  for item, key in ((enemy, (3, 1)), (player, (3, 11))):
    center = centers[key]
    mask = Image.new("L", item.size, 0)
    ImageDraw.Draw(mask).ellipse((0, 0, item.width - 1, item.height - 1), fill=255)
    base.paste(item, (center[0] - item.width // 2, center[1] - item.height // 2), mask.filter(ImageFilter.GaussianBlur(1)))


def build_battle() -> Path:
  base = load_base(BATTLE_BASE)
  main_source = load_base(MAIN_BASE)
  base.paste(main_source.crop((0, 0, 720, 140)), (0, 0))

  centers = draw_exact_battle_grid(base)
  paste_battle_castles(base, centers)
  for name, key in (("mouse", (1, 3)), ("frog", (4, 4))):
    paste_battle_unit(base, name, centers[key], "enemy")
  for name, key in (("rabbit", (1, 9)), ("cat", (3, 10)), ("dog", (5, 9))):
    paste_battle_unit(base, name, centers[key], "player")
  paste_battle_frame(base)

  source = load_base(BATTLE_BASE)
  paste_masked_component(base, source, (198, 140, 552, 226), (250, 12, 470, 68), "rounded")
  pause = component(source, (626, 139, 710, 222), (64, 64))
  base.alpha_composite(pause, (608, 76))

  paste_ticket(base, (26, 1132, 694, 1250))
  draw = ImageDraw.Draw(base)
  add_top_values(draw)
  center_text(draw, "青铜 1 星  VS  青铜 1 星", (258, 19, 462, 61), INK, 16, True, 1, LIGHT)
  center_text(draw, "可解锁：动物营地", (62, 1143, 658, 1183), INK, 23, True, 1, LIGHT)
  center_text(draw, "花费 50  ·  普通动物，品质在解锁时随机", (62, 1187, 658, 1228), INK, 18, True, 1, LIGHT)
  path = OUT / f"{PREFIX}_battle_page_mockup.png"
  base.convert("RGB").save(path, quality=96)
  return path


def build_gacha() -> Path:
  base = load_base(DECK_BASE)
  draw = ImageDraw.Draw(base)
  add_top_values(draw)
  center_text(draw, "抽卡", (154, 112, 566, 183), INK, 43, False, 1, LIGHT)
  center_text(draw, "今日招募", (180, 178, 540, 207), INK, 19, True, 1, LIGHT)
  candidates = [
    ("mouse", "老鼠", "概率提升", (160, 405)),
    ("frog", "青蛙", "已拥有", (360, 405)),
    ("rabbit", "兔子", "概率提升", (560, 405)),
    ("chicken", "鸡", "已拥有", (160, 620)),
    ("cat", "猫", "首次获得", (360, 620)),
    ("dog", "狗", "已拥有", (560, 620)),
  ]
  for name, title, state, center in candidates:
    draw.ellipse((center[0] - 47, center[1] - 56, center[0] + 47, center[1] + 38), fill=(255, 244, 203, 205), outline=(215, 158, 53, 255), width=2)
    paste_animal(base, name, (center[0], center[1] - 9), (88, 88))
    center_text(draw, title, (center[0] - 70, center[1] + 38, center[0] + 70, center[1] + 64), INK, 18, True, 1, LIGHT)
    center_text(draw, state, (center[0] - 64, center[1] + 71, center[0] + 64, center[1] + 99), INK, 16, True, 1, LIGHT)
  add_section_label(base, "最近获得")
  recent = [("rabbit", "兔"), ("frog", "蛙"), ("cat", "猫"), ("dog", "狗"), ("mouse", "鼠")]
  for (name, title), x in zip(recent, [116, 238, 360, 482, 604], strict=True):
    paste_animal(base, name, (x, 858), (60, 60))
    center_text(draw, title, (x - 42, 913, x + 42, 940), INK, 16, True, 1, LIGHT)
  clear_lower_action_area(base)
  paste_button_zone(base, (92, 984, 628, 1112))
  draw = ImageDraw.Draw(base)
  draw.rounded_rectangle((298, 950, 422, 978), radius=12, fill=(31, 76, 59, 235), outline=(220, 165, 58, 255), width=2)
  for index in range(5):
    x = 320 + index * 20
    draw.ellipse((x - 5, 959, x + 5, 969), fill=(238, 184, 52, 255) if index == 0 else (96, 116, 88, 255), outline=INK, width=1)
  paste_button(base, (118, 1001, 326, 1075), "抽 1 次", 23, "secondary")
  paste_button(base, (394, 1001, 602, 1075), "抽 10 次", 23, "primary")
  add_bottom_nav(draw, "抽卡")
  path = OUT / f"{PREFIX}_gacha_page_mockup.png"
  base.convert("RGB").save(path, quality=96)
  return path


def centered_icon_value(
  base: Image.Image,
  rect: tuple[int, int, int, int],
  value: str,
  icon_kind: str = "coin",
  font_size: int = 20,
  icon_size: int = 22,
) -> None:
  draw = ImageDraw.Draw(base)
  if value == "免费":
    center_text(draw, value, rect, GOLD, font_size, True, 1, LIGHT)
    return
  source = load_base(MAIN_BASE)
  crop = (44, 31, 94, 79) if icon_kind == "coin" else (499, 28, 551, 78)
  icon = component(source, crop, (icon_size, icon_size))
  icon_mask = Image.new("L", icon.size, 0)
  ImageDraw.Draw(icon_mask).ellipse((0, 0, icon.width - 1, icon.height - 1), fill=255)
  icon.putalpha(icon_mask.filter(ImageFilter.GaussianBlur(0.35)))
  fnt = fit_font(draw, value, rect[2] - rect[0] - icon_size - 10, font_size, True)
  box = draw.textbbox((0, 0), value, font=fnt)
  text_width = box[2] - box[0]
  total = icon_size + 6 + text_width
  x = (rect[0] + rect[2] - total) // 2
  y = (rect[1] + rect[3] - icon_size) // 2
  base.alpha_composite(icon, (x, y))
  center_text(draw, value, (x + icon_size + 6, rect[1], x + icon_size + 6 + text_width, rect[3]), GOLD, font_size, True, 1, LIGHT)


def build_shop() -> Path:
  base = load_base(DECK_BASE)
  draw = ImageDraw.Draw(base)
  add_top_values(draw)
  center_text(draw, "商店", (154, 112, 566, 183), INK, 43, False, 1, LIGHT)
  center_text(draw, "今日推荐", (180, 178, 540, 207), INK, 19, True, 1, LIGHT)
  items = [
    ("每日补给", "免费", "coins", (160, 405), False),
    ("招募券包", "120", "tickets", (360, 405), False),
    ("新手补给", "300", "starter", (560, 405), False),
    ("动物碎片", "80", "shards", (160, 620), False),
    ("稀有礼包", "680", "rare", (360, 620), False),
    ("刷新商店", "余额不足", "refresh", (560, 620), True),
  ]
  for title, price, kind, center, unavailable in items:
    paste_shop_art(base, kind, (center[0], center[1] - 24), 1.0)
    price_rect = (center[0] - 70, center[1] + 65, center[0] + 70, center[1] + 98)
    if unavailable:
      apply_disabled_wash(base, (center[0] - 60, center[1] - 78, center[0] + 60, center[1] + 45))
      draw = ImageDraw.Draw(base)
      center_text(draw, title, (center[0] - 76, center[1] + 23, center[0] + 76, center[1] + 52), INK, 18, True, 1, LIGHT)
      center_text(draw, price, price_rect, RED, 17, True, 1, LIGHT)
    else:
      center_text(draw, title, (center[0] - 76, center[1] + 23, center[0] + 76, center[1] + 52), INK, 18, True, 1, LIGHT)
      centered_icon_value(base, price_rect, price, font_size=19, icon_size=20)
  add_section_label(base, "限时礼包")
  offers = [
    ("金币箱", "300", "coin_box"),
    ("券箱", "5", "ticket_box"),
    ("碎片包", "180", "shard_box"),
    ("稀有箱", "680", "rare_box"),
    ("刷新券", "20", "refresh"),
  ]
  for (title, price, kind), x in zip(offers, [116, 238, 360, 482, 604], strict=True):
    paste_shop_art(base, kind, (x, 853), 0.62)
    center_text(draw, title, (x - 49, 879, x + 49, 906), INK, 16, True, 1, LIGHT)
    centered_icon_value(base, (x - 50, 912, x + 50, 941), price, font_size=16, icon_size=17)
  clear_lower_action_area(base)
  paste_button_zone(base, (92, 984, 628, 1112))
  draw = ImageDraw.Draw(base)
  center_text(draw, "每日 00:00 自动刷新", (120, 989, 600, 1018), INK, 18, True, 1, LIGHT)
  paste_button(base, (260, 1027, 460, 1089), "刷新 20", 21)
  add_bottom_nav(draw, "商店")
  path = OUT / f"{PREFIX}_shop_page_mockup.png"
  base.convert("RGB").save(path, quality=96)
  return path


def build_more() -> Path:
  base = load_base(MAIN_BASE)
  draw = ImageDraw.Draw(base)
  add_top_values(draw)
  center_text(draw, "任务", (138, 184, 582, 270), INK, 50, False, 1, LIGHT)
  tasks = [
    ("每日登录", "20 金币", "已完成"),
    ("赢得 1 场战斗", "1 招募券", "0/1"),
    ("升级 1 张卡牌", "50 金币", "0/1"),
    ("解锁 3 个地块", "30 金币", "1/3"),
  ]
  for index, (title, reward, state) in enumerate(tasks):
    y = 360 + index * 108
    paste_ticket(base, (104, y, 616, y + 82))
    left_text(draw, title, (152, y + 8, 438, y + 40), INK, 20, True, 1, LIGHT)
    left_text(draw, reward, (152, y + 42, 438, y + 72), GOLD, 18, True, 1, LIGHT)
    center_text(draw, state, (488, y + 15, 592, y + 66), GREEN if state == "已完成" else INK, 20, True, 1, LIGHT)
  paste_button(base, (88, 846, 254, 908), "设置", 19, "secondary")
  paste_button(base, (277, 846, 443, 908), "公告", 19, "secondary")
  paste_button(base, (466, 846, 632, 908), "邮件", 19, "secondary")
  paste_button(base, (190, 963, 530, 1044), "领取全部", 28, "primary")
  add_bottom_nav(draw, "更多")
  path = OUT / f"{PREFIX}_more_tasks_page_mockup.png"
  base.convert("RGB").save(path, quality=96)
  return path


def nine_slice(
  source: Image.Image,
  src_rect: tuple[int, int, int, int],
  size: tuple[int, int],
  margins: tuple[int, int, int, int],
) -> Image.Image:
  src = source.crop(src_rect).convert("RGBA")
  left, top, right, bottom = margins
  src_x = (0, left, src.width - right, src.width)
  src_y = (0, top, src.height - bottom, src.height)
  dst_x = (0, left, size[0] - right, size[0])
  dst_y = (0, top, size[1] - bottom, size[1])
  result = Image.new("RGBA", size, (0, 0, 0, 0))
  for row in range(3):
    for col in range(3):
      piece = src.crop((src_x[col], src_y[row], src_x[col + 1], src_y[row + 1]))
      target = (dst_x[col + 1] - dst_x[col], dst_y[row + 1] - dst_y[row])
      if piece.size != target:
        piece = piece.resize(target, Image.Resampling.LANCZOS)
      result.alpha_composite(piece, (dst_x[col], dst_y[row]))
  return result


def paste_popup_panel(base: Image.Image, rect: tuple[int, int, int, int]) -> None:
  source = load_base(DECK_BASE)
  width = rect[2] - rect[0]
  height = rect[3] - rect[1]
  panel = nine_slice(source, (104, 326, 276, 516), (width, height), (36, 42, 36, 48))
  mask = Image.new("L", (width, height), 0)
  ImageDraw.Draw(mask).polygon(
    [(28, 0), (width - 28, 0), (width, 30), (width, height - 34), (width - 34, height), (34, height), (0, height - 34), (0, 30)],
    fill=255,
  )
  base.paste(panel, (rect[0], rect[1]), mask.filter(ImageFilter.GaussianBlur(0.55)))


def popup_background() -> Image.Image:
  base = load_base(MAIN_FINAL)
  base = base.filter(ImageFilter.GaussianBlur(1.2))
  base.alpha_composite(Image.new("RGBA", base.size, (20, 12, 8, 150)))
  return base


def build_card_detail_popup() -> Path:
  base = popup_background()
  panel = (90, 370, 630, 780)
  paste_popup_panel(base, panel)
  draw = ImageDraw.Draw(base)
  center_text(draw, "卡牌详情", (135, 394, 585, 448), INK, 34, True, 1, LIGHT)
  draw.ellipse((142, 468, 278, 604), fill=(255, 244, 203, 215), outline=(216, 159, 52, 255), width=3)
  paste_animal(base, "frog", (210, 535), (120, 120))
  left_text(draw, "青蛙  Lv.1", (310, 465, 570, 502), INK, 23, True, 1, LIGHT)
  left_text(draw, "攻击 12", (310, 510, 470, 544), INK, 20, True, 1, LIGHT)
  left_text(draw, "生命 90", (310, 550, 470, 584), INK, 20, True, 1, LIGHT)
  left_text(draw, "碎片 3/10", (310, 590, 500, 624), GOLD, 20, True, 1, LIGHT)
  center_text(draw, "普通 · 远程", (162, 632, 558, 665), INK, 19, True, 1, LIGHT)
  paste_button(base, (244, 690, 476, 758), "升级 50", 23, "primary")
  path = OUT / f"{PREFIX}_popup_card_detail_mockup.png"
  base.convert("RGB").save(path, quality=96)
  return path


def build_victory_popup() -> Path:
  base = popup_background()
  panel = (90, 370, 630, 780)
  paste_popup_panel(base, panel)
  draw = ImageDraw.Draw(base)
  center_text(draw, "战斗胜利", (135, 394, 585, 448), INK, 36, True, 1, LIGHT)
  center_text(draw, "+1 招募券", (150, 494, 570, 548), GOLD, 27, True, 1, LIGHT)
  center_text(draw, "当前段位  青铜 2 星", (150, 562, 570, 606), INK, 21, True, 1, LIGHT)
  center_text(draw, "胜 1  ·  负 0", (190, 614, 530, 652), INK, 19, True, 1, LIGHT)
  paste_button(base, (232, 690, 488, 758), "返回主页面", 22, "primary")
  path = OUT / f"{PREFIX}_popup_battle_victory_mockup.png"
  base.convert("RGB").save(path, quality=96)
  return path


def build_purchase_popup() -> Path:
  base = popup_background()
  panel = (90, 370, 630, 780)
  paste_popup_panel(base, panel)
  draw = ImageDraw.Draw(base)
  center_text(draw, "确认购买", (135, 394, 585, 448), INK, 34, True, 1, LIGHT)
  paste_shop_art(base, "tickets", (360, 522), 1.2)
  center_text(draw, "招募券包", (170, 572, 550, 614), INK, 23, True, 1, LIGHT)
  centered_icon_value(base, (250, 620, 470, 664), "120", font_size=23, icon_size=24)
  paste_button(base, (148, 690, 330, 758), "取消", 21, "secondary")
  paste_button(base, (390, 690, 572, 758), "购买", 21, "primary")
  path = OUT / f"{PREFIX}_popup_purchase_mockup.png"
  base.convert("RGB").save(path, quality=96)
  return path


def build_overview(paths: list[Path]) -> Path:
  thumbs = []
  for path in paths:
    img = Image.open(path).convert("RGB")
    img.thumbnail((260, 462), Image.Resampling.LANCZOS)
    thumbs.append((path, img.copy()))
  sheet = Image.new("RGB", (920, 1980), (242, 219, 166))
  draw = ImageDraw.Draw(sheet)
  center_text(draw, "1930s 手绘 UI · ui-ux-pro-max 复验 v14", (0, 20, 920, 72), INK, 32, True)
  labels = [
    "主页面", "编组页", "战斗页 7×13", "抽卡页", "商店页", "任务页",
    "卡牌详情弹窗", "战斗胜利弹窗", "确认购买弹窗",
  ]
  for index, ((_, img), label) in enumerate(zip(thumbs, labels, strict=True)):
    col = index % 3
    row = index // 3
    x = 34 + col * 296
    y = 100 + row * 620
    sheet.paste(img, (x, y))
    center_text(draw, label, (x, y + img.height + 14, x + img.width, y + img.height + 54), INK, 20, True)
  path = OUT / f"{PREFIX}_page_set_overview.png"
  sheet.save(path, quality=96)
  return path


def main() -> int:
  OUT.mkdir(parents=True, exist_ok=True)
  paths = [
    build_lobby(),
    build_deck(),
    build_battle(),
    build_gacha(),
    build_shop(),
    build_more(),
    build_card_detail_popup(),
    build_victory_popup(),
    build_purchase_popup(),
  ]
  paths.append(build_overview(paths))
  for path in paths:
    print(f"Wrote {path.relative_to(ROOT).as_posix()}")
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
