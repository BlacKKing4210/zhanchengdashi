from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "visual_concepts"
SOURCE = OUT / "current_game_1930s_v5_c_cheerful_fair_lobby_bg_source.png"
MOCKUP = OUT / "current_game_1930s_v6_d_full_rubberhose_lobby_mockup.png"
BACKGROUND = OUT / "current_game_1930s_v6_d_full_rubberhose_lobby_background.png"
W, H = 720, 1280


Color = tuple[int, int, int, int]

INK: Color = (37, 24, 18, 255)
INK_SOFT: Color = (85, 55, 39, 255)
CREAM: Color = (255, 236, 180, 255)
PAPER: Color = (246, 217, 149, 255)
RED: Color = (207, 68, 52, 255)
BLUE: Color = (53, 142, 177, 255)
TEAL: Color = (47, 126, 125, 255)
GREEN: Color = (95, 168, 93, 255)
GOLD: Color = (255, 197, 58, 255)
BROWN: Color = (111, 69, 38, 255)
SHADOW: Color = (0, 0, 0, 70)


def rgba(color: Color, alpha: int) -> Color:
  return color[0], color[1], color[2], alpha


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


def text_size(draw: ImageDraw.ImageDraw, text: str, fnt: ImageFont.FreeTypeFont) -> tuple[int, int]:
  box = draw.textbbox((0, 0), text, font=fnt)
  return box[2] - box[0], box[3] - box[1]


def center_text(
  draw: ImageDraw.ImageDraw,
  text: str,
  rect: tuple[int, int, int, int],
  fill: Color,
  size: int,
  bold: bool = False,
  stroke: int = 0,
  stroke_fill: Color = INK,
) -> None:
  fnt = font(size, bold)
  width = rect[2] - rect[0] - 8
  clipped = text
  while clipped and text_size(draw, clipped, fnt)[0] > width:
    clipped = clipped[:-1]
  tw, th = text_size(draw, clipped, fnt)
  x = rect[0] + (rect[2] - rect[0] - tw) / 2
  y = rect[1] + (rect[3] - rect[1] - th) / 2 - 2
  draw.text((x, y), clipped, font=fnt, fill=fill, stroke_width=stroke, stroke_fill=stroke_fill)


def left_text(draw: ImageDraw.ImageDraw, text: str, pos: tuple[int, int], fill: Color, size: int, bold: bool = False) -> None:
  draw.text(pos, text, font=font(size, bold), fill=fill)


def cover_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
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


def prepare_background() -> Image.Image:
  image = cover_resize(Image.open(SOURCE), (W, H))
  image = ImageEnhance.Color(image).enhance(1.02)
  image = ImageEnhance.Contrast(image).enhance(1.05)

  veil = Image.new("RGBA", (W, H), (0, 0, 0, 0))
  draw = ImageDraw.Draw(veil)
  draw.rectangle((0, 0, W, 145), fill=(255, 236, 179, 44))
  draw.rectangle((0, 1098, W, H), fill=(25, 15, 13, 72))
  draw.rounded_rectangle((42, 130, 678, 832), radius=28, fill=(255, 236, 179, 30))
  image.alpha_composite(veil)

  grain = Image.new("RGBA", (W, H), (0, 0, 0, 0))
  gd = ImageDraw.Draw(grain)
  seed = 7331
  for _ in range(3400):
    seed = (1103515245 * seed + 12345) & 0x7FFFFFFF
    x = seed % W
    seed = (1103515245 * seed + 12345) & 0x7FFFFFFF
    y = seed % H
    alpha = 4 + seed % 15
    gd.point((x, y), fill=(48, 30, 23, alpha))
  for y in range(0, H, 6):
    gd.line((0, y, W, y), fill=(40, 25, 20, 5), width=1)
  image.alpha_composite(grain.filter(ImageFilter.GaussianBlur(0.2)))
  image.convert("RGB").save(BACKGROUND, quality=96)
  return image


