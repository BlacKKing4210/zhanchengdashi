from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

import build_ue_locked_2d_art_options as ui


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "visual_concepts"
SOURCE = OUT / "current_game_1930s_v5_c_cheerful_fair_lobby_bg_source.png"
BACKGROUND = OUT / "current_game_1930s_v5_c_cheerful_fair_lobby_background.png"
MOCKUP = OUT / "current_game_1930s_v5_c_cheerful_fair_lobby_mockup.png"
W, H = 720, 1280


SKIN = ui.SkinOption(
  key="C",
  slug="cheerful_fair",
  title="轻欢游园",
  visual_sentence="阳光游园入口 + 手绘墨线 + 明亮复古 CTA。",
  summary="更轻松欢快的 1930s 手绘动画转译，适合主页面第一眼建立亲和力。",
  best_for="想要主界面更可爱、更明亮，但仍保留当前页面 UE 和小屏可读性。",
  risk="背景情绪很强，正式落地时要继续压住装饰密度，避免抢资源条和匹配按钮。",
  palette={
    "sky_top": (255, 226, 152, 255),
    "sky_bottom": (248, 191, 110, 255),
    "ground_top": (132, 196, 111, 255),
    "ground_bottom": (71, 139, 96, 255),
    "canopy": (29, 91, 74, 255),
    "canopy_light": (251, 204, 104, 255),
    "ink": (35, 24, 20, 255),
    "ink_soft": (82, 52, 43, 255),
    "panel": (45, 103, 136, 246),
    "panel_2": (214, 84, 68, 245),
    "panel_light": (255, 239, 190, 248),
    "panel_warm": (255, 221, 147, 248),
    "scene": (116, 190, 105, 238),
    "scene_2": (158, 216, 126, 232),
    "rank": (45, 94, 125, 250),
    "nav": (43, 85, 111, 250),
    "nav_active": (221, 76, 63, 255),
    "cta": (255, 194, 52, 255),
    "cta_2": (194, 78, 43, 255),
    "gold": (255, 215, 73, 255),
    "blue": (54, 161, 202, 255),
    "green": (101, 198, 98, 255),
    "red": (221, 77, 66, 255),
    "purple": (151, 82, 168, 255),
    "board_outer": (240, 159, 78, 255),
    "board_inner": (118, 190, 88, 236),
    "board_line": (74, 59, 43, 255),
    "tile_enemy": (221, 76, 67, 178),
    "tile_player": (78, 198, 104, 174),
    "tile_neutral": (244, 216, 145, 130),
    "text": (255, 249, 224, 255),
    "dark_text": (44, 29, 24, 255),
    "muted": (177, 139, 96, 255),
  },
)


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
  image = ImageEnhance.Color(image).enhance(1.04)
  image = ImageEnhance.Contrast(image).enhance(1.02)

  overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
  draw = ImageDraw.Draw(overlay)
  draw.rectangle((0, 0, W, 116), fill=(255, 244, 199, 34))
  draw.rectangle((0, 1130, W, H), fill=(28, 17, 15, 58))
  draw.rounded_rectangle((46, 136, 674, 838), radius=30, fill=(255, 239, 178, 26))
  image.alpha_composite(overlay)

  finish = Image.new("RGBA", (W, H), (0, 0, 0, 0))
  finish_draw = ImageDraw.Draw(finish)
  for y in range(0, H, 5):
    alpha = 7 if y % 20 == 0 else 3
    finish_draw.line((0, y, W, y), fill=(36, 24, 20, alpha), width=1)
  image.alpha_composite(finish.filter(ImageFilter.GaussianBlur(0.2)))

  BACKGROUND.parent.mkdir(parents=True, exist_ok=True)
  image.convert("RGB").save(BACKGROUND, quality=96)
  return image


def draw_flag(draw: ImageDraw.ImageDraw, x: int, y: int, color: ui.Color) -> None:
  ink = ui.p(SKIN, "ink")
  draw.line((x, y, x, y + 54), fill=ink, width=5)
  draw.line((x, y, x, y + 54), fill=(96, 72, 46, 255), width=2)
  draw.polygon([(x, y + 4), (x + 42, y + 14), (x, y + 27)], fill=color, outline=ink)


