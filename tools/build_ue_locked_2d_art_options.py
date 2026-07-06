from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "output" / "visual_concepts"
W, H = 720, 1280


def hex_to_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return tuple(int(value[i : i + 2], 16) for i in (0, 2, 4))


def blend(a: str, b: str, t: float) -> tuple[int, int, int]:
    ar, ag, ab = hex_to_rgb(a)
    br, bg, bb = hex_to_rgb(b)
    return (
        int(ar + (br - ar) * t),
        int(ag + (bg - ag) * t),
        int(ab + (bb - ab) * t),
    )


def rgba(color: str, alpha: int = 255) -> tuple[int, int, int, int]:
    r, g, b = hex_to_rgb(color)
    return r, g, b, alpha


def rect_shadow(draw: ImageDraw.ImageDraw, box: tuple[int, int, int, int], radius: int, offset: int, color: str) -> None:
    x1, y1, x2, y2 = box
    draw.rounded_rectangle((x1 + offset, y1 + offset, x2 + offset, y2 + offset), radius=radius, fill=rgba(color, 125))


def rounded_panel(
    draw: ImageDraw.ImageDraw,
    box: tuple[int, int, int, int],
    fill: str,
    outline: str,
    radius: int = 14,
    width: int = 4,
    shadow: str | None = None,
) -> None:
    if shadow:
        rect_shadow(draw, box, radius, 6, shadow)
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)
    x1, y1, x2, y2 = box
    draw.rounded_rectangle((x1 + 5, y1 + 5, x2 - 5, y1 + 18), radius=max(4, radius - 6), fill=rgba("#ffffff", 38))


def polygon_regular(center: tuple[float, float], radius: float, sides: int, rotation: float) -> list[tuple[float, float]]:
    cx, cy = center
    return [
        (
            cx + math.cos(rotation + math.tau * i / sides) * radius,
            cy + math.sin(rotation + math.tau * i / sides) * radius,
        )
        for i in range(sides)
    ]


def draw_icon(draw: ImageDraw.ImageDraw, center: tuple[int, int], kind: str, color: str, dark: str) -> None:
    x, y = center
    if kind == "coin":
        draw.ellipse((x - 15, y - 15, x + 15, y + 15), fill=color, outline=dark, width=3)
        draw.polygon(polygon_regular((x, y), 8, 5, -math.pi / 2), fill=rgba("#fff2a5", 230))
    elif kind == "gem":
        draw.polygon(polygon_regular((x, y), 17, 6, math.pi / 6), fill=color, outline=dark)
        draw.line((x - 9, y - 2, x, y + 12, x + 10, y - 4), fill=rgba("#ffffff", 120), width=2)
    elif kind == "sword":
        draw.line((x - 13, y + 13, x + 12, y - 12), fill=color, width=7)
        draw.line((x - 3, y + 8, x + 10, y + 21), fill=dark, width=5)
        draw.polygon([(x + 12, y - 12), (x + 18, y - 20), (x + 5, y - 14)], fill=rgba("#ffffff", 230))
    elif kind == "tower":
        draw.rectangle((x - 13, y - 9, x + 13, y + 14), fill=color, outline=dark, width=3)
        draw.rectangle((x - 8, y - 20, x + 8, y - 9), fill=color, outline=dark, width=3)
        draw.rectangle((x - 5, y + 2, x + 5, y + 14), fill=dark)
    elif kind == "mine":
        draw.polygon([(x - 20, y + 14), (x - 8, y - 12), (x + 2, y + 12)], fill=color, outline=dark)
        draw.polygon([(x - 2, y + 14), (x + 12, y - 14), (x + 22, y + 14)], fill=color, outline=dark)
        draw.line((x - 10, y + 2, x + 8, y + 3), fill=rgba("#ffffff", 120), width=2)
    elif kind == "cards":
        for i in range(3):
            draw.rounded_rectangle((x - 15 + i * 5, y - 18 + i * 3, x + 10 + i * 5, y + 15 + i * 3), radius=4, fill=color, outline=dark, width=2)
    elif kind == "paw":
        draw.ellipse((x - 9, y - 2, x + 9, y + 15), fill=color, outline=dark, width=2)
        for dx, dy in [(-13, -11), (-4, -16), (6, -16), (14, -9)]:
            draw.ellipse((x + dx - 5, y + dy - 5, x + dx + 5, y + dy + 5), fill=color, outline=dark, width=1)
    elif kind == "menu":
        for dx in [-11, 0, 11]:
            draw.ellipse((x + dx - 4, y - 4, x + dx + 4, y + 4), fill=color)


