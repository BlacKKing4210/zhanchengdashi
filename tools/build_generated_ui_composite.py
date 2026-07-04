from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
UI_DIR = ROOT / "assets" / "ui" / "formal_arcade"
OUT_DIR = ROOT / "output" / "formal_page_options"
COMPONENT_DIR = UI_DIR / "components"

W, H = 720, 1280


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


def cover_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    image = image.convert("RGBA")
    scale = max(size[0] / image.width, size[1] / image.height)
    resized = image.resize((int(image.width * scale), int(image.height * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - size[0]) // 2
    top = (resized.height - size[1]) // 2
    return resized.crop((left, top, left + size[0], top + size[1]))


def fit_asset(path: Path, max_size: tuple[int, int]) -> Image.Image:
    image = Image.open(path).convert("RGBA")
    bbox = image.getbbox()
    if bbox:
        image = image.crop(bbox)
    image.thumbnail(max_size, Image.Resampling.LANCZOS)
    return image


def paste_center(base: Image.Image, asset: Image.Image, center: tuple[int, int]) -> None:
    base.alpha_composite(asset, (int(center[0] - asset.width / 2), int(center[1] - asset.height / 2)))


def centered_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    rect: tuple[int, int, int, int],
    size: int,
    fill: tuple[int, int, int, int],
    stroke_width: int = 0,
    stroke_fill: tuple[int, int, int, int] = (0, 0, 0, 255),
    bold: bool = False,
) -> None:
    fnt = font(size, bold)
    bbox = draw.textbbox((0, 0), text, font=fnt, stroke_width=stroke_width)
    x = rect[0] + (rect[2] - rect[0] - (bbox[2] - bbox[0])) / 2
    y = rect[1] + (rect[3] - rect[1] - (bbox[3] - bbox[1])) / 2 - 2
    draw.text((x, y), text, font=fnt, fill=fill, stroke_width=stroke_width, stroke_fill=stroke_fill)


def left_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    xy: tuple[int, int],
    size: int,
    fill: tuple[int, int, int, int],
    stroke_width: int = 0,
    stroke_fill: tuple[int, int, int, int] = (0, 0, 0, 255),
    bold: bool = False,
) -> None:
    draw.text(xy, text, font=font(size, bold), fill=fill, stroke_width=stroke_width, stroke_fill=stroke_fill)


def crop_component(image: Image.Image, box: tuple[int, int, int, int], name: str) -> None:
    component = image.crop(box)
    bbox = component.getbbox()
    if bbox:
        component = component.crop(bbox)
    component.save(COMPONENT_DIR / name)


def export_components() -> None:
    COMPONENT_DIR.mkdir(parents=True, exist_ok=True)
    overlay = Image.open(UI_DIR / "arcade_ui_overlay_alpha.png").convert("RGBA")
    overlay = overlay.resize((W, H), Image.Resampling.LANCZOS)
    overlay.save(UI_DIR / "arcade_ui_overlay_alpha_720x1280.png")
    crop_component(overlay, (0, 0, W, 100), "top_resource_bar.png")
    crop_component(overlay, (0, 96, W, 274), "mode_progress_panel.png")
    crop_component(overlay, (0, 752, W, 958), "squad_card_panel.png")
    crop_component(overlay, (44, 960, 430, 1118), "primary_cta_button.png")
    crop_component(overlay, (430, 960, 696, 1118), "secondary_button.png")
    crop_component(overlay, (0, 1110, W, H), "bottom_nav_bar.png")


def animal_path(name: str) -> Path:
    return ROOT / "assets" / "card_art" / "animals" / f"{name}.png"


