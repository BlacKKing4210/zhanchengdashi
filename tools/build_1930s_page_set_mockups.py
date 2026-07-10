from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "visual_concepts"
MAIN_BASE = OUT / "current_game_1930s_v7_e_ai_painted_full_ui_base_with_icons.png"
DECK_BASE = OUT / "current_game_1930s_v10_h_deck_ui_base.png"
BATTLE_BASE = OUT / "current_game_1930s_v10_h_battle_ui_base.png"
MAIN_FINAL = OUT / "current_game_1930s_v9_g_ai_painted_clean_info_ui_lobby_mockup.png"
W, H = 720, 1280

INK = (48, 30, 22, 255)
LIGHT = (255, 250, 222, 255)
RED = (172, 55, 45, 255)
BLUE = (38, 112, 139, 255)
GOLD = (202, 128, 31, 255)
GREEN = (42, 115, 74, 255)
WHITE = (255, 255, 245, 255)


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
  fill: tuple[int, int, int, int] = INK,
  size: int = 24,
  bold: bool = False,
  stroke_width: int = 0,
  stroke_fill: tuple[int, int, int, int] = LIGHT,
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
  fnt = font(size, bold)
  text = value
  max_width = rect[2] - rect[0] - 8
  while text and text_size(draw, text, fnt)[0] > max_width:
    text = text[:-1]
  _, th = text_size(draw, text, fnt)
  y = rect[1] + (rect[3] - rect[1] - th) / 2 - 2
  draw.text((rect[0] + 4, y), text, font=fnt, fill=fill, stroke_width=stroke_width, stroke_fill=stroke_fill)


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
  sd.ellipse((center[0] - 35, center[1] + img.height // 2 - 12, center[0] + 35, center[1] + img.height // 2 + 4), fill=(0, 0, 0, 45))
  base.alpha_composite(shadow)
  paste_center(base, img, center)


def add_top_values(draw: ImageDraw.ImageDraw, extra: bool = False) -> None:
  center_text(draw, "60", (142, 34, 206, 66), INK, 22, True)
  center_text(draw, "10", (618, 34, 672, 66), INK, 21, True)
  if extra:
    center_text(draw, "0", (314, 34, 356, 66), INK, 18, True)
    center_text(draw, "12", (468, 34, 516, 66), INK, 18, True)


def add_bottom_nav(draw: ImageDraw.ImageDraw, active: str) -> None:
  labels = [
    ((20, 1200, 128, 1236), "商店"),
    ((166, 1200, 274, 1236), "编组"),
    ((310, 1200, 418, 1236), "战斗"),
    ((456, 1200, 564, 1236), "抽卡"),
    ((592, 1200, 700, 1236), "更多"),
  ]
  for rect, label in labels:
    fill = RED if label == active else INK
    center_text(draw, label, rect, fill, 21, True, 1, LIGHT)


def card_frame(source: Image.Image, rect: tuple[int, int, int, int], size: tuple[int, int]) -> Image.Image:
  return source.crop(rect).resize(size, Image.Resampling.LANCZOS)


def add_card_content(base: Image.Image, name: str, rect: tuple[int, int, int, int], title: str, line: str) -> None:
  draw = ImageDraw.Draw(base)
  paste_animal(base, name, ((rect[0] + rect[2]) // 2, rect[1] + 58), (76, 76))
  center_text(draw, title, (rect[0] + 8, rect[3] - 62, rect[2] - 8, rect[3] - 34), INK, 16, True, 1, LIGHT)
  center_text(draw, line, (rect[0] + 8, rect[3] - 36, rect[2] - 8, rect[3] - 12), GOLD, 13, True, 1, LIGHT)


def build_lobby() -> Path:
  # Main page already has its own tuned builder; keep output for set consistency.
  return OUT / "current_game_1930s_v9_g_ai_painted_clean_info_ui_lobby_mockup.png"


def build_deck() -> Path:
  base = load_base(DECK_BASE)
  draw = ImageDraw.Draw(base)
  add_top_values(draw)
  center_text(draw, "编组", (138, 184, 582, 270), INK, 52, True, 1, LIGHT)
  center_text(draw, "出战 6/6  ·  战力 1280", (126, 300, 594, 346), INK, 24, True, 1, LIGHT)

  slots = [
    ("mouse", (160, 346), "Lv.1 老鼠", "近战"),
    ("frog", (360, 346), "Lv.1 青蛙", "远程"),
    ("rabbit", (560, 346), "Lv.1 兔子", "速攻"),
    ("chicken", (160, 570), "Lv.1 鸡", "召唤"),
    ("cat", (360, 570), "Lv.1 猫", "突袭"),
    ("dog", (560, 570), "Lv.1 狗", "守护"),
  ]
  for name, center, title, line in slots:
    paste_animal(base, name, center, (112, 112))
    center_text(draw, title, (center[0] - 82, center[1] + 80, center[0] + 82, center[1] + 118), INK, 18, True, 1, LIGHT)
    center_text(draw, line, (center[0] - 58, center[1] + 114, center[0] + 58, center[1] + 144), GOLD, 16, True, 1, LIGHT)

  center_text(draw, "卡牌收藏", (92, 794, 628, 834), INK, 28, True, 1, LIGHT)
  collection = [
    ("bear", "熊", "未上阵"),
    ("fox", "狐", "可替换"),
    ("wolf", "狼", "碎片 3/10"),
    ("deer", "鹿", "可升级"),
    ("duck", "鸭", "未拥有"),
  ]
  x_positions = [116, 238, 360, 482, 604]
  for (name, title, line), x in zip(collection, x_positions, strict=True):
    paste_animal(base, name, (x, 914), (82, 82))
    center_text(draw, title, (x - 44, 972, x + 44, 1000), INK, 17, True, 1, LIGHT)
    center_text(draw, line, (x - 58, 998, x + 58, 1028), GOLD, 13, True, 1, LIGHT)
  add_bottom_nav(draw, "编组")
  path = OUT / "current_game_1930s_v10_h_deck_page_mockup.png"
  base.convert("RGB").save(path, quality=96)
  return path


def build_battle() -> Path:
  base = load_base(BATTLE_BASE)
  draw = ImageDraw.Draw(base)
  add_top_values(draw, True)
  center_text(draw, "青铜一星  VS  青铜一星", (172, 146, 548, 200), INK, 23, True, 1, LIGHT)
  center_text(draw, "01:30", (312, 222, 408, 266), INK, 25, True, 1, LIGHT)
  center_text(draw, "暂停", (626, 146, 688, 218), INK, 16, True, 1, LIGHT)

  paste_animal(base, "rabbit", (214, 714), (58, 58))
  paste_animal(base, "cat", (357, 794), (58, 58))
  paste_animal(base, "dog", (506, 724), (60, 60))
  paste_animal(base, "frog", (362, 514), (58, 58))
  paste_animal(base, "mouse", (206, 488), (54, 54))

  center_text(draw, "可解锁地块", (250, 968, 486, 1018), INK, 27, True, 1, LIGHT)
  center_text(draw, "动物营地  ·  花费 50", (250, 1030, 488, 1076), INK, 22, True, 1, LIGHT)
  center_text(draw, "普通动物，随机品质", (250, 1094, 512, 1134), GOLD, 18, True, 1, LIGHT)
  path = OUT / "current_game_1930s_v10_h_battle_page_mockup.png"
  base.convert("RGB").save(path, quality=96)
  return path


def make_component_page(title: str, active: str) -> Image.Image:
  base = load_base(MAIN_BASE)
  draw = ImageDraw.Draw(base)
  add_top_values(draw)
  center_text(draw, title, (138, 184, 582, 270), INK, 52, True, 1, LIGHT)
  add_bottom_nav(draw, active)
  return base


def build_gacha() -> Path:
  base = load_base(DECK_BASE)
  draw = ImageDraw.Draw(base)
  add_top_values(draw)
  center_text(draw, "抽卡", (138, 184, 582, 270), INK, 52, True, 1, LIGHT)
  center_text(draw, "今日招募", (222, 300, 498, 346), INK, 28, True, 1, LIGHT)
  for center in [(160, 430), (360, 430), (560, 430), (160, 654), (360, 654), (560, 654)]:
    center_text(draw, "?", (center[0] - 48, center[1] - 54, center[0] + 48, center[1] + 20), GOLD, 44, True, 1, LIGHT)
  center_text(draw, "最近获得", (92, 794, 628, 834), INK, 28, True, 1, LIGHT)
  for name, x in zip(["rabbit", "frog", "cat", "dog"], [146, 286, 426, 566], strict=True):
    paste_animal(base, name, (x, 936), (86, 86))
  center_text(draw, "抽1次", (174, 1070, 320, 1130), INK, 27, True, 1, LIGHT)
  center_text(draw, "抽10次", (398, 1070, 560, 1130), INK, 27, True, 1, LIGHT)
  add_bottom_nav(draw, "抽卡")
  path = OUT / "current_game_1930s_v10_h_gacha_page_mockup.png"
  base.convert("RGB").save(path, quality=96)
  return path


def build_shop() -> Path:
  base = load_base(DECK_BASE)
  draw = ImageDraw.Draw(base)
  add_top_values(draw)
  center_text(draw, "商店", (138, 184, 582, 270), INK, 52, True, 1, LIGHT)
  center_text(draw, "今日推荐", (126, 300, 594, 346), INK, 28, True, 1, LIGHT)
  items = [
    ("每日金币", "免费", (160, 430)),
    ("招募券包", "120", (360, 430)),
    ("新手补给", "300", (560, 430)),
    ("动物碎片", "80", (160, 654)),
    ("稀有礼包", "680", (360, 654)),
    ("刷新商店", "20", (560, 654)),
  ]
  for title, price, center in items:
    center_text(draw, title, (center[0] - 74, center[1] - 30, center[0] + 74, center[1] + 20), INK, 20, True, 1, LIGHT)
    center_text(draw, price, (center[0] - 52, center[1] + 36, center[0] + 52, center[1] + 74), GOLD, 20, True, 1, LIGHT)
  center_text(draw, "限时礼包", (92, 794, 628, 834), INK, 28, True, 1, LIGHT)
  for title, price, x in [("金币箱", "300", 160), ("券箱", "5", 360), ("刷新", "20", 560)]:
    center_text(draw, title, (x - 70, 900, x + 70, 938), INK, 18, True, 1, LIGHT)
    center_text(draw, price, (x - 52, 950, x + 52, 988), GOLD, 18, True, 1, LIGHT)
  add_bottom_nav(draw, "商店")
  path = OUT / "current_game_1930s_v10_h_shop_page_mockup.png"
  base.convert("RGB").save(path, quality=96)
  return path


def build_more() -> Path:
  base = make_component_page("任务", "更多")
  draw = ImageDraw.Draw(base)
  tasks = [
    ("每日登录", "奖励 20 金币", "完成"),
    ("赢得 1 场战斗", "奖励 1 招募券", "0/1"),
    ("升级 1 张卡牌", "奖励 50 金币", "0/1"),
    ("解锁 3 个地块", "奖励 30 金币", "1/3"),
  ]
  y = 376
  for title, reward, state in tasks:
    center_text(draw, title, (120, y, 400, y + 42), INK, 24, True, 1, LIGHT)
    center_text(draw, reward, (136, y + 42, 426, y + 78), GOLD, 17, True, 1, LIGHT)
    center_text(draw, state, (482, y + 18, 620, y + 72), RED if state == "完成" else INK, 20, True, 1, LIGHT)
    y += 132
  center_text(draw, "设置", (122, 912, 274, 980), INK, 24, True, 1, LIGHT)
  center_text(draw, "公告", (284, 912, 436, 980), INK, 24, True, 1, LIGHT)
  center_text(draw, "邮件", (446, 912, 598, 980), INK, 24, True, 1, LIGHT)
  path = OUT / "current_game_1930s_v10_h_more_tasks_page_mockup.png"
  base.convert("RGB").save(path, quality=96)
  return path


def build_popup_sheet() -> Path:
  base = load_base(MAIN_BASE)
  overlay = Image.new("RGBA", base.size, (20, 12, 8, 124))
  base.alpha_composite(overlay)
  draw = ImageDraw.Draw(base)
  source = load_base(DECK_BASE)
  frame_big = card_frame(source, (96, 324, 629, 728), (520, 278))
  panels = [
    ("卡牌详情", "Lv.1 青蛙 · 攻击 12 · 生命 90", "碎片 3/10    升级 50", (100, 160)),
    ("战斗胜利", "奖励 +1 招募券", "点击任意位置返回", (100, 470)),
    ("确认购买", "招募券包  ·  花费 120", "取消        购买", (100, 780)),
  ]
  for title, line1, line2, pos in panels:
    base.alpha_composite(frame_big, pos)
    center_text(draw, title, (pos[0] + 30, pos[1] + 28, pos[0] + 490, pos[1] + 78), INK, 34, True, 1, LIGHT)
    center_text(draw, line1, (pos[0] + 42, pos[1] + 112, pos[0] + 478, pos[1] + 160), INK, 23, True, 1, LIGHT)
    center_text(draw, line2, (pos[0] + 42, pos[1] + 176, pos[0] + 478, pos[1] + 230), GOLD, 22, True, 1, LIGHT)
  paste_animal(base, "frog", (190, 320), (100, 100))
  path = OUT / "current_game_1930s_v10_h_popup_sheet_mockup.png"
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
  center_text(draw, "1930s 手绘 UI 页面效果图套件", (0, 20, 920, 72), INK, 36, True)
  labels = ["主页面", "编组页", "战斗页", "抽卡页", "商店页", "任务页", "弹窗合集"]
  for i, ((_, img), label) in enumerate(zip(thumbs, labels, strict=True)):
    col = i % 3
    row = i // 3
    x = 34 + col * 296
    y = 100 + row * 620
    sheet.paste(img, (x, y))
    center_text(draw, label, (x, y + img.height + 14, x + img.width, y + img.height + 54), INK, 22, True)
  path = OUT / "current_game_1930s_v10_h_page_set_overview.png"
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
