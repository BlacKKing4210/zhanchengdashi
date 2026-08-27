from __future__ import annotations

import argparse
import hashlib
import json
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE_BOARD = ROOT / "output" / "visual_concepts" / "defense_towers_v2" / "raw_candidates" / "defense_towers_architecture_a.png"
ANIMAL_DIR = ROOT / "assets" / "card_art" / "animals"
TEMP_ROOT = ROOT / "temp" / "art" / "F-ZC-DEFENSE-TOWER-005" / "v3"
REF_DIR = TEMP_ROOT / "refs"
ANIMAL_STYLE_BOARD_PATH = REF_DIR / "animal_style_reference_board.png"
CANDIDATE_DIR = TEMP_ROOT / "normalized_candidates"
OUTPUT_ROOT = ROOT / "output" / "visual_concepts" / "defense_towers_v3"
BOARD_PATH = OUTPUT_ROOT / "defense_towers_production_board_a.png"
RUNTIME_DIR = ROOT / "assets" / "art" / "buildings" / "defense_towers"
RUNTIME_QA_DIR = ROOT / "output" / "qa" / "F-ZC-DEFENSE-TOWER-005" / "runtime-art-a"

CANVAS_SIZE = 480
BASELINE_Y = 438
TOP_MARGIN = 20
SIDE_MARGIN = 24
CORNER_SIZE = 24


@dataclass(frozen=True)
class TowerSpec:
    index: int
    tower_id: str
    name: str
    animal_id: str
    rarity: int
    rect: tuple[int, int, int, int]


TOWERS = (
    TowerSpec(1, "defense_watch_tower", "兔子哨塔", "rabbit", 2, (0, 0, 334, 470)),
    TowerSpec(2, "defense_longshot_tower", "猎鹰瞭望塔", "falcon", 3, (334, 0, 334, 470)),
    TowerSpec(3, "defense_cannon_tower", "野猪重弩塔", "boar", 3, (668, 0, 335, 470)),
    TowerSpec(4, "defense_plunder_tower", "松鼠掠金塔", "squirrel", 3, (1003, 0, 334, 470)),
    TowerSpec(5, "defense_rapid_tower", "麻雀速弩塔", "sparrow", 4, (1337, 0, 335, 470)),
    TowerSpec(6, "defense_repair_beacon", "龟甲壁垒塔", "turtle", 4, (0, 470, 334, 471)),
    TowerSpec(7, "defense_twinshot_tower", "鹦鹉双弩塔", "parrot", 4, (334, 470, 334, 471)),
    TowerSpec(8, "defense_bounty_tower", "老虎赏金塔", "tiger", 5, (668, 470, 335, 471)),
    TowerSpec(9, "defense_territory_tower", "金雕领空塔", "golden_eagle", 5, (1003, 470, 334, 471)),
    TowerSpec(10, "defense_storm_obelisk", "猛犸震地塔", "mammoth", 5, (1337, 470, 335, 471)),
)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def font(size: int, bold: bool = False) -> ImageFont.ImageFont:
    candidates = (
        Path(r"C:\Windows\Fonts\msyhbd.ttc" if bold else r"C:\Windows\Fonts\msyh.ttc"),
        Path(r"C:\Windows\Fonts\simhei.ttf"),
    )
    for candidate in candidates:
        if candidate.exists():
            return ImageFont.truetype(str(candidate), size=size)
    return ImageFont.load_default()


def prepare_refs() -> None:
    if not SOURCE_BOARD.exists():
        raise FileNotFoundError(SOURCE_BOARD)
    REF_DIR.mkdir(parents=True, exist_ok=True)
    with Image.open(SOURCE_BOARD) as source:
        source = source.convert("RGB")
        for spec in TOWERS:
            x, y, width, height = spec.rect
            crop = source.crop((x + 3, y + 3, x + width - 3, y + height - 3))
            scale = 2
            crop = crop.resize((crop.width * scale, crop.height * scale), Image.Resampling.LANCZOS)
            crop.save(REF_DIR / f"a{spec.index:02d}_{spec.tower_id}_reference.png")
    build_animal_style_reference_board()
    print(REF_DIR)


