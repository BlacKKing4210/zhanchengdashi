#!/usr/bin/env python3
"""Build deterministic review boards for the universal animal motion FX proposal.

Visible FX shapes come from ImageGen atlases. This script only removes visual
drift from those sources, applies the approved review palette, and composites
the unchanged project animal PNGs into current 720x1280 / 7x13 battle geometry.
It does not create runtime assets or modify Godot files.
"""

from __future__ import annotations

import math
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "output" / "visual_concepts"
ANIMALS = ROOT / "assets" / "card_art" / "animals"

INK = "#24211D"
PAPER = "#F7E6B5"
HIT = "#D9543D"
POWER = "#F2C14E"
GAIN = "#2D8C7A"
MOTION = "#4E9BC4"
FX_PALETTE = [INK, PAPER, HIT, POWER, GAIN, MOTION]

OPTION_META = {
    "a": ("A", "弹性墨线动作", "推荐：动作与遮挡最平衡"),
    "b": ("B", "粗笔战斗印章", "强反馈：小屏最醒目"),
    "c": ("C", "克制舞台轨迹", "低干扰：适合减弱动效"),
}

ACTIONS = [
    {
        "id": "attack",
        "title": "攻击",
        "phases": "蓄力  ·  接触  ·  复位",
        "time": "0.24s",
        "animal": "wolf.png",
    },
    {
        "id": "hit",
        "title": "受击",
        "phases": "受击前  ·  命中  ·  复位",
        "time": "0.16s",
        "animal": "bear.png",
    },
    {
        "id": "move",
        "title": "移动",
        "phases": "左步  ·  右步  ·  循环",
        "time": "0.32s",
        "animal": "rabbit.png",
    },
    {
        "id": "stat",
        "title": "获得属性",
        "phases": "触发  ·  上升  ·  淡出",
        "time": "0.55s",
        "animal": "turtle.png",
    },
    {
        "id": "power",
        "title": "获得提升",
        "phases": "蓄势  ·  确认  ·  回弹",
        "time": "0.68s",
        "animal": "eagle.png",
    },
    {
        "id": "death",
        "title": "死亡",
        "phases": "存活  ·  倾倒  ·  消散",
        "time": "0.42s",
        "animal": "mouse.png",
    },
]


def rgb(hex_color: str) -> tuple[int, int, int]:
    value = hex_color.removeprefix("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def rgba(hex_color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    return (*rgb(hex_color), alpha)


def mix_color(base: str, overlay: str, amount: float) -> tuple[int, int, int, int]:
    base_rgb = rgb(base)
    overlay_rgb = rgb(overlay)
    mixed = tuple(
        round(base_rgb[index] * (1.0 - amount) + overlay_rgb[index] * amount)
        for index in range(3)
    )
    return (*mixed, 255)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        Path("C:/Windows/Fonts/msyhbd.ttc" if bold else "C:/Windows/Fonts/msyh.ttc"),
        Path("C:/Windows/Fonts/simhei.ttf"),
        Path("C:/Windows/Fonts/arial.ttf"),
    ]
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size=size)
    return ImageFont.load_default()


def alpha_composite_at(canvas: Image.Image, layer: Image.Image, xy: tuple[int, int]) -> None:
    canvas.alpha_composite(layer, dest=(int(xy[0]), int(xy[1])))


def flatten_fx_palette(image: Image.Image) -> Image.Image:
    source = image.convert("RGBA")
    palette_image = Image.new("P", (1, 1))
    colors: list[int] = []
    for color in FX_PALETTE:
        colors.extend(rgb(color))
    colors.extend(list(rgb(FX_PALETTE[-1])) * (256 - len(FX_PALETTE)))
    palette_image.putpalette(colors)
    quantized_rgb = source.convert("RGB").quantize(
        palette=palette_image,
        dither=Image.Dither.NONE,
    ).convert("RGB")
    quantized_rgb = quantized_rgb.filter(ImageFilter.ModeFilter(size=5))
    quantized_rgb = quantized_rgb.quantize(
        palette=palette_image,
        dither=Image.Dither.NONE,
    ).convert("RGB")
    quantized = quantized_rgb.convert("RGBA")
    quantized.putalpha(source.getchannel("A"))
    return quantized


