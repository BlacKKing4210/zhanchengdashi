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
MAIN_FINAL = OUT / "current_game_1930s_v11_i_aligned_lobby_mockup.png"
PREFIX = "current_game_1930s_v11_i_aligned"
W, H = 720, 1280

INK = (48, 30, 22, 255)
LIGHT = (255, 250, 222, 255)
RED = (172, 55, 45, 255)
BLUE = (38, 112, 139, 255)
GOLD = (202, 128, 31, 255)
GREEN = (42, 115, 74, 255)
WHITE = (255, 255, 245, 255)

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


def paste_button(base: Image.Image, rect: tuple[int, int, int, int], label: str, size: int = 24) -> None:
  source = load_base(MAIN_BASE)
  paste_masked_component(base, source, (176, 938, 550, 1076), rect, "ellipse")
  center_text(ImageDraw.Draw(base), label, rect, INK, size, True, 1, LIGHT)


def paste_ticket(base: Image.Image, rect: tuple[int, int, int, int]) -> None:
  source = load_base(MAIN_BASE)
  paste_masked_component(base, source, (91, 869, 630, 932), rect, "rounded")


def build_lobby() -> Path:
  if not MAIN_FINAL.exists():
    raise FileNotFoundError(f"Run build_1930s_ai_painted_main_page_mockup.py first: {MAIN_FINAL}")
  return MAIN_FINAL


def build_deck() -> Path:
  base = load_base(DECK_BASE)
  draw = ImageDraw.Draw(base)
  add_top_values(draw)
  center_text(draw, "编组", (154, 116, 566, 204), INK, 45, False, 1, LIGHT)
  center_text(draw, "出战 6/6", (76, 279, 306, 316), WHITE, 20, True, 2, INK)
  center_text(draw, "战力 1280", (414, 279, 644, 316), WHITE, 20, True, 2, INK)

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
    center_text(draw, title, (x - 76, y + 48, x + 76, y + 76), INK, 15, True, 1, LIGHT)
    center_text(draw, role, (x - 62, y + 80, x + 62, y + 108), INK, 15, True, 1, LIGHT)

  center_text(draw, "所有卡牌", (92, 758, 284, 790), WHITE, 19, True, 2, INK)
  collection = [
    ("bear", "熊"), ("fox", "狐"), ("wolf", "狼"), ("deer", "鹿"), ("duck", "鸭"),
    ("tiger", "虎"), ("eagle", "鹰"), ("cow", "牛"), ("sheep", "羊"), ("pig", "猪"),
  ]
  x_positions = [116, 238, 360, 482, 604]
  for index, (name, title) in enumerate(collection):
    row = index // 5
    x = x_positions[index % 5]
    y = 858 + row * 158
    paste_animal(base, name, (x, y), (58, 58))
    center_text(draw, title, (x - 42, y + 54, x + 42, y + 78), INK, 14, True, 1, LIGHT)
  add_bottom_nav(draw, "编组")
  path = OUT / f"{PREFIX}_deck_page_mockup.png"
  base.convert("RGB").save(path, quality=96)
  return path


def paper_patch(source: Image.Image, size: tuple[int, int], tint: tuple[int, int, int], seed: int) -> Image.Image:
  sample = source.crop((250, 178, 470, 260)).convert("RGB")
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


def draw_exact_battle_grid(base: Image.Image) -> dict[tuple[int, int], tuple[int, int]]:
  draw = ImageDraw.Draw(base)
  main_source = load_base(MAIN_BASE)
  radius = 43.0
  cols, rows = 7, 13
  origin = board_origin(cols, rows, radius)
  centers: dict[tuple[int, int], tuple[int, int]] = {}

  field = paper_patch(main_source, (592, 982), (110, 92, 59), 99)
  base.paste(field, (64, 110))
  draw.rounded_rectangle((61, 107, 659, 1095), radius=16, outline=INK, width=6)

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
    draw.ellipse((center[0] - 12, center[1] - 12, center[0] + 12, center[1] + 12), fill=(237, 176, 45, 255), outline=INK, width=3)
    center_text(draw, "25", (center[0] - 19, center[1] + 11, center[0] + 19, center[1] + 33), LIGHT, 11, True, 2, INK)

  for col in (1, 3, 5):
    center = centers[(col, 7)]
    center_text(draw, "?", (center[0] - 18, center[1] - 25, center[0] + 18, center[1] + 25), LIGHT, 24, True, 2, INK)
  return centers