def build_animal_style_reference_board() -> None:
    cell = 320
    board = Image.new("RGBA", (cell * 5, cell * 2), (247, 242, 229, 255))
    for spec in TOWERS:
        source_path = ANIMAL_DIR / f"{spec.animal_id}.png"
        if not source_path.exists():
            raise FileNotFoundError(source_path)
        with Image.open(source_path) as source:
            subject = ensure_alpha(source)
            bbox = alpha_bbox(subject)
            if bbox is None:
                raise ValueError(f"No visible animal pixels: {source_path}")
            subject = subject.crop(bbox)
            scale = min(250 / subject.width, 250 / subject.height)
            subject = subject.resize(
                (max(1, round(subject.width * scale)), max(1, round(subject.height * scale))),
                Image.Resampling.LANCZOS,
            )
        column = (spec.index - 1) % 5
        row = (spec.index - 1) // 5
        x = column * cell + (cell - subject.width) // 2
        y = row * cell + (cell - subject.height) // 2
        board.alpha_composite(subject, (x, y))
    board.convert("RGB").save(ANIMAL_STYLE_BOARD_PATH, optimize=True)


def alpha_bbox(image: Image.Image, threshold: int = 8) -> tuple[int, int, int, int] | None:
    alpha = image.getchannel("A")
    binary = alpha.point(lambda value: 255 if value > threshold else 0)
    return binary.getbbox()


def ensure_alpha(image: Image.Image) -> Image.Image:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    low, high = alpha.getextrema()
    if low < high:
        return rgba

    corners = (
        rgba.getpixel((0, 0))[:3],
        rgba.getpixel((rgba.width - 1, 0))[:3],
        rgba.getpixel((0, rgba.height - 1))[:3],
        rgba.getpixel((rgba.width - 1, rgba.height - 1))[:3],
    )
    background = tuple(sum(pixel[channel] for pixel in corners) // len(corners) for channel in range(3))
    pixels = rgba.load()
    mask = Image.new("L", rgba.size, 255)
    mask_pixels = mask.load()
    for y in range(rgba.height):
        for x in range(rgba.width):
            rgb = pixels[x, y][:3]
            distance = sum((rgb[channel] - background[channel]) ** 2 for channel in range(3)) ** 0.5
            mask_pixels[x, y] = 0 if distance < 24 else min(255, int((distance - 24) * 6))
    mask = mask.filter(ImageFilter.MedianFilter(3))
    rgba.putalpha(mask)
    return rgba


def normalize_image(source_path: Path, output_path: Path) -> dict[str, object]:
    with Image.open(source_path) as source:
        rgba = ensure_alpha(source)
    bbox = alpha_bbox(rgba)
    if bbox is None:
        raise ValueError(f"No visible pixels: {source_path}")
    subject = rgba.crop(bbox)
    max_width = CANVAS_SIZE - SIDE_MARGIN * 2
    max_height = BASELINE_Y - TOP_MARGIN
    scale = min(max_width / subject.width, max_height / subject.height)
    target = (max(1, round(subject.width * scale)), max(1, round(subject.height * scale)))
    subject = subject.resize(target, Image.Resampling.LANCZOS)
    canvas = Image.new("RGBA", (CANVAS_SIZE, CANVAS_SIZE), (0, 0, 0, 0))
    x = (CANVAS_SIZE - subject.width) // 2
    y = BASELINE_Y - subject.height
    canvas.alpha_composite(subject, (x, y))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output_path, optimize=True)
    return audit_image(output_path)