def draw_gate(draw: ImageDraw.ImageDraw, cx: int, cy: int) -> None:
  ink = ui.p(SKIN, "ink")
  cream = (255, 235, 180, 255)
  roof = ui.p(SKIN, "red")
  blue = ui.p(SKIN, "blue")
  draw.ellipse((cx - 118, cy + 62, cx + 118, cy + 91), fill=(0, 0, 0, 42))
  for dx in (-72, 72):
    draw.rounded_rectangle((cx + dx - 28, cy - 8, cx + dx + 28, cy + 75), radius=12, fill=cream, outline=ink, width=5)
    draw.polygon([(cx + dx - 36, cy - 5), (cx + dx, cy - 48), (cx + dx + 36, cy - 5)], fill=roof, outline=ink)
    draw.arc((cx + dx - 16, cy + 24, cx + dx + 16, cy + 56), 180, 360, fill=blue, width=5)
  draw.rounded_rectangle((cx - 72, cy + 8, cx + 72, cy + 78), radius=18, fill=(248, 204, 103, 255), outline=ink, width=6)
  draw.arc((cx - 34, cy + 18, cx + 34, cy + 92), 180, 360, fill=ink, width=6)
  draw.pieslice((cx - 30, cy + 24, cx + 30, cy + 92), 180, 360, fill=(92, 58, 34, 255), outline=ink)
  draw.rectangle((cx - 30, cy + 58, cx + 30, cy + 92), fill=(92, 58, 34, 255), outline=ink, width=4)
  draw_flag(draw, cx - 10, cy - 86, blue)


def draw_unit_token(
  draw: ImageDraw.ImageDraw,
  center: tuple[int, int],
  body: ui.Color,
  accent: ui.Color,
  ears: bool,
  horn: bool = False,
) -> None:
  x, y = center
  ink = ui.p(SKIN, "ink")
  draw.ellipse((x - 40, y + 36, x + 40, y + 52), fill=(0, 0, 0, 44))
  if ears:
    draw.ellipse((x - 43, y - 42, x - 15, y - 8), fill=body, outline=ink, width=4)
    draw.ellipse((x + 15, y - 42, x + 43, y - 8), fill=body, outline=ink, width=4)
    draw.ellipse((x - 35, y - 31, x - 22, y - 14), fill=accent)
    draw.ellipse((x + 22, y - 31, x + 35, y - 14), fill=accent)
  if horn:
    draw.polygon([(x - 10, y - 38), (x, y - 66), (x + 10, y - 38)], fill=(255, 232, 126, 255), outline=ink)
  draw.ellipse((x - 42, y - 36, x + 42, y + 46), fill=body, outline=ink, width=5)
  draw.ellipse((x - 20, y - 8, x - 7, y + 12), fill=(255, 255, 245, 255), outline=ink, width=3)
  draw.ellipse((x + 7, y - 8, x + 20, y + 12), fill=(255, 255, 245, 255), outline=ink, width=3)
  draw.ellipse((x - 13, y - 2, x - 7, y + 9), fill=ink)
  draw.ellipse((x + 14, y - 2, x + 20, y + 9), fill=ink)
  draw.arc((x - 18, y + 10, x + 18, y + 32), 15, 165, fill=ink, width=4)
  draw.ellipse((x - 6, y + 4, x + 6, y + 14), fill=accent, outline=ink, width=2)
  draw.line((x - 50, y - 1, x - 27, y + 3), fill=ink, width=2)
  draw.line((x + 27, y + 3, x + 50, y - 1), fill=ink, width=2)