def paste_battle_frame(base: Image.Image) -> None:
  source = load_base(BATTLE_BASE)
  draw = ImageDraw.Draw(base)
  draw.rounded_rectangle((36, 82, 684, 1120), radius=28, outline=INK, width=8)
  base.alpha_composite(component(source, (74, 282, 646, 360), (648, 92)), (36, 82))
  base.alpha_composite(component(source, (18, 350, 105, 845), (70, 886)), (36, 158))
  base.alpha_composite(component(source, (608, 350, 702, 845), (70, 886)), (614, 158))
  base.alpha_composite(component(source, (68, 845, 652, 920), (648, 90)), (36, 1030))


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
  for name, key in (("mouse", (1, 3)), ("frog", (4, 4)), ("rabbit", (1, 9)), ("cat", (3, 10)), ("dog", (5, 9))):
    paste_animal(base, name, centers[key], (44, 44))
  paste_battle_frame(base)

  source = load_base(BATTLE_BASE)
  paste_masked_component(base, source, (198, 140, 552, 226), (250, 12, 470, 68), "rounded")
  pause = component(source, (626, 139, 710, 222), (64, 64))
  base.alpha_composite(pause, (608, 76))

  paste_ticket(base, (26, 1132, 694, 1250))
  draw = ImageDraw.Draw(base)
  add_top_values(draw)
  center_text(draw, "青铜一星  VS  青铜一星", (258, 19, 462, 61), INK, 14, True, 1, LIGHT)
  center_text(draw, "可解锁：动物营地", (62, 1143, 658, 1183), INK, 22, True, 1, LIGHT)
  center_text(draw, "花费 50  ·  普通动物，品质在解锁时随机", (62, 1187, 658, 1228), INK, 16, True, 1, LIGHT)
  path = OUT / f"{PREFIX}_battle_page_mockup.png"
  base.convert("RGB").save(path, quality=96)
  return path


def build_gacha() -> Path:
  base = load_base(DECK_BASE)
  draw = ImageDraw.Draw(base)
  add_top_values(draw)
  center_text(draw, "抽卡", (154, 112, 566, 183), INK, 43, False, 1, LIGHT)
  center_text(draw, "今日招募", (154, 187, 566, 226), INK, 20, True, 1, LIGHT)
  for center in [(160, 405), (360, 405), (560, 405), (160, 620), (360, 620), (560, 620)]:
    center_text(draw, "?", (center[0] - 36, center[1] - 42, center[0] + 36, center[1] + 42), GOLD, 38, True, 1, LIGHT)
  center_text(draw, "最近获得", (92, 758, 286, 790), WHITE, 19, True, 2, INK)
  recent = [("rabbit", "兔"), ("frog", "蛙"), ("cat", "猫"), ("dog", "狗"), ("mouse", "鼠")]
  for (name, title), x in zip(recent, [116, 238, 360, 482, 604], strict=True):
    paste_animal(base, name, (x, 858), (60, 60))
    center_text(draw, title, (x - 42, 913, x + 42, 939), INK, 14, True, 1, LIGHT)
  paste_button(base, (118, 1044, 334, 1114), "抽 1 次", 22)
  paste_button(base, (386, 1044, 602, 1114), "抽 10 次", 22)
  add_bottom_nav(draw, "抽卡")
  path = OUT / f"{PREFIX}_gacha_page_mockup.png"
  base.convert("RGB").save(path, quality=96)
  return path


def centered_icon_value(
  base: Image.Image,
  rect: tuple[int, int, int, int],
  value: str,
  icon_kind: str = "coin",
) -> None:
  draw = ImageDraw.Draw(base)
  if value == "免费":
    center_text(draw, value, rect, GOLD, 16, True, 1, LIGHT)
    return
  source = load_base(MAIN_BASE)
  crop = (44, 31, 94, 79) if icon_kind == "coin" else (499, 28, 551, 78)
  icon = component(source, crop, (18, 18))
  icon_mask = Image.new("L", icon.size, 0)
  ImageDraw.Draw(icon_mask).ellipse((0, 0, icon.width - 1, icon.height - 1), fill=255)
  icon.putalpha(icon_mask.filter(ImageFilter.GaussianBlur(0.35)))
  fnt = fit_font(draw, value, rect[2] - rect[0] - 30, 16, True)
  box = draw.textbbox((0, 0), value, font=fnt)
  text_width = box[2] - box[0]
  total = 18 + 6 + text_width
  x = (rect[0] + rect[2] - total) // 2
  y = (rect[1] + rect[3] - 18) // 2
  base.alpha_composite(icon, (x, y))
  center_text(draw, value, (x + 24, rect[1], x + 24 + text_width, rect[3]), GOLD, 16, True, 1, LIGHT)


