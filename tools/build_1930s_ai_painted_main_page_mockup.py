from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "visual_concepts"
SOURCE = OUT / "current_game_1930s_v7_e_ai_painted_full_ui_base_with_icons.png"
BACKGROUND = OUT / "current_game_1930s_v8_f_ai_painted_info_ui_background.png"
MOCKUP = OUT / "current_game_1930s_v8_f_ai_painted_info_ui_lobby_mockup.png"
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
  center_text(draw, "金币 60", (92, 34, 206, 66), INK, 18, True)
  center_text(draw, "招募券 10", (566, 34, 686, 66), INK, 16, True)

  center_text(draw, "丛林法则", (138, 176, 582, 242), INK, 48, True, 1, LIGHT)
  center_text(draw, "动物卡牌 · 占地自动战斗", (166, 236, 554, 275), GOLD, 20, True, 1, LIGHT)

  center_text(draw, "当前阵容 6/6", (116, 390, 296, 424), INK, 21, True, 1, LIGHT)
  center_text(draw, "总战力 1280", (424, 390, 604, 424), INK, 21, True, 1, LIGHT)

  center_text(draw, "青铜一星 · 胜 0 负 0 · 段位赛", (152, 878, 568, 925), INK, 21, True)
  center_text(draw, "首胜奖励", (540, 896, 650, 926), RED, 14, True, 1, LIGHT)

  center_text(draw, "匹配", (214, 970, 506, 1028), INK, 38, True, 1, LIGHT)
  center_text(draw, "预计 15 秒 · 免费", (214, 1018, 506, 1055), RED, 18, True, 1, LIGHT)

  for rect, label, sub in [
    ((20, 1192, 128, 1250), "商店", "上新"),
    ((166, 1192, 274, 1250), "编组", "6/6"),
    ((310, 1192, 418, 1250), "战斗", "当前"),
    ((456, 1192, 564, 1250), "抽卡", "免费"),
    ((592, 1192, 700, 1250), "更多", "任务"),
  ]:
    center_text(draw, label, (rect[0], rect[1], rect[2], rect[1] + 34), INK, 20, True)
    center_text(draw, sub, (rect[0], rect[1] + 28, rect[2], rect[3]), RED if sub in {"上新", "免费", "当前"} else GOLD, 12, True, 1, LIGHT)


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
