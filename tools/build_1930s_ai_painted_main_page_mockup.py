from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "visual_concepts"
SOURCE = OUT / "current_game_1930s_v7_e_ai_painted_full_ui_base_with_icons.png"
DECK_SOURCE = OUT / "current_game_1930s_v10_h_deck_ui_base.png"
BACKGROUND = OUT / "current_game_1930s_v15_m_uiux_pixel_polish_lobby_background.png"
MOCKUP = OUT / "current_game_1930s_v15_m_uiux_pixel_polish_lobby_mockup.png"
W, H = 720, 1280

INK = (48, 30, 22, 255)
CREAM = (255, 241, 190, 255)
LIGHT = (255, 250, 222, 255)
BLUE = (42, 118, 145, 255)
RED = (185, 61, 46, 255)
GOLD = (205, 128, 30, 255)
NAV_CENTERS = (84, 222, 360, 498, 636)


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
  current_size = size
  fnt = font(current_size, bold)
  max_width = rect[2] - rect[0] - 8
  while current_size > 12 and text_size(draw, value, fnt)[0] > max_width:
    current_size -= 1
    fnt = font(current_size, bold)
  tw, th = text_size(draw, value, fnt)
  x = rect[0] + (rect[2] - rect[0] - tw) / 2
  y = rect[1] + (rect[3] - rect[1] - th) / 2 - 2
  draw.text((x, y), value, font=fnt, fill=fill, stroke_width=stroke_width, stroke_fill=stroke_fill)


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


def paste_status_strip(base: Image.Image, rect: tuple[int, int, int, int]) -> None:
  source = cover_resize(Image.open(DECK_SOURCE), (W, H))
  width = rect[2] - rect[0]
  height = rect[3] - rect[1]
  src_rect = (105, 469, 274, 527) if rect[0] < W // 2 else (307, 469, 452, 527)
  strip = nine_slice(source, src_rect, (width, height), (45, 10, 25, 10))
  mask = Image.new("L", (width, height), 0)
  md = ImageDraw.Draw(mask)
  md.ellipse((0, 1, height - 1, height - 1), fill=255)
  md.polygon(
    [(height // 2, 4), (width - 20, 4), (width - 3, height // 2), (width - 20, height - 4), (height // 2, height - 4)],
    fill=255,
  )
  base.paste(strip, (rect[0], rect[1]), mask)


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


def clean_lobby_background(base: Image.Image) -> Image.Image:
  clean = base.copy()
  for center_y in (592, 717):
    for center_x in (238, 361, 483):
      width, height = 90, 36
      source_rect = (
        center_x - width // 2,
        center_y - 62,
        center_x + width // 2,
        center_y - 62 + height,
      )
      patch = base.crop(source_rect)
      mask = Image.new("L", (width, height), 0)
      ImageDraw.Draw(mask).ellipse((0, 1, width - 1, height - 2), fill=255)
      clean.paste(patch, (center_x - width // 2, center_y - height // 2), mask.filter(ImageFilter.GaussianBlur(2.0)))
  return clean


def add_labels(base: Image.Image) -> None:
  draw = ImageDraw.Draw(base)
  # Center values inside the usable parchment area to the right of each icon.
  center_text(draw, "60", (103, 30, 222, 70), INK, 22, True)
  center_text(draw, "10", (554, 30, 678, 70), INK, 21, True)

  center_text(draw, "丛林法则", (138, 184, 582, 270), INK, 52, False, 1, LIGHT)

  for rect in ((130, 384, 306, 426), (414, 384, 590, 426)):
    paste_status_strip(base, rect)
  draw = ImageDraw.Draw(base)
  center_text(draw, "出战 6/6", (176, 388, 290, 423), INK, 17, True, 1, LIGHT)
  center_text(draw, "战力 1280", (460, 388, 574, 423), INK, 17, True, 1, LIGHT)

  center_text(draw, "青铜 1 星 · 胜 0 负 0", (170, 878, 550, 925), INK, 21, True)

  center_text(draw, "匹配", (214, 970, 506, 1050), INK, 42, False, 1, LIGHT)

  for rect, label in [
    ((20, 1200, 128, 1236), "商店"),
    ((166, 1200, 274, 1236), "编组"),
    ((310, 1200, 418, 1236), "战斗"),
    ((456, 1200, 564, 1236), "抽卡"),
    ((592, 1200, 700, 1236), "更多"),
  ]:
    center_text(draw, label, rect, RED if label == "战斗" else INK, 21, True, 1, LIGHT)
  draw.ellipse((352, 1250, 368, 1266), fill=INK)
  draw.ellipse((355, 1253, 365, 1263), fill=RED)
  draw.ellipse((358, 1255, 362, 1259), fill=(255, 226, 112, 255))


def build() -> None:
  OUT.mkdir(parents=True, exist_ok=True)
  base = cover_resize(Image.open(SOURCE), (W, H))
  clean_lobby_background(base).convert("RGB").save(BACKGROUND, quality=96)
  add_existing_animals(base)
  add_labels(base)
  base.convert("RGB").save(MOCKUP, quality=96)
  print(f"Wrote {BACKGROUND.relative_to(ROOT).as_posix()}")
  print(f"Wrote {MOCKUP.relative_to(ROOT).as_posix()}")


if __name__ == "__main__":
  build()