def draw_building_token(draw: ImageDraw.ImageDraw, center: tuple[int, int], kind: str) -> None:
  x, y = center
  ink = ui.p(SKIN, "ink")
  draw.ellipse((x - 39, y + 34, x + 39, y + 49), fill=(0, 0, 0, 45))
  if kind == "mine":
    draw.rounded_rectangle((x - 33, y - 12, x + 33, y + 36), radius=9, fill=(126, 82, 45, 255), outline=ink, width=5)
    draw.polygon([(x - 42, y - 10), (x, y - 46), (x + 42, y - 10)], fill=ui.p(SKIN, "gold"), outline=ink)
    draw.ellipse((x - 14, y + 2, x + 14, y + 30), fill=(255, 239, 157, 255), outline=ink, width=3)
  else:
    draw.rounded_rectangle((x - 24, y - 20, x + 24, y + 40), radius=7, fill=(245, 224, 166, 255), outline=ink, width=5)
    draw.polygon([(x - 34, y - 18), (x, y - 54), (x + 34, y - 18)], fill=ui.p(SKIN, "blue"), outline=ink)
    draw.rectangle((x - 28, y + 12, x + 28, y + 26), fill=ui.p(SKIN, "red"), outline=ink, width=3)


def draw_cheerful_lobby_scene(image: Image.Image) -> None:
  draw = ImageDraw.Draw(image)
  scene = (58, 144, 662, 824)
  ui.panel(image, scene, ui.p(SKIN, "scene"), ui.p(SKIN, "ink"), radius=18, width=5, shadow=82)
  inner = (72, 158, 648, 810)
  draw.rounded_rectangle(inner, radius=13, fill=(163, 216, 125, 255))
  draw.rectangle((72, 158, 648, 312), fill=(255, 222, 148, 255))

  for index, color in enumerate([(114, 185, 121, 255), (92, 165, 112, 255), (73, 144, 100, 255)]):
    y = 258 + index * 58
    draw.ellipse((34, y, 686, y + 220), fill=color, outline=ui.p(SKIN, "ink"), width=3)

  draw.pieslice((190, 244, 530, 720), 200, 340, fill=(248, 220, 151, 255), outline=ui.p(SKIN, "ink"), width=4)
  for x in range(116, 626, 114):
    draw.line((x, 200, x + 26, 790), fill=(255, 255, 225, 64), width=2)
  for y in range(378, 742, 82):
    draw.arc((108, y, 612, y + 168), 205, 335, fill=(41, 92, 60, 158), width=4)

  draw_gate(draw, 360, 302)
  draw_building_token(draw, (248, 574), "mine")
  draw_building_token(draw, (456, 574), "tower")
  draw_unit_token(draw, (268, 458), (232, 104, 92, 255), (255, 229, 164, 255), True)
  draw_unit_token(draw, (452, 458), (94, 185, 111, 255), (255, 226, 89, 255), False, True)
  draw_unit_token(draw, (226, 672), (248, 229, 178, 255), (229, 87, 66, 255), True)
  draw_unit_token(draw, (360, 686), (85, 165, 198, 255), (255, 239, 194, 255), False)
  draw_unit_token(draw, (494, 672), (249, 171, 91, 255), (255, 240, 190, 255), True)

  for x, y, radius, color in [
    (112, 214, 9, ui.p(SKIN, "gold")),
    (604, 218, 8, ui.p(SKIN, "red")),
    (110, 760, 8, ui.p(SKIN, "blue")),
    (604, 760, 10, ui.p(SKIN, "gold")),
  ]:
    draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill=color, outline=ui.p(SKIN, "ink"), width=2)


def build() -> None:
  image = prepare_background()
  draw = ImageDraw.Draw(image)

  ui.draw_resource_bar(image, SKIN)
  ui.center_text(draw, "丛林法则", (40, 66, 680, 130), ui.p(SKIN, "text"), 46, True, (4, ui.p(SKIN, "ink")))
  draw_cheerful_lobby_scene(image)
  ui.draw_rank_panel(image, SKIN)
  ui.draw_cta(image, SKIN, (190, 958, 530, 1034), "匹配", True)
  ui.draw_nav(image, SKIN)

  image.convert("RGB").save(MOCKUP, quality=96)


def main() -> int:
  build()
  print(f"Wrote {BACKGROUND.relative_to(ROOT).as_posix()}")
  print(f"Wrote {MOCKUP.relative_to(ROOT).as_posix()}")
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
