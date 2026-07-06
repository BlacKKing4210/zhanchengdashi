from __future__ import annotations

from dataclasses import dataclass
from datetime import date
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter

import build_ue_locked_2d_art_options as ui


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "visual_concepts"
DOC = ROOT / "docs" / "CURRENT_GAME_1930S_PAGE_STYLE_OPTIONS.md"
W, H = 720, 1280
PREFIX = "current_game_1930s_v4"


@dataclass(frozen=True)
class Option:
  key: str
  slug: str
  title: str
  visual_sentence: str
  summary: str
  best_for: str
  risk: str
  lobby_source: str
  battle_source: str
  skin: ui.SkinOption
  bg_color: tuple[int, int, int]


OPTIONS = [
  Option(
    key="A",
    slug="classic_cel",
    title="经典赛璐璐",
    visual_sentence="暖纸胶片森林 + 黑墨线 UI + 金色 CTA。",
    summary="最接近 1930s 手绘动画短片的原创转译，画面高级、复古、克制。",
    best_for="想要更强艺术辨识度，同时保持当前页面信息完全不变。",
    risk="色彩较克制，后续需要用按钮高光和地块描边保护奖励感。",
    lobby_source="current_game_1930s_v4_a_lobby_bg_source.png",
    battle_source="current_game_1930s_v4_a_battle_bg_source.png",
    bg_color=(241, 225, 178),
    skin=ui.SkinOption(
      key="A",
      slug="classic_cel",
      title="经典赛璐璐",
      visual_sentence="暖纸胶片森林 + 黑墨线 UI + 金色 CTA。",
      summary="最接近 1930s 手绘动画短片的原创转译，画面高级、复古、克制。",
      best_for="想要更强艺术辨识度，同时保持当前页面信息完全不变。",
      risk="色彩较克制，后续需要用按钮高光和地块描边保护奖励感。",
      palette={
        "sky_top": (236, 219, 168, 255),
        "sky_bottom": (194, 179, 128, 255),
        "ground_top": (149, 165, 111, 255),
        "ground_bottom": (80, 103, 72, 255),
        "canopy": (41, 63, 47, 255),
        "canopy_light": (191, 177, 122, 255),
        "ink": (25, 19, 16, 255),
        "ink_soft": (59, 45, 34, 255),
        "panel": (54, 48, 40, 246),
        "panel_2": (102, 92, 69, 245),
        "panel_light": (245, 232, 185, 248),
        "panel_warm": (241, 213, 142, 248),
        "scene": (166, 184, 125, 240),
        "scene_2": (190, 201, 144, 232),
        "rank": (51, 45, 38, 250),
        "nav": (43, 37, 33, 250),
        "nav_active": (44, 123, 137, 255),
        "cta": (245, 184, 57, 255),
        "cta_2": (160, 69, 38, 255),
        "gold": (248, 202, 72, 255),
        "blue": (54, 139, 160, 255),
        "green": (97, 161, 84, 255),
        "red": (190, 74, 59, 255),
        "purple": (127, 85, 142, 255),
        "board_outer": (230, 207, 142, 255),
        "board_inner": (145, 165, 104, 235),
        "board_line": (51, 58, 38, 255),
        "tile_enemy": (187, 73, 65, 178),
        "tile_player": (89, 156, 91, 174),
        "tile_neutral": (222, 204, 151, 130),
        "text": (255, 249, 226, 255),
        "dark_text": (33, 25, 18, 255),
        "muted": (158, 148, 111, 255),
      },
    ),
  ),
  Option(
    key="B",
    slug="fairground_poster",
    title="游园海报",
    visual_sentence="亮盒彩印游园 + 红蓝错版边 + 剧场感棋盘。",
    summary="更明亮、更漂亮、更适合商业化主界面，仍保持手绘墨线和复古动画气质。",
    best_for="想要更美观、更有奖励感，后续方便接活动、赛季和礼包包装。",
    risk="装饰更强，落地时要控制饱和度，不让背景抢棋盘和资源条。",
    lobby_source="current_game_1930s_v4_b_lobby_bg_source.png",
    battle_source="current_game_1930s_v4_b_battle_bg_source.png",
    bg_color=(247, 227, 179),
    skin=ui.SkinOption(
      key="B",
      slug="fairground_poster",
      title="游园海报",
      visual_sentence="亮盒彩印游园 + 红蓝错版边 + 剧场感棋盘。",
      summary="更明亮、更漂亮、更适合商业化主界面，仍保持手绘墨线和复古动画气质。",
      best_for="想要更美观、更有奖励感，后续方便接活动、赛季和礼包包装。",
      risk="装饰更强，落地时要控制饱和度，不让背景抢棋盘和资源条。",
      palette={
        "sky_top": (255, 221, 143, 255),
        "sky_bottom": (234, 145, 94, 255),
        "ground_top": (96, 183, 127, 255),
        "ground_bottom": (41, 118, 96, 255),
        "canopy": (22, 92, 80, 255),
        "canopy_light": (252, 194, 96, 255),
        "ink": (35, 24, 27, 255),
        "ink_soft": (81, 50, 46, 255),
        "panel": (40, 91, 127, 246),
        "panel_2": (206, 78, 67, 245),
        "panel_light": (255, 237, 185, 248),
        "panel_warm": (255, 219, 144, 248),
        "scene": (101, 185, 118, 238),
        "scene_2": (148, 211, 118, 232),
        "rank": (40, 88, 122, 250),
        "nav": (43, 82, 112, 250),
        "nav_active": (219, 72, 62, 255),
        "cta": (255, 190, 54, 255),
        "cta_2": (192, 56, 43, 255),
        "gold": (255, 215, 74, 255),
        "blue": (42, 151, 190, 255),
        "green": (88, 196, 99, 255),
        "red": (221, 74, 67, 255),
        "purple": (145, 76, 171, 255),
        "board_outer": (239, 154, 74, 255),
        "board_inner": (113, 190, 87, 236),
        "board_line": (73, 59, 42, 255),
        "tile_enemy": (221, 76, 67, 178),
        "tile_player": (74, 196, 104, 174),
        "tile_neutral": (242, 211, 139, 130),
        "text": (255, 249, 222, 255),
        "dark_text": (43, 28, 27, 255),
        "muted": (170, 131, 93, 255),
      },
    ),
  ),
]