def normalize_directory(input_dir: Path) -> None:
    CANDIDATE_DIR.mkdir(parents=True, exist_ok=True)
    records = []
    for spec in TOWERS:
        source = input_dir / f"{spec.tower_id}.png"
        if not source.exists():
            raise FileNotFoundError(source)
        target = CANDIDATE_DIR / f"{spec.tower_id}.png"
        records.append({"tower_id": spec.tower_id, **normalize_image(source, target)})
    (CANDIDATE_DIR / "normalization_manifest.json").write_text(
        json.dumps({"status": "CANDIDATE_ONLY", "assets": records}, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    print(CANDIDATE_DIR)


def build_board() -> None:
    OUTPUT_ROOT.mkdir(parents=True, exist_ok=True)
    board = Image.new("RGBA", (CANVAS_SIZE * 5, CANVAS_SIZE * 2), (0, 0, 0, 0))
    for spec in TOWERS:
        source = CANDIDATE_DIR / f"{spec.tower_id}.png"
        if not source.exists():
            raise FileNotFoundError(source)
        with Image.open(source) as image:
            image = image.convert("RGBA")
            column = (spec.index - 1) % 5
            row = (spec.index - 1) // 5
            board.alpha_composite(image, (column * CANVAS_SIZE, row * CANVAS_SIZE))
    board.save(BOARD_PATH, optimize=True)
    build_review_board(board)
    build_mattes_and_small_previews(board)
    print(BOARD_PATH)


def checker_tile(size: tuple[int, int], dark: bool) -> Image.Image:
    base = (31, 38, 51, 255) if dark else (244, 238, 222, 255)
    alt = (47, 56, 72, 255) if dark else (224, 216, 196, 255)
    image = Image.new("RGBA", size, base)
    draw = ImageDraw.Draw(image)
    step = 32
    for y in range(0, size[1], step):
        for x in range(0, size[0], step):
            if (x // step + y // step) % 2:
                draw.rectangle((x, y, x + step - 1, y + step - 1), fill=alt)
    return image


def build_review_board(board: Image.Image) -> None:
    header = 118
    review = Image.new("RGB", (board.width, board.height + header), (238, 226, 197))
    draw = ImageDraw.Draw(review)
    draw.text((36, 22), "防御塔方案 A｜动物同风格低细节正式生产整板｜F-ZC-DEFENSE-TOWER-005 V1.2", font=font(34, True), fill=(24, 36, 60))
    draw.text((38, 70), "480×480 RGBA / 大色块粗轮廓 / 3～5 主形状 / A07 代表切片优先", font=font(22), fill=(60, 75, 96))
    matte = checker_tile(board.size, dark=False)
    matte.alpha_composite(board)
    review.paste(matte.convert("RGB"), (0, header))
    draw = ImageDraw.Draw(review)
    for spec in TOWERS:
        column = (spec.index - 1) % 5
        row = (spec.index - 1) // 5
        x = column * CANVAS_SIZE + 12
        y = header + row * CANVAS_SIZE + 12
        label = f"{spec.index:02d}  {spec.name}  品质{spec.rarity}"
        bounds = draw.textbbox((0, 0), label, font=font(19, True))
        draw.rounded_rectangle((x - 5, y - 4, x + bounds[2] + 10, y + bounds[3] + 8), 7, fill=(255, 250, 235), outline=(33, 43, 58), width=2)
        draw.text((x, y), label, font=font(19, True), fill=(24, 36, 60))
    review.save(OUTPUT_ROOT / "defense_towers_production_board_a_review.png", optimize=True)


def audit_image(path: Path) -> dict[str, object]:
    with Image.open(path) as image:
        rgba = image.convert("RGBA")
        bbox = alpha_bbox(rgba)
        alpha = rgba.getchannel("A")
        alpha_min, alpha_max = alpha.getextrema()
        visible_pixels = sum(1 for value in alpha.get_flattened_data() if value > 8)
        corners = (
            alpha.crop((0, 0, CORNER_SIZE, CORNER_SIZE)),
            alpha.crop((CANVAS_SIZE - CORNER_SIZE, 0, CANVAS_SIZE, CORNER_SIZE)),
            alpha.crop((0, CANVAS_SIZE - CORNER_SIZE, CORNER_SIZE, CANVAS_SIZE)),
            alpha.crop((CANVAS_SIZE - CORNER_SIZE, CANVAS_SIZE - CORNER_SIZE, CANVAS_SIZE, CANVAS_SIZE)),
        )
        corner_clear = all(corner.getextrema()[1] == 0 for corner in corners)
    if bbox is None:
        raise ValueError(f"No visible pixels: {path}")
    left, top, right, bottom = bbox
    return {
        "path": path.relative_to(ROOT).as_posix(),
        "sha256": sha256(path),
        "size": [CANVAS_SIZE, CANVAS_SIZE],
        "mode": "RGBA",
        "alpha_extrema": [alpha_min, alpha_max],
        "bbox": [left, top, right, bottom],
        "visual_center_x": round((left + right) / 2, 2),
        "baseline_y": bottom,
        "bbox_occupancy_pct": round(((right - left) * (bottom - top)) / (CANVAS_SIZE * CANVAS_SIZE) * 100, 2),
        "visible_pixel_pct": round(visible_pixels / (CANVAS_SIZE * CANVAS_SIZE) * 100, 2),
        "transparent_corners_24px": corner_clear,
    }


def publish() -> None:
    if not BOARD_PATH.exists():
        raise FileNotFoundError(BOARD_PATH)
    RUNTIME_DIR.mkdir(parents=True, exist_ok=True)
    records = []
    with Image.open(BOARD_PATH) as board:
        board = board.convert("RGBA")
        if board.size != (CANVAS_SIZE * 5, CANVAS_SIZE * 2):
            raise ValueError(f"Unexpected board size: {board.size}")
        for spec in TOWERS:
            column = (spec.index - 1) % 5
            row = (spec.index - 1) // 5
            left = column * CANVAS_SIZE
            top = row * CANVAS_SIZE
            crop = board.crop((left, top, left + CANVAS_SIZE, top + CANVAS_SIZE))
            target = RUNTIME_DIR / f"{spec.tower_id}.png"
            crop.save(target, optimize=True)
            records.append({
                "index": spec.index,
                "tower_id": spec.tower_id,
                "name": spec.name,
                "rarity": spec.rarity,
                **audit_image(target),
            })
    build_mattes_and_small_previews()
    manifest = {
        "feature_id": "F-ZC-DEFENSE-TOWER-005",
        "version": "v1.2.0",
        "direction": "A_existing_animal_style_large_color_blocks_low_detail_architecture_first",
        "status": "RUNTIME_READY",
        "source_board": BOARD_PATH.relative_to(ROOT).as_posix(),
        "source_board_sha256": sha256(BOARD_PATH),
        "canvas": [CANVAS_SIZE, CANVAS_SIZE],
        "baseline_target_y": BASELINE_Y,
        "assets": records,
    }
    manifest_path = RUNTIME_DIR / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    (OUTPUT_ROOT / "defense_towers_production_manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8"
    )
    print(manifest_path)


def build_mattes_and_small_previews(board: Image.Image | None = None) -> None:
    if board is None:
        with Image.open(BOARD_PATH) as source:
            board_rgba = source.convert("RGBA")
    else:
        board_rgba = board.convert("RGBA")
    light = checker_tile((CANVAS_SIZE * 5, CANVAS_SIZE * 2), dark=False)
    dark = checker_tile((CANVAS_SIZE * 5, CANVAS_SIZE * 2), dark=True)
    light.alpha_composite(board_rgba)
    dark.alpha_composite(board_rgba)
    light.convert("RGB").save(OUTPUT_ROOT / "defense_towers_matte_light.png", optimize=True)
    dark.convert("RGB").save(OUTPUT_ROOT / "defense_towers_matte_dark.png", optimize=True)

    for size in (48, 56, 64, 96):
        sheet = Image.new("RGBA", (size * 5, size * 2), (0, 0, 0, 0))
        for spec in TOWERS:
            column = (spec.index - 1) % 5
            row = (spec.index - 1) // 5
            source = board_rgba.crop((column * CANVAS_SIZE, row * CANVAS_SIZE, (column + 1) * CANVAS_SIZE, (row + 1) * CANVAS_SIZE))
            thumb = source.resize((size, size), Image.Resampling.LANCZOS)
            sheet.alpha_composite(thumb, (column * size, row * size))
        matte = checker_tile(sheet.size, dark=size in (56, 96))
        matte.alpha_composite(sheet)
        matte.convert("RGB").save(OUTPUT_ROOT / f"defense_towers_preview_{size}px.png", optimize=True)


def build_representative_review(source_path: Path, output_path: Path) -> None:
    with Image.open(source_path) as source:
        sprite = source.convert("RGBA")
    if sprite.size != (CANVAS_SIZE, CANVAS_SIZE):
        raise ValueError(f"Representative must be {CANVAS_SIZE}x{CANVAS_SIZE}: {source_path}")
    review = Image.new("RGB", (1120, 720), (239, 229, 207))
    draw = ImageDraw.Draw(review)
    draw.text((34, 22), "A07 鹦鹉双弩塔｜动物同风格低细节代表切片", font=font(32, True), fill=(24, 36, 60))
    draw.text((36, 68), "大色块 / 粗轮廓 / 建筑主体 / 56px 双弩可读性", font=font(21), fill=(60, 75, 96))
    large = checker_tile((520, 520), dark=False)
    large.alpha_composite(sprite, (20, 20))
    review.paste(large.convert("RGB"), (32, 120))
    samples = (
        (56, (139, 196, 104, 255), "56px 绿色地块"),
        (56, (143, 132, 197, 255), "56px 紫色地块"),
        (96, (244, 238, 222, 255), "96px 浅底"),
        (96, (31, 38, 51, 255), "96px 深底"),
    )
    for index, (size, background, label) in enumerate(samples):
        row = index // 2
        column = index % 2
        panel_x = 610 + column * 238
        panel_y = 152 + row * 248
        panel = Image.new("RGBA", (190, 190), background)
        thumb = sprite.resize((size, size), Image.Resampling.LANCZOS)
        panel.alpha_composite(thumb, ((190 - size) // 2, (190 - size) // 2))
        review.paste(panel.convert("RGB"), (panel_x, panel_y))
        draw.text((panel_x, panel_y + 198), label, font=font(18, True), fill=(24, 36, 60))
    output_path.parent.mkdir(parents=True, exist_ok=True)
    review.save(output_path, optimize=True)


def build_runtime_catalog(input_dir: Path, output_dir: Path) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    layouts = (
        ("card", (0, 130, 720, 680), (420, 321), "方案 A｜10 座防御塔卡牌实机目录｜720×1280"),
        ("battle", (140, 540, 580, 1280), (420, 706), "方案 A｜10 座防御塔战场实机目录｜720×1280"),
    )
    for suffix, crop_box, cell_size, title in layouts:
        header = 86
        board = Image.new("RGB", (cell_size[0] * 5, header + cell_size[1] * 2), (238, 226, 197))
        draw = ImageDraw.Draw(board)
        draw.text((28, 18), title, font=font(30, True), fill=(24, 36, 60))
        draw.text((30, 56), "Godot 4.6.2 / NVIDIA RTX 4060 / 实际卡面与建成塔绑定", font=font(17), fill=(60, 75, 96))
        for spec in TOWERS:
            source_path = input_dir / f"{spec.index:02d}_{spec.tower_id}_{suffix}_720x1280.png"
            if not source_path.exists():
                raise FileNotFoundError(source_path)
            with Image.open(source_path) as source:
                crop = source.convert("RGB").crop(crop_box)
                crop = crop.resize(cell_size, Image.Resampling.LANCZOS)
            column = (spec.index - 1) % 5
            row = (spec.index - 1) // 5
            x = column * cell_size[0]
            y = header + row * cell_size[1]
            board.paste(crop, (x, y))
            draw.rectangle((x, y, x + cell_size[0] - 1, y + cell_size[1] - 1), outline=(24, 36, 60), width=3)
            label = f"{spec.index:02d}  {spec.name}"
            bounds = draw.textbbox((0, 0), label, font=font(18, True))
            draw.rounded_rectangle((x + 8, y + 8, x + bounds[2] + 22, y + bounds[3] + 20), 6, fill=(255, 250, 235), outline=(24, 36, 60), width=2)
            draw.text((x + 14, y + 12), label, font=font(18, True), fill=(24, 36, 60))
        board.save(output_dir / f"defense_towers_runtime_{suffix}_catalog_720x1280.png", optimize=True)
    print(output_dir)


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    subparsers.add_parser("prepare-refs")
    normalize_parser = subparsers.add_parser("normalize")
    normalize_parser.add_argument("--input-dir", type=Path, required=True)
    one_parser = subparsers.add_parser("normalize-one")
    one_parser.add_argument("--input", type=Path, required=True)
    one_parser.add_argument("--output", type=Path, required=True)
    review_parser = subparsers.add_parser("representative-review")
    review_parser.add_argument("--input", type=Path, required=True)
    review_parser.add_argument("--output", type=Path, required=True)
    runtime_catalog_parser = subparsers.add_parser("runtime-catalog")
    runtime_catalog_parser.add_argument("--input-dir", type=Path, required=True)
    runtime_catalog_parser.add_argument("--output-dir", type=Path, default=RUNTIME_QA_DIR)
    subparsers.add_parser("build-board")
    subparsers.add_parser("publish")
    args = parser.parse_args()

    if args.command == "prepare-refs":
        prepare_refs()
    elif args.command == "normalize":
        normalize_directory(args.input_dir.resolve())
    elif args.command == "normalize-one":
        print(json.dumps(normalize_image(args.input.resolve(), args.output.resolve()), ensure_ascii=False, indent=2))
    elif args.command == "representative-review":
        build_representative_review(args.input.resolve(), args.output.resolve())
        print(args.output.resolve())
    elif args.command == "runtime-catalog":
        build_runtime_catalog(args.input_dir.resolve(), args.output_dir.resolve())
    elif args.command == "build-board":
        build_board()
    elif args.command == "publish":
        publish()


if __name__ == "__main__":
    main()
