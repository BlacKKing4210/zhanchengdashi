from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "visual_concepts"
SOURCE = OUT / "current_game_1930s_v7_e_ai_painted_full_ui_base_with_icons.png"
BACKGROUND = OUT / "current_game_1930s_v9_g_ai_painted_clean_info_ui_background.png"
MOCKUP = OUT / "current_game_1930s_v9_g_ai_painted_clean_info_ui_lobby_mockup.png"
W, H = 720, 1280

INK = (48, 30, 22, 255)
CREAM = (255, 241, 190, 255)
LIGHT = (255, 250, 222, 255)
BLUE = (42, 118, 145, 255)
RED = (185, 61, 46, 255)
GOLD = (205, 128, 30, 255)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
  candidates = [
    Path("C:/Windows/Fonts/simkai.ttf"),
    Path("C:/Windows/Fonts/STXINGKA.TTF"),
    Path("C:/Windows/Fonts/msyhbd.ttc" if bold else "C:/Windows/Fonts/msyh.ttc"),
    Path("C:/Windows/Fonts/simhei.ttf"),
  ]
  for path in candidates:
    if path.exists():
      return ImageFont.truetype(str(path), size=size)
  return ImageFont.load_default()


def text_size(draw: ImageDraw.ImageDraw, value: str, fnt: ImageFont.FreeTypeFont) -> tuple[int, int]:
  box = draw.textbbox((0, 0), value, font=fnt)
  return box[2] - box[0], box[3] - box[1]


def center_text(
  draw: ImageDraw.ImageDraw,
  value: str,
  rect: tuple[int, int, int, int],
  fill: tuple[int, int, int, int],
  size: int,
  bold: bool = False,
  stroke_width: int = 0,
  stroke_fill: tuple[int, int, int, int] = CREAM,
) -> None:
  fnt = font(size, bold)
  text = value
  max_width = rect[2] - rect[0] - 8
  while text and text_size(draw, text, fnt)[0] > max_width:
    text = text[:-1]
  tw, th = text_size(draw, text, fnt)
  x = rect[0] + (rect[2] - rect[0] - tw) / 2
  y = rect[1] + (rect[3] - rect[1] - th) / 2 - 2
  draw.text((x, y), text, font=fnt, fill=fill, stroke_width=stroke_width, stroke_fill=stroke_fill)


def right_text(
  draw: ImageDraw.ImageDraw,
  value: str,
  rect: tuple[int, int, int, int],
  fill: tuple[int, int, int, int],
  size: int,
  bold: bool = False,
  stroke_width: int = 0,
  stroke_fill: tuple[int, int, int, int] = CREAM,
) -> None:
  fnt = font(size, bold)
  text = value
  max_width = rect[2] - rect[0] - 8
  while text and text_size(draw, text, fnt)[0] > max_width:
    text = text[:-1]
  tw, th = text_size(draw, text, fnt)
  x = rect[2] - tw - 4
  y = rect[1] + (rect[3] - rect[1] - th) / 2 - 2
  draw.text((x, y), text, font=fnt, fill=fill, stroke_width=stroke_width, stroke_fill=stroke_fill)


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


def animal(name: str, max_size: tuple[int, int]) -> Image.Image:
  image = Image.open(ROOT / "assets" / "card_art" / "animals" / f"{name}.png").convert("RGBA")
  box = image.getbbox()
  if box:
    image = image.crop(box)
  image.thumbnail(max_size, Image.Resampling.LANCZOS)
  return image


def paste_animal(base: Image.Image, name: str, center_x: int, feet_y: int, max_size: tuple[int, int]) -> None:
  image = animal(name, max_size)
  x = round(center_x - image.width / 2)
  y = round(feet_y - image.height)
  base.alpha_composite(image, (x, y))


def add_existing_animals(base: Image.Image) -> None:
  # Existing project animal PNGs are composited only; no redraw or style transfer.
  paste_animal(base, "mouse", 232, 642, (118, 118))
  paste_animal(base, "frog", 361, 642, (126, 126))
  paste_animal(base, "rabbit", 488, 642, (122, 122))
  paste_animal(base, "chicken", 232, 776, (124, 124))
  paste_animal(base, "cat", 361, 780, (126, 126))
  paste_animal(base, "dog", 488, 776, (128, 128))


def add_labels(base: Image.Image) -> None:
  draw = ImageDraw.Draw(base)
  center_text(draw, "60", (142, 34, 206, 66), INK, 22, True)
  center_text(draw, "10", (618, 34, 672, 66), INK, 21, True)

  center_text(draw, "丛林法则", (138, 184, 582, 270), INK, 52, True, 1, LIGHT)

  center_text(draw, "阵容 6/6", (126, 390, 306, 424), INK, 23, True, 1, LIGHT)
  center_text(draw, "战力 1280", (414, 390, 594, 424), INK, 23, True, 1, LIGHT)

  center_text(draw, "青铜一星  ·  胜 0 负 0", (170, 878, 550, 925), INK, 23, True)

  center_text(draw, "匹配", (214, 970, 506, 1050), INK, 42, True, 1, LIGHT)

  for rect, label in [
    ((20, 1200, 128, 1236), "商店"),
    ((166, 1200, 274, 1236), "编组"),
    ((310, 1200, 418, 1236), "战斗"),
    ((456, 1200, 564, 1236), "抽卡"),
    ((592, 1200, 700, 1236), "更多"),
  ]:
    center_text(draw, label, rect, INK, 21, True, 1, LIGHT)


def build() -> None:
  OUT.mkdir(parents=True, exist_ok=True)
  base = cover_resize(Image.open(SOURCE), (W, H))
  base.convert("RGB").save(BACKGROUND, quality=96)
  add_existing_animals(base)
  add_labels(base)
  base.convert("RGB").save(MOCKUP, quality=96)
  print(f"Wrote {BACKGROUND.relative_to(ROOT).as_posix()}")
  print(f"Wrote {MOCKUP.relative_to(ROOT).as_posix()}")


if __name__ == "__main__":
  build()