def rel(path: Path) -> str:
  return path.relative_to(ROOT).as_posix()


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


def prepare_background(option: Option, source_name: str, page: str) -> Path:
  src = OUT / source_name
  image = cover_resize(Image.open(src), (W, H))
  image = ImageEnhance.Color(image).enhance(0.96 if option.key == "A" else 1.04)
  image = ImageEnhance.Contrast(image).enhance(1.04)

  overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
  draw = ImageDraw.Draw(overlay)
  draw.rectangle((0, 0, W, 108), fill=(255, 246, 207, 28))
  draw.rectangle((0, 1130, W, H), fill=(20, 13, 12, 55))
  if page == "battle":
    draw.rounded_rectangle((44, 76, 676, 1124), radius=28, fill=(255, 244, 190, 32))
  else:
    draw.rounded_rectangle((50, 138, 670, 838), radius=28, fill=(255, 244, 190, 24))
  image.alpha_composite(overlay)

  path = OUT / f"{PREFIX}_{option.key.lower()}_{option.slug}_{page}_background.png"
  image.convert("RGB").save(path, quality=96)
  return path


def add_print_finish(image: Image.Image, option: Option) -> None:
  width, height = image.size
  overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
  draw = ImageDraw.Draw(overlay)
  for y in range(0, height, 5):
    alpha = 8 if y % 20 == 0 else 3
    draw.line((0, y, width, y), fill=(32, 22, 18, alpha), width=1)
  for x in range(0, width, 160):
    draw.line((x, 0, x + 9, height), fill=(255, 245, 201, 8), width=1)
  image.alpha_composite(overlay)
  if option.key == "B":
    edge = image.convert("L").filter(ImageFilter.FIND_EDGES).point(lambda p: 24 if p > 42 else 0)
    red = Image.new("RGBA", image.size, (210, 56, 48, 0))
    blue = Image.new("RGBA", image.size, (48, 141, 184, 0))
    red.putalpha(edge)
    blue.putalpha(edge)
    image.alpha_composite(red, (1, 0))
    image.alpha_composite(blue, (-1, 1))


def draw_lobby(option: Option, bg_path: Path) -> Path:
  image = Image.open(bg_path).convert("RGBA")
  skin = option.skin
  draw = ImageDraw.Draw(image)
  ui.draw_resource_bar(image, skin)
  ui.center_text(draw, "丛林法则", (40, 66, 680, 130), ui.p(skin, "text"), 46, True, (4, ui.p(skin, "ink")))
  ui.draw_lobby_scene(image, skin)
  ui.draw_rank_panel(image, skin)
  ui.draw_cta(image, skin, (190, 958, 530, 1034), "匹配", True)
  ui.draw_nav(image, skin)
  add_print_finish(image, option)
  path = OUT / f"{PREFIX}_{option.key.lower()}_{option.slug}_lobby_mockup.png"
  image.convert("RGB").save(path, quality=96)
  return path


def draw_battle(option: Option, bg_path: Path) -> Path:
  image = Image.open(bg_path).convert("RGBA")
  skin = option.skin
  ui.draw_resource_bar(image, skin)
  ui.draw_match_status(image, skin)
  ui.draw_battle_board(image, skin)
  ui.draw_selection_panel(image, skin)
  ui.draw_pause_button(image, skin)
  add_print_finish(image, option)
  path = OUT / f"{PREFIX}_{option.key.lower()}_{option.slug}_battle_mockup.png"
  image.convert("RGB").save(path, quality=96)
  return path