def build_shop() -> Path:
  base = load_base(DECK_BASE)
  draw = ImageDraw.Draw(base)
  add_top_values(draw)
  center_text(draw, "商店", (154, 112, 566, 183), INK, 43, False, 1, LIGHT)
  center_text(draw, "今日推荐", (154, 187, 566, 226), INK, 20, True, 1, LIGHT)
  items = [
    ("每日补给", "免费", (160, 405)), ("招募券包", "120", (360, 405)), ("新手补给", "300", (560, 405)),
    ("动物碎片", "80", (160, 620)), ("稀有礼包", "680", (360, 620)), ("刷新商店", "20", (560, 620)),
  ]
  for title, price, center in items:
    center_text(draw, title, (center[0] - 70, center[1] - 18, center[0] + 70, center[1] + 22), INK, 17, True, 1, LIGHT)
    centered_icon_value(base, (center[0] - 68, center[1] + 61, center[0] + 68, center[1] + 93), price)
  center_text(draw, "限时礼包", (92, 758, 286, 790), WHITE, 19, True, 2, INK)
  offers = [("金币箱", "300"), ("券箱", "5"), ("碎片包", "180"), ("经验包", "90"), ("刷新", "20")]
  for (title, price), x in zip(offers, [116, 238, 360, 482, 604], strict=True):
    center_text(draw, title, (x - 48, 845, x + 48, 879), INK, 14, True, 1, LIGHT)
    centered_icon_value(base, (x - 49, 913, x + 49, 940), price)
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
    ("每日登录", "20 金币", "完成"),
    ("赢得 1 场战斗", "1 招募券", "0/1"),
    ("升级 1 张卡牌", "50 金币", "0/1"),
    ("解锁 3 个地块", "30 金币", "1/3"),
  ]
  for index, (title, reward, state) in enumerate(tasks):
    y = 360 + index * 108
    paste_ticket(base, (104, y, 616, y + 82))
    left_text(draw, title, (152, y + 8, 438, y + 40), INK, 18, True, 1, LIGHT)
    left_text(draw, reward, (152, y + 42, 438, y + 72), GOLD, 15, True, 1, LIGHT)
    center_text(draw, state, (488, y + 15, 592, y + 66), RED if state == "完成" else INK, 17, True, 1, LIGHT)
  paste_button(base, (88, 846, 254, 908), "设置", 19)
  paste_button(base, (277, 846, 443, 908), "公告", 19)
  paste_button(base, (466, 846, 632, 908), "邮件", 19)
  paste_button(base, (190, 963, 530, 1044), "领取全部", 28)
  add_bottom_nav(draw, "更多")
  path = OUT / f"{PREFIX}_more_tasks_page_mockup.png"
  base.convert("RGB").save(path, quality=96)
  return path


def paste_popup_panel(base: Image.Image, rect: tuple[int, int, int, int]) -> None:
  source = load_base(MAIN_BASE)
  paste_masked_component(base, source, (110, 140, 610, 330), rect, "banner")


def build_popup_sheet() -> Path:
  base = load_base(MAIN_BASE)
  base.alpha_composite(Image.new("RGBA", base.size, (20, 12, 8, 142)))
  draw = ImageDraw.Draw(base)

  panels = [(100, 110, 620, 385), (100, 440, 620, 715), (100, 770, 620, 1045)]
  for rect in panels:
    paste_popup_panel(base, rect)

  center_text(draw, "卡牌详情", (155, 132, 565, 183), INK, 30, True, 1, LIGHT)
  paste_animal(base, "frog", (205, 270), (92, 92))
  left_text(draw, "青蛙  Lv.1", (286, 208, 560, 239), INK, 19, True, 1, LIGHT)
  left_text(draw, "攻击 12   生命 90", (286, 244, 560, 275), INK, 17, True, 1, LIGHT)
  left_text(draw, "碎片 3/10", (286, 280, 440, 313), GOLD, 16, True, 1, LIGHT)
  paste_button(base, (422, 294, 572, 350), "升级 50", 17)

  center_text(draw, "战斗胜利", (155, 462, 565, 513), INK, 30, True, 1, LIGHT)
  center_text(draw, "+1 招募券", (180, 535, 540, 580), GOLD, 23, True, 1, LIGHT)
  center_text(draw, "当前段位  青铜二星", (180, 582, 540, 620), INK, 17, True, 1, LIGHT)
  paste_button(base, (260, 630, 460, 688), "返回主页面", 18)

  center_text(draw, "确认购买", (155, 792, 565, 843), INK, 30, True, 1, LIGHT)
  center_text(draw, "招募券包", (180, 865, 540, 904), INK, 21, True, 1, LIGHT)
  centered_icon_value(base, (250, 906, 470, 942), "120")
  paste_button(base, (176, 960, 336, 1018), "取消", 18)
  paste_button(base, (384, 960, 544, 1018), "购买", 18)

  path = OUT / f"{PREFIX}_popup_sheet_mockup.png"
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
  center_text(draw, "1930s 手绘 UI 页面效果图套件 v11", (0, 20, 920, 72), INK, 34, True)
  labels = ["主页面", "编组页", "战斗页 7×13", "抽卡页", "商店页", "任务页", "弹窗合集"]
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
    build_popup_sheet(),
  ]
  paths.append(build_overview(paths))
  for path in paths:
    print(f"Wrote {path.relative_to(ROOT).as_posix()}")
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