def draw_unit(draw: ImageDraw.ImageDraw, center: tuple[int, int], team: str, palette: dict[str, str], shape: str) -> None:
    x, y = center
    accent = palette["player"] if team == "player" else palette["enemy"]
    body = palette["unit_player"] if team == "player" else palette["unit_enemy"]
    draw.ellipse((x - 18, y - 17, x + 18, y + 17), fill=body, outline=palette["ink"], width=3)
    if shape == "beak":
        draw.polygon([(x + 6, y - 4), (x + 24, y + 1), (x + 6, y + 7)], fill=palette["gold"], outline=palette["ink"])
    elif shape == "horn":
        draw.polygon([(x - 11, y - 13), (x - 3, y - 29), (x + 1, y - 12)], fill=palette["panel_light"], outline=palette["ink"])
        draw.polygon([(x + 8, y - 13), (x + 17, y - 27), (x + 18, y - 10)], fill=palette["panel_light"], outline=palette["ink"])
    else:
        draw.polygon([(x - 14, y - 12), (x - 25, y - 24), (x - 19, y - 3)], fill=body, outline=palette["ink"])
        draw.polygon([(x + 13, y - 12), (x + 25, y - 24), (x + 18, y - 3)], fill=body, outline=palette["ink"])
    draw.ellipse((x - 4, y - 5, x + 4, y + 3), fill=palette["ink"])
    draw.rectangle((x - 20, y + 19, x + 20, y + 25), fill=palette["ink"])
    draw.rectangle((x - 18, y + 20, x + 14, y + 24), fill=accent)


def draw_hex(draw: ImageDraw.ImageDraw, center: tuple[float, float], r: float, fill: str, outline: str, width: int = 2) -> None:
    pts = polygon_regular(center, r, 6, -math.pi / 2)
    draw.polygon(pts, fill=fill, outline=outline)
    if width > 1:
        for shrink in range(1, width):
            pts2 = polygon_regular(center, r - shrink * 1.6, 6, -math.pi / 2)
            draw.line(pts2 + [pts2[0]], fill=outline, width=1)


def add_noise(image: Image.Image, amount: int, seed: int) -> None:
    rng = random.Random(seed)
    overlay = Image.new("RGBA", image.size, (0, 0, 0, 0))
    pix = overlay.load()
    for _ in range(amount):
        x = rng.randrange(W)
        y = rng.randrange(H)
        v = rng.randrange(18, 52)
        pix[x, y] = (255, 255, 255, v)
    image.alpha_composite(overlay)


def make_gradient(palette: dict[str, str]) -> Image.Image:
    image = Image.new("RGBA", (W, H), palette["bg_top"])
    draw = ImageDraw.Draw(image)
    for y in range(H):
        t = y / (H - 1)
        draw.line((0, y, W, y), fill=blend(palette["bg_top"], palette["bg_bottom"], t) + (255,))
    return image