def shadowed_layer(base: Image.Image) -> tuple[Image.Image, ImageDraw.ImageDraw]:
  layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
  return layer, ImageDraw.Draw(layer)


def paste_shadow(base: Image.Image, layer: Image.Image, blur: float = 1.0) -> None:
  shadow = Image.new("RGBA", base.size, (0, 0, 0, 0))
  alpha = layer.getchannel("A").filter(ImageFilter.GaussianBlur(blur))
  shadow.putalpha(alpha.point(lambda p: min(95, p // 3)))
  base.alpha_composite(shadow, (0, 8))
  base.alpha_composite(layer)


def rough_panel(base: Image.Image, rect: tuple[int, int, int, int], fill: Color, outline: Color = INK, radius: int = 22, width: int = 5) -> None:
  layer, draw = shadowed_layer(base)
  draw.rounded_rectangle(rect, radius=radius, fill=fill, outline=outline, width=width)
  x1, y1, x2, y2 = rect
  draw.rounded_rectangle((x1 + 9, y1 + 8, x2 - 9, y2 - 9), radius=max(8, radius - 9), outline=rgba((255, 255, 255, 255), 68), width=2)
  draw.arc((x1 + 12, y1 + 10, x2 - 12, y1 + 42), 200, 340, fill=rgba((255, 255, 255, 255), 70), width=3)
  draw.line((x1 + 16, y2 - 11, x2 - 16, y2 - 14), fill=rgba((80, 42, 26, 255), 70), width=3)
  paste_shadow(base, layer, 1.2)


def draw_bulbs(draw: ImageDraw.ImageDraw, points: list[tuple[int, int]], active: bool = True) -> None:
  for x, y in points:
    draw.ellipse((x - 8, y - 8, x + 8, y + 8), fill=GOLD if active else PAPER, outline=INK, width=3)
    draw.ellipse((x - 4, y - 5, x + 1, y), fill=(255, 255, 235, 180))


def draw_resource_ticket(base: Image.Image, rect: tuple[int, int, int, int], label: str, value: str, kind: str, color: Color) -> None:
  layer, draw = shadowed_layer(base)
  x1, y1, x2, y2 = rect
  draw.rounded_rectangle(rect, radius=18, fill=CREAM, outline=INK, width=5)
  draw.rectangle((x1 + 4, y1 + 7, x1 + 47, y2 - 7), fill=color, outline=INK, width=3)
  for y in (y1 + 14, y2 - 14):
    draw.ellipse((x1 + 35, y - 5, x1 + 45, y + 5), fill=(255, 249, 210, 255), outline=INK, width=2)
  if kind == "coin":
    draw.ellipse((x1 + 13, y1 + 14, x1 + 37, y1 + 38), fill=GOLD, outline=INK, width=3)
    draw.arc((x1 + 18, y1 + 17, x1 + 34, y1 + 34), 210, 330, fill=(255, 255, 230, 210), width=2)
  else:
    draw.rounded_rectangle((x1 + 12, y1 + 15, x1 + 37, y1 + 37), radius=4, fill=(118, 211, 234, 255), outline=INK, width=3)
    draw.line((x1 + 20, y1 + 16, x1 + 27, y1 + 36), fill=(255, 255, 255, 150), width=2)
  left_text(draw, label, (x1 + 62, y1 + 12), INK, 20, True)
  center_text(draw, value, (x2 - 66, y1, x2 - 8, y2), INK, 22, True)
  paste_shadow(base, layer, 1.0)


def draw_title(base: Image.Image) -> None:
  layer, draw = shadowed_layer(base)
  draw.polygon([(166, 79), (554, 79), (592, 117), (554, 155), (166, 155), (128, 117)], fill=RED, outline=INK)
  draw.rounded_rectangle((178, 69, 542, 145), radius=24, fill=CREAM, outline=INK, width=6)
  draw_bulbs(draw, [(204 + i * 45, 83) for i in range(8)], True)
  center_text(draw, "丛林法则", (176, 83, 544, 143), INK, 42, True)
  draw.line((212, 136, 508, 136), fill=rgba(RED, 170), width=3)
  paste_shadow(base, layer, 1.4)


def oval_points(cx: int, cy: int, rx: int, ry: int, steps: int = 80) -> list[tuple[float, float]]:
  return [
    (cx + math.cos(math.tau * i / steps) * rx, cy + math.sin(math.tau * i / steps) * ry)
    for i in range(steps)
  ]


def draw_stage_panel(base: Image.Image) -> None:
  layer, draw = shadowed_layer(base)
  rect = (42, 148, 678, 814)
  draw.rounded_rectangle(rect, radius=30, fill=(250, 225, 157, 255), outline=INK, width=7)
  draw.rounded_rectangle((57, 163, 663, 799), radius=21, fill=(111, 179, 101, 255), outline=INK, width=4)
  draw.rectangle((57, 163, 663, 292), fill=(255, 218, 136, 255))
  draw.polygon([(58, 164), (122, 164), (58, 238)], fill=RED, outline=INK)
  draw.polygon([(662, 164), (598, 164), (662, 238)], fill=RED, outline=INK)
  draw.arc((84, 220, 636, 532), 195, 345, fill=INK_SOFT, width=5)
  draw.polygon(oval_points(360, 360, 294, 114), fill=(75, 148, 94, 235), outline=INK)
  draw.polygon(oval_points(360, 447, 278, 96), fill=(63, 132, 86, 226), outline=INK)
  draw.polygon(oval_points(360, 554, 259, 84), fill=(130, 203, 100, 238), outline=INK)
  draw.polygon(oval_points(360, 675, 238, 68), fill=(156, 216, 119, 245), outline=INK)
  for x in (142, 253, 364, 475, 586):
    draw.line((x, 196, x - 2, 775), fill=rgba((255, 252, 217, 255), 120), width=3)
  for y in (352, 465, 576, 692):
    draw.arc((118, y - 72, 602, y + 78), 202, 338, fill=rgba(INK, 150), width=4)
  draw_bulbs(draw, [(112, 206), (608, 206), (112, 757), (608, 757)], True)
  paste_shadow(base, layer, 1.5)


def draw_gate(base: Image.Image) -> None:
  layer, draw = shadowed_layer(base)
  cx, cy = 360, 312
  draw.ellipse((cx - 138, cy + 65, cx + 138, cy + 94), fill=(0, 0, 0, 52))
  draw.rounded_rectangle((cx - 78, cy - 14, cx + 78, cy + 84), radius=23, fill=(255, 215, 120, 255), outline=INK, width=6)
  for dx in (-78, 78):
    draw.rounded_rectangle((cx + dx - 32, cy - 5, cx + dx + 32, cy + 78), radius=13, fill=CREAM, outline=INK, width=5)
    draw.polygon([(cx + dx - 42, cy - 1), (cx + dx, cy - 51), (cx + dx + 42, cy - 1)], fill=RED, outline=INK)
  draw.arc((cx - 34, cy + 22, cx + 34, cy + 96), 180, 360, fill=INK, width=6)
  draw.rectangle((cx - 31, cy + 58, cx + 31, cy + 96), fill=BROWN, outline=INK, width=5)
  draw.pieslice((cx - 31, cy + 22, cx + 31, cy + 94), 180, 360, fill=BROWN, outline=INK)
  draw.line((cx, cy - 62, cx, cy - 8), fill=INK, width=5)
  draw.polygon([(cx, cy - 58), (cx + 50, cy - 46), (cx, cy - 30)], fill=BLUE, outline=INK)
  paste_shadow(base, layer, 1.0)


def animal_image(name: str, max_size: tuple[int, int]) -> Image.Image:
  path = ROOT / "assets" / "card_art" / "animals" / f"{name}.png"
  image = Image.open(path).convert("RGBA")
  box = image.getbbox()
  if box:
    image = image.crop(box)
  image.thumbnail(max_size, Image.Resampling.LANCZOS)
  return image


def paste_animal(base: Image.Image, name: str, center: tuple[int, int], max_size: tuple[int, int]) -> None:
  image = animal_image(name, max_size)
  layer = Image.new("RGBA", base.size, (0, 0, 0, 0))
  draw = ImageDraw.Draw(layer)
  x = round(center[0] - image.width / 2)
  y = round(center[1] - image.height / 2)
  draw.ellipse((center[0] - 42, center[1] + image.height // 2 - 14, center[0] + 42, center[1] + image.height // 2 + 6), fill=(0, 0, 0, 55))
  base.alpha_composite(layer)
  base.alpha_composite(image, (x, y))


def draw_small_building(base: Image.Image, center: tuple[int, int], kind: str) -> None:
  layer, draw = shadowed_layer(base)
  x, y = center
  draw.ellipse((x - 42, y + 34, x + 42, y + 51), fill=(0, 0, 0, 55))
  if kind == "mine":
    draw.rounded_rectangle((x - 35, y - 12, x + 35, y + 35), radius=9, fill=(121, 77, 43, 255), outline=INK, width=5)
    draw.polygon([(x - 43, y - 11), (x, y - 49), (x + 43, y - 11)], fill=GOLD, outline=INK)
    draw.ellipse((x - 14, y + 4, x + 14, y + 30), fill=(255, 236, 160, 255), outline=INK, width=3)
  else:
    draw.rounded_rectangle((x - 27, y - 18, x + 27, y + 40), radius=8, fill=CREAM, outline=INK, width=5)
    draw.polygon([(x - 38, y - 17), (x, y - 55), (x + 38, y - 17)], fill=BLUE, outline=INK)
    draw.rectangle((x - 30, y + 14, x + 30, y + 27), fill=RED, outline=INK, width=3)
  paste_shadow(base, layer, 0.8)


def draw_scene_contents(base: Image.Image) -> None:
  draw_gate(base)
  paste_animal(base, "mouse", (264, 470), (92, 92))
  paste_animal(base, "frog", (455, 470), (98, 98))
  draw_small_building(base, (248, 598), "mine")
  draw_small_building(base, (458, 598), "tower")
  paste_animal(base, "chicken", (215, 694), (98, 98))
  paste_animal(base, "cat", (360, 708), (104, 104))
  paste_animal(base, "dog", (505, 694), (104, 104))


def draw_rank_panel(base: Image.Image) -> None:
  layer, draw = shadowed_layer(base)
  draw.rounded_rectangle((62, 834, 658, 920), radius=24, fill=CREAM, outline=INK, width=6)
  draw.rectangle((82, 843, 248, 912), fill=BLUE, outline=INK, width=4)
  draw.polygon([(528, 843), (640, 843), (622, 912), (510, 912)], fill=RED, outline=INK)
  left_text(draw, "青铜 1星", (96, 855), (255, 249, 224, 255), 26, True)
  center_text(draw, "胜 0  负 0", (270, 850, 492, 906), INK, 22, True)
  center_text(draw, "段位赛", (512, 850, 634, 906), (255, 249, 224, 255), 20, True)
  for i, fill in enumerate([GOLD, GOLD, PAPER]):
    x = 100 + i * 28
    draw.ellipse((x, 895, x + 15, 910), fill=fill, outline=INK, width=2)
  paste_shadow(base, layer, 1.0)


def draw_match_button(base: Image.Image) -> None:
  layer, draw = shadowed_layer(base)
  draw.ellipse((192, 948, 528, 1042), fill=RED, outline=INK, width=7)
  draw.ellipse((208, 955, 512, 1029), fill=GOLD, outline=INK, width=5)
  draw.arc((232, 966, 488, 1002), 190, 350, fill=(255, 252, 214, 120), width=4)
  draw.line((250, 1018, 470, 1016), fill=rgba(RED, 180), width=4)
  center_text(draw, "匹配", (214, 962, 506, 1030), INK, 34, True, 1, (255, 249, 224, 255))
  paste_shadow(base, layer, 1.4)


def draw_nav_icon(draw: ImageDraw.ImageDraw, center: tuple[int, int], kind: str, fill: Color) -> None:
  x, y = center
  if kind == "shop":
    draw.rectangle((x - 22, y - 11, x + 22, y + 22), fill=fill, outline=INK, width=4)
    draw.polygon([(x - 27, y - 12), (x + 27, y - 12), (x + 20, y - 30), (x - 20, y - 30)], fill=RED, outline=INK)
  elif kind == "deck":
    draw.rounded_rectangle((x - 19, y - 22, x + 8, y + 18), radius=5, fill=fill, outline=INK, width=4)
    draw.rounded_rectangle((x - 6, y - 16, x + 21, y + 23), radius=5, fill=(255, 245, 202, 255), outline=INK, width=3)
  elif kind == "battle":
    draw.line((x - 24, y - 24, x + 24, y + 24), fill=INK, width=8)
    draw.line((x + 24, y - 24, x - 24, y + 24), fill=INK, width=8)
    draw.line((x - 24, y - 24, x + 24, y + 24), fill=GOLD, width=4)
    draw.line((x + 24, y - 24, x - 24, y + 24), fill=GOLD, width=4)
  elif kind == "draw":
    for dx, dy, r in [(-16, -8, 5), (-6, -17, 5), (6, -16, 5), (16, -7, 5), (0, 6, 13)]:
      draw.ellipse((x + dx - r, y + dy - r, x + dx + r, y + dy + r), fill=fill, outline=INK, width=3)
  else:
    for dx in (-17, 0, 17):
      draw.ellipse((x + dx - 6, y - 6, x + dx + 6, y + 6), fill=fill, outline=INK, width=3)


def draw_nav(base: Image.Image) -> None:
  layer, draw = shadowed_layer(base)
  draw.rectangle((0, 1128, W, H), fill=(33, 78, 92, 255))
  labels = [("商店", "shop"), ("编组", "deck"), ("战斗", "battle"), ("抽卡", "draw"), ("更多", "more")]
  for i, (label, kind) in enumerate(labels):
    x1 = 8 + i * 142
    x2 = x1 + 132
    active = label == "战斗"
    fill = RED if active else CREAM
    draw.polygon([(x1 + 8, 1148), (x2 - 8, 1148), (x2, 1174), (x2 - 12, 1266), (x1 + 12, 1266), (x1, 1174)], fill=fill, outline=INK)
    draw.line((x1 + 18, 1158, x2 - 18, 1158), fill=rgba((255, 255, 255, 255), 120), width=3)
    icon_fill = GOLD if active else BLUE
    draw_nav_icon(draw, ((x1 + x2) // 2, 1196), kind, icon_fill)
    center_text(draw, label, (x1 + 8, 1230, x2 - 8, 1266), INK if not active else (255, 247, 217, 255), 22, True)
    if i in (0, 4):
      draw.arc((x2 - 28, 1160, x2 - 8, 1184), 180, 360, fill=INK, width=3)
      draw.rounded_rectangle((x2 - 31, 1176, x2 - 5, 1201), radius=5, fill=(245, 239, 215, 255), outline=INK, width=3)
  paste_shadow(base, layer, 0.9)


def build() -> None:
  OUT.mkdir(parents=True, exist_ok=True)
  image = prepare_background()
  draw_resource_ticket(image, (44, 22, 244, 70), "金币", "60", "coin", RED)
  draw_resource_ticket(image, (476, 22, 676, 70), "券", "10", "ticket", BLUE)
  draw_title(image)
  draw_stage_panel(image)
  draw_scene_contents(image)
  draw_rank_panel(image)
  draw_match_button(image)
  draw_nav(image)
  image.convert("RGB").save(MOCKUP, quality=96)
  print(f"Wrote {BACKGROUND.relative_to(ROOT).as_posix()}")
  print(f"Wrote {MOCKUP.relative_to(ROOT).as_posix()}")


if __name__ == "__main__":
  build()