def build_composite() -> Path:
    bg = cover_resize(Image.open(OUT_DIR / "background_b_arcade_jungle.png"), (W, H))
    overlay_path = UI_DIR / "arcade_ui_overlay_alpha_720x1280.png"
    if overlay_path.exists():
        overlay = Image.open(overlay_path).convert("RGBA")
    else:
        overlay = Image.open(UI_DIR / "arcade_ui_overlay_alpha.png").convert("RGBA")
        overlay = overlay.resize((W, H), Image.Resampling.LANCZOS)

    base = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    base.alpha_composite(bg)
    tint = Image.new("RGBA", (W, H), (12, 22, 54, 34))
    base.alpha_composite(tint)

    building = fit_asset(ROOT / "assets" / "art" / "buildings" / "base.png", (178, 178))
    paste_center(base, building, (360, 405))

    animal_specs = [
        ("rabbit", (210, 560), (92, 92)),
        ("mouse", (286, 584), (74, 74)),
        ("frog", (368, 564), (86, 86)),
        ("chicken", (461, 548), (76, 76)),
        ("cat", (252, 672), (92, 92)),
        ("dog", (365, 688), (100, 100)),
        ("wolf", (480, 666), (100, 100)),
        ("bear", (360, 762), (112, 112)),
    ]
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    for _, center, size in animal_specs:
        sd.ellipse((center[0] - size[0] // 4, center[1] + size[1] // 3, center[0] + size[0] // 4, center[1] + size[1] // 2), fill=(0, 0, 0, 55))
    base.alpha_composite(shadow)
    for name, center, size in animal_specs:
        paste_center(base, fit_asset(animal_path(name), size), center)

    base.alpha_composite(overlay)

    draw = ImageDraw.Draw(base)
    ink = (8, 14, 27, 255)
    white = (255, 255, 255, 255)
    cream = (255, 248, 223, 255)

    centered_text(draw, "战城大师", (62, 29, 175, 67), 22, ink, bold=True)
    centered_text(draw, "1340", (252, 31, 338, 69), 21, ink, bold=True)
    centered_text(draw, "10", (420, 31, 506, 69), 21, ink, bold=True)
    centered_text(draw, "2", (594, 31, 680, 69), 21, ink, bold=True)

    left_text(draw, "荣耀之路", (134, 122), 25, white, 2, ink, True)
    centered_text(draw, "76 / 100", (272, 170, 456, 208), 21, cream, 2, ink, True)
    centered_text(draw, "今日宝箱", (496, 198, 626, 232), 18, cream, 2, ink, True)

    left_text(draw, "出战编组", (70, 778), 25, white, 2, ink, True)
    card_slots = [
        ("rabbit", (81, 845, 159, 923), "兔子"),
        ("mouse", (222, 845, 300, 923), "老鼠"),
        ("frog", (362, 845, 440, 923), "青蛙"),
        ("chicken", (500, 845, 578, 923), "鸡"),
    ]
    for name, rect, label in card_slots:
        asset = fit_asset(animal_path(name), (64, 64))
        paste_center(base, asset, ((rect[0] + rect[2]) // 2, rect[1] + 35))
        centered_text(draw, label, (rect[0] - 5, rect[3] - 6, rect[2] + 5, rect[3] + 26), 15, white, 2, ink, True)

    centered_text(draw, "开始战斗", (96, 1048, 410, 1088), 29, white, 3, ink, True)
    centered_text(draw, "编组", (486, 1048, 650, 1084), 24, white, 3, ink, True)

    nav_labels = [
        ("大厅", (28, 1208, 146, 1246)),
        ("编组", (176, 1208, 294, 1246)),
        ("战斗", (320, 1208, 438, 1246)),
        ("宝箱", (466, 1208, 584, 1246)),
        ("商店", (596, 1208, 714, 1246)),
    ]
    for label, rect in nav_labels:
        centered_text(draw, label, rect, 17, white, 2, ink, True)

    out_path = OUT_DIR / "formal_page_option_b_generated_ui.png"
    base.save(out_path)
    return out_path


def main() -> int:
    export_components()
    out_path = build_composite()
    print(f"Wrote {out_path.relative_to(ROOT)}")
    for component in sorted(COMPONENT_DIR.glob("*.png")):
        print(f"Wrote {component.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