def draw_screen(name: str, palette: dict[str, str], seed: int) -> None:
    image = make_gradient(palette)
    draw = ImageDraw.Draw(image)
    add_noise(image, 7800, seed)

    # Fixed UE zones.
    top = (0, 0, W, 112)
    board = (24, 116, 696, 820)
    info = (24, 836, 696, 1058)
    nav = (0, 1080, W, 1280)

    draw.rectangle(top, fill=rgba(palette["hud"], 245))
    draw.rectangle(nav, fill=rgba(palette["hud"], 248))
    rounded_panel(draw, board, palette["board_frame"], palette["ink"], radius=18, width=5, shadow=palette["shadow"])
    rounded_panel(draw, info, palette["panel"], palette["ink"], radius=18, width=5, shadow=palette["shadow"])

    # Top resource pills: same slots in all options.
    pill_boxes = [(18, 20, 160, 82), (178, 20, 320, 82), (338, 20, 480, 82), (498, 20, 640, 82)]
    kinds = ["gem", "coin", "gem", "paw"]
    colors = [palette["blue"], palette["gold"], palette["green"], palette["red"]]
    for box, kind, color in zip(pill_boxes, kinds, colors):
        rounded_panel(draw, box, palette["panel_dark"], palette["ink"], radius=13, width=4, shadow=palette["shadow"])
        draw_icon(draw, ((box[0] + 30), (box[1] + box[3]) // 2), kind, color, palette["ink"])
        for i in range(4):
            draw.rounded_rectangle((box[0] + 58 + i * 18, box[1] + 22, box[0] + 70 + i * 18, box[3] - 22), radius=4, fill=color)

    # Board surface.
    rounded_panel(draw, (40, 132, 680, 806), palette["field"], palette["field_line"], radius=12, width=3)

    # Hex grid. Same center positions for every skin.
    r = 30
    dx = math.sqrt(3) * r
    dy = 1.5 * r
    start_y = 182
    center_x = W / 2
    centers: list[tuple[int, int, int, int]] = []
    for row in range(13):
        y = int(start_y + row * dy)
        row_offset = dx / 2 if row % 2 else 0
        for col in range(7):
            x = int(center_x + (col - 3) * dx + row_offset - dx / 4)
            if 55 < x < 665 and 145 < y < 790:
                centers.append((row, col, x, y))

    locked = {(2, 0), (2, 6), (5, 0), (5, 6), (8, 0), (8, 6)}
    mines = {(3, 0), (3, 6), (10, 0), (10, 6)}
    towers = {(3, 1), (3, 5), (9, 1), (9, 5)}
    camps = {(5, 3), (7, 3)}
    units = {
        (4, 3): ("enemy", "horn"),
        (5, 2): ("enemy", "ears"),
        (6, 3): ("enemy", "horn"),
        (7, 2): ("player", "horn"),
        (8, 3): ("player", "ears"),
        (9, 3): ("player", "beak"),
    }
    selected = (8, 4)

    for row, col, x, y in centers:
        if (row, col) in locked:
            fill = palette["locked"]
        elif row <= 5:
            fill = palette["enemy_tile"]
        elif row >= 7:
            fill = palette["player_tile"]
        else:
            fill = palette["field_tile"]
        outline = palette["select"] if (row, col) == selected else palette["field_line"]
        draw_hex(draw, (x, y), r, fill, outline, width=4 if (row, col) == selected else 2)
        if (row, col) in locked:
            draw_icon(draw, (x, y), "menu", palette["muted"], palette["ink"])

    def center_for(key: tuple[int, int]) -> tuple[int, int]:
        for row, col, x, y in centers:
            if (row, col) == key:
                return x, y
        return 0, 0

    # Fixed building positions.
    for key in mines:
        x, y = center_for(key)
        draw_icon(draw, (x, y), "mine", palette["gold"], palette["ink"])
    for key in towers:
        x, y = center_for(key)
        team = "enemy" if key[0] < 6 else "player"
        draw_icon(draw, (x, y), "tower", palette["red"] if team == "enemy" else palette["blue"], palette["ink"])
    for key in camps:
        x, y = center_for(key)
        draw_icon(draw, (x, y), "paw", palette["red"] if key[0] < 6 else palette["blue"], palette["ink"])
    for key, (team, shape) in units.items():
        x, y = center_for(key)
        draw_unit(draw, (x, y - 3), team, palette, shape)

    # Bases, same top/bottom locations.
    for y, team_color in [(172, palette["red"]), (770, palette["blue"])]:
        rounded_panel(draw, (286, y - 42, 434, y + 42), palette["base"], palette["ink"], radius=14, width=4, shadow=palette["shadow"])
        draw.polygon([(322, y + 42), (398, y + 42), (382, y - 18), (338, y - 18)], fill=team_color, outline=palette["ink"])
        draw_icon(draw, (360, y + 1), "tower", team_color, palette["ink"])

    # Selected info panel: fixed structure.
    rounded_panel(draw, (48, 858, 210, 1036), palette["panel_light"], palette["ink"], radius=12, width=4)
    draw_icon(draw, (129, 938), "tower", palette["blue"], palette["ink"])
    for i, kind in enumerate(["sword", "tower", "gem", "paw"]):
        y = 874 + i * 38
        draw_icon(draw, (252, y + 14), kind, [palette["gold"], palette["blue"], palette["green"], palette["purple"]][i], palette["ink"])
        draw.rounded_rectangle((286, y + 7, 470, y + 21), radius=6, fill=palette["bar_back"])
        draw.rounded_rectangle((286, y + 7, 360 + i * 22, y + 21), radius=6, fill=[palette["gold"], palette["blue"], palette["green"], palette["purple"]][i])
    rounded_panel(draw, (512, 896, 664, 1008), palette["cta"], palette["ink"], radius=16, width=5, shadow=palette["shadow"])
    draw_icon(draw, (588, 952), "sword", palette["panel_light"], palette["ink"])

    # Bottom nav, five tabs unchanged.
    tab_w = W // 5
    tab_icons = ["tower", "cards", "sword", "paw", "menu"]
    for i in range(5):
        x1 = i * tab_w + 8
        x2 = (i + 1) * tab_w - 8
        fill = palette["nav_active"] if i == 2 else palette["nav"]
        rounded_panel(draw, (x1, 1100, x2, 1260), fill, palette["ink"], radius=16, width=4, shadow=palette["shadow"])
        icon_color = palette["gold"] if i == 2 else palette["nav_icon"]
        draw_icon(draw, ((x1 + x2) // 2, 1180), tab_icons[i], icon_color, palette["ink"])

    # Crisp pass.
    image = image.filter(ImageFilter.UnsharpMask(radius=1.0, percent=90, threshold=3))
    OUT.mkdir(parents=True, exist_ok=True)
    image.convert("RGB").save(OUT / name, quality=95)


OPTIONS = {
    "current_game_2d_ue_locked_option_a_clean_arcade.png": {
        "bg_top": "#23376d",
        "bg_bottom": "#10243e",
        "hud": "#10233e",
        "panel": "#173456",
        "panel_dark": "#0c1e36",
        "panel_light": "#d7ecff",
        "board_frame": "#0f2b34",
        "field": "#3a7b49",
        "field_tile": "#68a85d",
        "field_line": "#24422e",
        "enemy_tile": "#6f8d4b",
        "player_tile": "#63a263",
        "locked": "#a7b3a4",
        "base": "#7f8176",
        "ink": "#07131f",
        "shadow": "#000000",
        "blue": "#20a8ff",
        "red": "#d94b44",
        "green": "#7ddb43",
        "gold": "#f5c13f",
        "purple": "#9b5cff",
        "cta": "#f4b829",
        "select": "#55d8ff",
        "muted": "#637271",
        "bar_back": "#203044",
        "nav": "#18263e",
        "nav_active": "#214773",
        "nav_icon": "#9fb6cf",
        "unit_player": "#a4b7aa",
        "unit_enemy": "#b47a4c",
        "player": "#1aa7ff",
        "enemy": "#de4a43",
    },
    "current_game_2d_ue_locked_option_b_paper_jungle.png": {
        "bg_top": "#264431",
        "bg_bottom": "#132a21",
        "hud": "#142c29",
        "panel": "#d8c49a",
        "panel_dark": "#234a42",
        "panel_light": "#eadcb7",
        "board_frame": "#42522f",
        "field": "#6c8545",
        "field_tile": "#8aa356",
        "field_line": "#4f612d",
        "enemy_tile": "#977b4c",
        "player_tile": "#768f55",
        "locked": "#c4b896",
        "base": "#a98253",
        "ink": "#1b2018",
        "shadow": "#000000",
        "blue": "#2b8bc6",
        "red": "#b4523a",
        "green": "#68a94b",
        "gold": "#d9a944",
        "purple": "#9b63b7",
        "cta": "#e7ae32",
        "select": "#b7ec9e",
        "muted": "#817966",
        "bar_back": "#74664f",
        "nav": "#45513a",
        "nav_active": "#25678e",
        "nav_icon": "#e7d6aa",
        "unit_player": "#c2b899",
        "unit_enemy": "#b67c55",
        "player": "#2d8ec8",
        "enemy": "#b94e37",
    },
    "current_game_2d_ue_locked_option_c_crystal_night.png": {
        "bg_top": "#101733",
        "bg_bottom": "#07101f",
        "hud": "#081528",
        "panel": "#17263a",
        "panel_dark": "#091323",
        "panel_light": "#c7d7ec",
        "board_frame": "#0b2632",
        "field": "#25515a",
        "field_tile": "#356b71",
        "field_line": "#1a424a",
        "enemy_tile": "#3f515b",
        "player_tile": "#285d66",
        "locked": "#5d6e78",
        "base": "#37475c",
        "ink": "#040914",
        "shadow": "#000000",
        "blue": "#28b9ff",
        "red": "#f05b57",
        "green": "#64df87",
        "gold": "#f3b84c",
        "purple": "#b06dff",
        "cta": "#f0aa28",
        "select": "#52e8ff",
        "muted": "#8392a4",
        "bar_back": "#0c1728",
        "nav": "#111d30",
        "nav_active": "#173c68",
        "nav_icon": "#9eb7d2",
        "unit_player": "#839fb0",
        "unit_enemy": "#9d6a62",
        "player": "#2bbcff",
        "enemy": "#e8504e",
    },
    "current_game_2d_ue_locked_option_d_toy_board.png": {
        "bg_top": "#28324c",
        "bg_bottom": "#151b2c",
        "hud": "#111a2b",
        "panel": "#31506a",
        "panel_dark": "#121c2e",
        "panel_light": "#d7d2bd",
        "board_frame": "#354038",
        "field": "#4f7b45",
        "field_tile": "#74a45e",
        "field_line": "#3c5f37",
        "enemy_tile": "#876141",
        "player_tile": "#638e58",
        "locked": "#8a8e80",
        "base": "#7a684d",
        "ink": "#090d13",
        "shadow": "#000000",
        "blue": "#2aa5e8",
        "red": "#cf4a3f",
        "green": "#74c64b",
        "gold": "#eeb43f",
        "purple": "#905be0",
        "cta": "#f2b63b",
        "select": "#67d6ff",
        "muted": "#747b7b",
        "bar_back": "#1c293a",
        "nav": "#202b3d",
        "nav_active": "#284b6a",
        "nav_icon": "#cfc6a6",
        "unit_player": "#b2aa90",
        "unit_enemy": "#a8734e",
        "player": "#229fe4",
        "enemy": "#cc493d",
    },
}


if __name__ == "__main__":
    for index, (filename, palette) in enumerate(OPTIONS.items(), start=1):
        draw_screen(filename, palette, 20260706 + index)