def draw_sheet(option: Option, lobby: Path, battle: Path, lobby_bg: Path, battle_bg: Path) -> Path:
  sheet = Image.new("RGB", (1520, 1750), option.bg_color)
  image = sheet.convert("RGBA")
  draw = ImageDraw.Draw(image)
  ink = (35, 24, 20, 255)
  ui.center_text(draw, f"方案 {option.key}：{option.title}", (0, 18, 1520, 72), ink, 36, True)
  ui.center_text(draw, option.visual_sentence, (0, 74, 1520, 108), (85, 62, 45, 255), 21, False)
  ui.center_text(draw, "当前页面基础：主页面/战场 UE 不变；新增每页背景底图；原创 1930s 手绘动画风格，不复制茶杯头元素。", (0, 108, 1520, 134), (88, 72, 54, 255), 17, False)
  image.alpha_composite(Image.open(lobby).convert("RGBA"), (28, 150))
  image.alpha_composite(Image.open(battle).convert("RGBA"), (772, 150))
  ui.center_text(draw, "主页面效果图", (28, 1444, 748, 1476), ink, 24, True)
  ui.center_text(draw, "战场效果图", (772, 1444, 1492, 1476), ink, 24, True)
  y = 1492
  ui.left_text(draw, f"定位：{option.summary}", (64, y, 1456, y + 28), ink, 18)
  ui.left_text(draw, f"适合：{option.best_for}", (64, y + 30, 1456, y + 58), ink, 18)
  ui.left_text(draw, f"风险：{option.risk}", (64, y + 60, 1456, y + 88), ink, 18)
  ui.left_text(draw, f"主页面背景底图：{rel(lobby_bg)}", (64, y + 96, 1456, y + 124), ink, 17)
  ui.left_text(draw, f"战场背景底图：{rel(battle_bg)}", (64, y + 124, 1456, y + 152), ink, 17)
  add_print_finish(image, option)
  path = OUT / f"{PREFIX}_{option.key.lower()}_{option.slug}_sheet.png"
  image.convert("RGB").save(path, quality=96)
  return path


def build() -> dict[str, dict[str, Path]]:
  OUT.mkdir(parents=True, exist_ok=True)
  outputs: dict[str, dict[str, Path]] = {}
  for option in OPTIONS:
    lobby_bg = prepare_background(option, option.lobby_source, "lobby")
    battle_bg = prepare_background(option, option.battle_source, "battle")
    lobby = draw_lobby(option, lobby_bg)
    battle = draw_battle(option, battle_bg)
    sheet = draw_sheet(option, lobby, battle, lobby_bg, battle_bg)
    outputs[option.key] = {
      "lobby_bg": lobby_bg,
      "battle_bg": battle_bg,
      "lobby": lobby,
      "battle": battle,
      "sheet": sheet,
    }
  return outputs


def write_doc(outputs: dict[str, dict[str, Path]]) -> None:
  lines = [
    "# 当前页面 1930s 手绘动画美术方案",
    "",
    f"生成日期：{date.today().isoformat()}",
    "",
    "本轮忽略之前的设计，从当前正在使用的主页面和战场页出发，只做设计评审图，不应用到游戏里。",
    "",
    "风格学习范围：转译 1930s 橡皮管动画、手绘赛璐璐、胶片颗粒、复古海报印刷与墨线质感；不复制茶杯头角色、Logo、专有造型、关卡或 UI。",
    "",
    "## 硬性要求",
    "",
    "- 主页面和战场都生成独立背景底图。",
    "- 当前页面信息、布局、控件位置、点击区域和点击反馈不变。",
    "- 效果图只展示美术升级方向，不进入 Godot 实装。",
    "",
    "## 方案总览",
    "",
    "| 方案 | 名称 | 视觉句子 | 定位 | 主页面背景 | 战场背景 | 总览图 |",
    "| --- | --- | --- | --- | --- | --- | --- |",
  ]
  for option in OPTIONS:
    group = outputs[option.key]
    lines.append(
      f"| {option.key} | {option.title} | {option.visual_sentence} | {option.summary} | `{rel(group['lobby_bg'])}` | `{rel(group['battle_bg'])}` | `{rel(group['sheet'])}` |"
    )
  for option in OPTIONS:
    group = outputs[option.key]
    lines.extend(
      [
        "",
        f"## 方案 {option.key}：{option.title}",
        "",
        f"![方案 {option.key}：{option.title}](../{rel(group['sheet'])})",
        "",
        f"- 视觉句子：{option.visual_sentence}",
        f"- 定位：{option.summary}",
        f"- 适合：{option.best_for}",
        f"- 风险：{option.risk}",
        f"- 主页面背景底图：`{rel(group['lobby_bg'])}`",
        f"- 战场背景底图：`{rel(group['battle_bg'])}`",
        f"- 主页面效果图：`{rel(group['lobby'])}`",
        f"- 战场效果图：`{rel(group['battle'])}`",
      ]
    )
  lines.extend(
    [
      "",
      "## 初步建议",
      "",
      "1. 选 A：如果你想要最有艺术辨识度、最高级、最克制的复古动画质感。",
      "2. 选 B：如果你想要更亮、更美、更商业化、更适合后续活动包装。",
      "",
      "我建议优先看 B 是否符合你想要的“美观度”，如果觉得过热闹，再回到 A 的高级克制路线。",
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