def split_atlas(atlas: Image.Image) -> list[Image.Image]:
    cells: list[Image.Image] = []
    for row in range(2):
        y0 = round(row * atlas.height / 2)
        y1 = round((row + 1) * atlas.height / 2)
        for col in range(3):
            x0 = round(col * atlas.width / 3)
            x1 = round((col + 1) * atlas.width / 3)
            cell = atlas.crop((x0, y0, x1, y1))
            bbox = cell.getchannel("A").getbbox()
            if bbox:
                cell = cell.crop(bbox)
            cells.append(cell)
    return cells


def contain(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    layer = image.copy()
    layer.thumbnail(size, Image.Resampling.LANCZOS)
    return layer


def set_opacity(image: Image.Image, opacity: float) -> Image.Image:
    result = image.copy().convert("RGBA")
    alpha = result.getchannel("A").point(lambda value: round(value * opacity))
    result.putalpha(alpha)
    return result


def tint_toward(image: Image.Image, target: str, amount: float) -> Image.Image:
    source = image.convert("RGBA")
    solid = Image.new("RGBA", source.size, rgba(target))
    mixed = Image.blend(source, solid, amount)
    mixed.putalpha(source.getchannel("A"))
    return mixed


def pose_image(
    animal: Image.Image,
    nominal_size: int,
    scale: tuple[float, float] = (1.0, 1.0),
    rotation: float = 0.0,
    tint: tuple[str, float] | None = None,
    opacity: float = 1.0,
) -> Image.Image:
    base = animal.convert("RGBA").resize(
        (nominal_size, nominal_size), Image.Resampling.LANCZOS
    )
    width = max(1, round(base.width * scale[0]))
    height = max(1, round(base.height * scale[1]))
    base = base.resize((width, height), Image.Resampling.LANCZOS)
    if tint:
        base = tint_toward(base, tint[0], tint[1])
    if rotation:
        base = base.rotate(
            rotation,
            resample=Image.Resampling.BICUBIC,
            expand=True,
            fillcolor=(0, 0, 0, 0),
        )
    if opacity < 1.0:
        base = set_opacity(base, opacity)
    return base


def paste_at_foot(
    canvas: Image.Image,
    image: Image.Image,
    foot: tuple[float, float],
    offset: tuple[float, float] = (0.0, 0.0),
) -> None:
    x = round(foot[0] + offset[0] - image.width / 2)
    y = round(foot[1] + offset[1] - image.height)
    alpha_composite_at(canvas, image, (x, y))


def paste_center(
    canvas: Image.Image,
    image: Image.Image,
    center: tuple[float, float],
    offset: tuple[float, float] = (0.0, 0.0),
) -> None:
    x = round(center[0] + offset[0] - image.width / 2)
    y = round(center[1] + offset[1] - image.height / 2)
    alpha_composite_at(canvas, image, (x, y))


def pose_for(action: str, phase: int) -> dict[str, object]:
    poses = {
        "attack": [
            {"scale": (0.92, 1.06), "rotation": -4.0, "offset": (-6.0, 0.0)},
            {"scale": (1.16, 0.90), "rotation": 3.0, "offset": (10.0, -1.0)},
            {"scale": (1.01, 0.99), "rotation": 0.5, "offset": (1.0, 0.0)},
        ],
        "hit": [
            {"scale": (1.0, 1.0), "rotation": 0.0, "offset": (0.0, 0.0)},
            {
                "scale": (0.86, 1.10),
                "rotation": -7.0,
                "offset": (-5.0, 0.0),
                "tint": (PAPER, 0.62),
            },
            {"scale": (0.98, 1.02), "rotation": 1.0, "offset": (0.0, 0.0)},
        ],
        "move": [
            {"scale": (0.98, 1.02), "rotation": -5.0, "offset": (-3.0, -2.0)},
            {"scale": (1.02, 0.98), "rotation": 5.0, "offset": (4.0, -5.0)},
            {"scale": (0.99, 1.01), "rotation": -2.0, "offset": (0.0, -2.0)},
        ],
        "stat": [
            {"scale": (1.0, 1.0), "rotation": 0.0, "offset": (0.0, 0.0)},
            {"scale": (1.08, 1.08), "rotation": 0.0, "offset": (0.0, -5.0)},
            {"scale": (1.02, 1.02), "rotation": 0.0, "offset": (0.0, -1.0)},
        ],
        "power": [
            {"scale": (0.95, 1.03), "rotation": 0.0, "offset": (0.0, 0.0)},
            {"scale": (1.16, 1.16), "rotation": 0.0, "offset": (0.0, -8.0)},
            {"scale": (1.0, 1.0), "rotation": 0.0, "offset": (0.0, 0.0)},
        ],
        "death": [
            {"scale": (1.0, 1.0), "rotation": 0.0, "offset": (0.0, 0.0)},
            {
                "scale": (0.72, 0.72),
                "rotation": 18.0,
                "offset": (7.0, 1.0),
                "tint": (PAPER, 0.35),
                "opacity": 0.62,
            },
            {"hidden": True},
        ],
    }
    return poses[action][phase]


def draw_pose(
    canvas: Image.Image,
    animal: Image.Image,
    action: str,
    phase: int,
    foot: tuple[float, float],
    nominal_size: int,
) -> None:
    pose = pose_for(action, phase)
    if pose.get("hidden"):
        return
    image = pose_image(
        animal,
        nominal_size,
        scale=pose.get("scale", (1.0, 1.0)),
        rotation=float(pose.get("rotation", 0.0)),
        tint=pose.get("tint"),
        opacity=float(pose.get("opacity", 1.0)),
    )
    paste_at_foot(canvas, image, foot, pose.get("offset", (0.0, 0.0)))


def effect_behind(action: str) -> bool:
    return action in {"move", "stat", "power"}


def draw_action_peak(
    canvas: Image.Image,
    effect: Image.Image,
    animal: Image.Image,
    action: str,
    foot: tuple[float, float],
    animal_size: int,
    effect_box: tuple[int, int],
) -> None:
    effect_layer = contain(effect, effect_box)
    center = (foot[0], foot[1] - animal_size * 0.52)
    if action == "move":
        center = (center[0] - animal_size * 0.18, center[1] + animal_size * 0.08)
    if effect_behind(action):
        paste_center(canvas, effect_layer, center)
    draw_pose(canvas, animal, action, 1, foot, animal_size)
    if not effect_behind(action):
        paste_center(canvas, effect_layer, center)


def draw_review_panel(
    canvas: Image.Image,
    rect: tuple[int, int, int, int],
    spec: dict[str, str],
    effect: Image.Image,
) -> None:
    x0, y0, x1, y1 = rect
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(
        rect,
        radius=18,
        fill=rgba("#FFF4D4"),
        outline=rgba(INK),
        width=4,
    )
    draw.text(
        (x0 + 24, y0 + 20),
        spec["title"],
        fill=rgba(INK),
        font=font(34, True),
        anchor="la",
    )
    draw.text(
        (x1 - 24, y0 + 26),
        spec["time"],
        fill=rgba(MOTION),
        font=font(24, True),
        anchor="ra",
    )
    draw.text(
        ((x0 + x1) // 2, y0 + 72),
        spec["phases"],
        fill=rgba(INK, 190),
        font=font(20),
        anchor="ma",
    )

    animal = Image.open(ANIMALS / spec["animal"]).convert("RGBA")
    frame_x = [x0 + 92, (x0 + x1) // 2, x1 - 92]
    foot_y = y0 + 286
    draw.line(
        (frame_x[0], foot_y + 18, frame_x[2], foot_y + 18),
        fill=rgba(INK, 72),
        width=3,
    )
    for phase, center_x in enumerate(frame_x):
        if phase == 1:
            layer = contain(effect, (176, 150))
            effect_center = (center_x, foot_y - 54)
            if spec["id"] == "move":
                effect_center = (center_x - 14, foot_y - 46)
            if effect_behind(spec["id"]):
                paste_center(canvas, layer, effect_center)
            draw_pose(canvas, animal, spec["id"], phase, (center_x, foot_y), 104)
            if not effect_behind(spec["id"]):
                paste_center(canvas, layer, effect_center)
        elif spec["id"] == "death" and phase == 2:
            layer = set_opacity(contain(effect, (112, 92)), 0.72)
            paste_center(canvas, layer, (center_x, foot_y - 40))
        else:
            draw_pose(canvas, animal, spec["id"], phase, (center_x, foot_y), 88)

    divider_y = y1 - 82
    draw.line((x0 + 22, divider_y, x1 - 22, divider_y), fill=rgba(INK, 64), width=2)
    draw.text(
        (x0 + 24, y1 - 54),
        "图片 FX + 脚点程序化姿态",
        fill=rgba(INK, 205),
        font=font(19),
        anchor="lm",
    )
    draw.text(
        (x1 - 96, y1 - 54),
        "实际 44px",
        fill=rgba(INK, 205),
        font=font(18),
        anchor="rm",
    )
    draw_action_peak(
        canvas,
        effect,
        animal,
        spec["id"],
        (x1 - 48, y1 - 30),
        44,
        (72, 62),
    )


def draw_header(
    canvas: Image.Image,
    option: str,
    subtitle: str,
    width: int,
    top: int = 0,
) -> None:
    label, name, recommendation = OPTION_META[option]
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((0, top, width, top + 96), fill=rgba(INK))
    draw.rounded_rectangle(
        (30, top + 22, 94, top + 76),
        radius=12,
        fill=rgba(POWER if option == "a" else MOTION if option == "b" else GAIN),
    )
    draw.text((62, top + 48), label, fill=rgba(INK), font=font(30, True), anchor="mm")
    draw.text((116, top + 24), name, fill=rgba(PAPER), font=font(32, True), anchor="la")
    draw.text((116, top + 64), subtitle, fill=rgba(PAPER, 215), font=font(21), anchor="la")
    draw.text((width - 30, top + 48), recommendation, fill=rgba(POWER), font=font(20), anchor="rm")


def build_review_board(option: str, effects: list[Image.Image]) -> Path:
    canvas = Image.new("RGBA", (1600, 1080), rgba(PAPER))
    draw_header(canvas, option, "六类通用动作 · 三阶段图片评审", canvas.width)
    margin_x = 34
    gap_x = 20
    gap_y = 20
    panel_w = (canvas.width - margin_x * 2 - gap_x * 2) // 3
    panel_h = 456
    start_y = 112
    for index, spec in enumerate(ACTIONS):
        col = index % 3
        row = index // 3
        x0 = margin_x + col * (panel_w + gap_x)
        y0 = start_y + row * (panel_h + gap_y)
        draw_review_panel(canvas, (x0, y0, x0 + panel_w, y0 + panel_h), spec, effects[index])
    path = OUTPUT / f"animal_universal_motion_option_{option}_review_board.png"
    canvas.convert("RGB").save(path, quality=95)
    return path


def hex_center(key: tuple[int, int], origin: tuple[float, float], size: float) -> tuple[float, float]:
    x, y = key
    width = math.sqrt(3.0) * size
    return (origin[0] + width * (x + 0.5 * (y % 2)), origin[1] + size * 1.5 * y)


def hex_points(center: tuple[float, float], size: float) -> list[tuple[float, float]]:
    points = []
    for index in range(6):
        angle = math.radians(60.0 * index - 30.0)
        points.append((center[0] + math.cos(angle) * size, center[1] + math.sin(angle) * size))
    return points


def classic_board_origin() -> tuple[float, float]:
    size = 43.0
    points: list[tuple[float, float]] = []
    for row in range(13):
        for col in range(7):
            points.extend(hex_points(hex_center((col, row), (0.0, 0.0), size), size))
    min_x = min(point[0] for point in points)
    max_x = max(point[0] for point in points)
    min_y = min(point[1] for point in points)
    max_y = max(point[1] for point in points)
    bounds_center = ((min_x + max_x) / 2.0, (min_y + max_y) / 2.0)
    play_center = (64 + 592 / 2, 110 + 982 / 2)
    return (play_center[0] - bounds_center[0], play_center[1] - bounds_center[1])


def draw_hp_bar(draw: ImageDraw.ImageDraw, center: tuple[float, float], ratio: float, team: str) -> None:
    x = round(center[0] - 18)
    y = round(center[1] + 20)
    draw.rectangle((x, y, x + 36, y + 6), fill=rgba(INK, 220))
    fill = GAIN if team == "player" else HIT
    if ratio > 0:
        draw.rectangle((x + 1, y + 1, x + 1 + round(34 * ratio), y + 4), fill=rgba(fill))
    draw.rectangle((x, y, x + 36, y + 6), outline=rgba(INK), width=1)


def build_battle_preview(option: str, effects: list[Image.Image]) -> Path:
    canvas = Image.new("RGBA", (720, 1280), rgba(PAPER))
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((0, 0, 720, 82), fill=rgba(INK))
    label, name, _ = OPTION_META[option]
    draw.text((24, 41), f"{label}  {name}", fill=rgba(PAPER), font=font(28, True), anchor="lm")
    draw.text((696, 41), "当前 720×1280 / 7×13 / 动物 44px", fill=rgba(POWER), font=font(16), anchor="rm")

    draw.rectangle((36, 82, 684, 1120), fill=rgba(PAPER), outline=rgba(INK), width=5)
    draw.rectangle((64, 110, 656, 1092), fill=rgba("#FFF4D4"), outline=rgba(INK), width=4)

    origin = classic_board_origin()
    size = 43.0
    for row in range(13):
        for col in range(7):
            center = hex_center((col, row), origin, size)
            fill = mix_color("#FFF4D4", HIT if row < 6 else GAIN, 0.18)
            draw.polygon(hex_points(center, size), fill=fill, outline=mix_color("#FFF4D4", INK, 0.56))

    placements = [(1, 2), (4, 3), (2, 5), (5, 7), (1, 9), (4, 10)]
    for index, (spec, key) in enumerate(zip(ACTIONS, placements)):
        center = hex_center(key, origin, size)
        animal = Image.open(ANIMALS / spec["animal"]).convert("RGBA")
        foot = (center[0], center[1] + 14)
        effect_box = [(110, 86), (92, 86), (110, 76), (88, 86), (96, 92), (94, 86)][index]
        draw_action_peak(canvas, effects[index], animal, spec["id"], foot, 44, effect_box)
        draw_hp_bar(draw, center, 0.0 if spec["id"] == "death" else 0.72, "enemy" if index < 3 else "player")
        badge_center = (round(center[0] + 27), round(center[1] - 29))
        draw.ellipse(
            (badge_center[0] - 10, badge_center[1] - 10, badge_center[0] + 10, badge_center[1] + 10),
            fill=rgba(PAPER),
            outline=rgba(INK),
            width=2,
        )
        draw.text(badge_center, str(index + 1), fill=rgba(INK), font=font(13, True), anchor="mm")

    draw.rectangle((0, 1138, 720, 1280), fill=rgba(INK))
    legend = "1 攻击   2 受击   3 移动   4 属性   5 提升   6 死亡"
    draw.text((360, 1182), legend, fill=rgba(PAPER), font=font(21, True), anchor="mm")
    draw.text(
        (360, 1230),
        "工程尺寸预览：FX 不改变格位、逻辑坐标或血条层",
        fill=rgba(POWER),
        font=font(17),
        anchor="mm",
    )
    path = OUTPUT / f"animal_universal_motion_option_{option}_battle_preview.png"
    canvas.convert("RGB").save(path, quality=95)
    return path


def build_overview(preview_paths: Iterable[Path]) -> Path:
    paths = list(preview_paths)
    canvas = Image.new("RGBA", (1280, 820), rgba(PAPER))
    draw = ImageDraw.Draw(canvas)
    draw.rectangle((0, 0, 1280, 92), fill=rgba(INK))
    draw.text((32, 30), "动物通用动作反馈 · 三版实际战场对比", fill=rgba(PAPER), font=font(34, True), anchor="la")
    draw.text((1248, 48), "推荐 A", fill=rgba(POWER), font=font(26, True), anchor="rm")
    for index, path in enumerate(paths):
        option = chr(ord("a") + index)
        preview = Image.open(path).convert("RGBA").resize((360, 640), Image.Resampling.LANCZOS)
        x = 60 + index * 410
        y = 122
        draw.rectangle((x - 4, y - 4, x + 364, y + 644), fill=rgba(INK))
        alpha_composite_at(canvas, preview, (x, y))
        label, name, _ = OPTION_META[option]
        draw.text((x + 180, 786), f"{label}  {name}", fill=rgba(INK), font=font(23, True), anchor="mm")
    path = OUTPUT / "animal_universal_motion_options_overview.png"
    canvas.convert("RGB").save(path, quality=95)
    return path


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    preview_paths: list[Path] = []
    for option in ("a", "b", "c"):
        alpha_path = OUTPUT / f"animal_universal_motion_fx_option_{option}_alpha.png"
        atlas = flatten_fx_palette(Image.open(alpha_path))
        flat_path = OUTPUT / f"animal_universal_motion_fx_option_{option}_flat_alpha.png"
        atlas.save(flat_path)
        effects = split_atlas(atlas)
        build_review_board(option, effects)
        preview_paths.append(build_battle_preview(option, effects))
    build_overview(preview_paths)


if __name__ == "__main__":
    main()
