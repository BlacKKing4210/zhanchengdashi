#!/usr/bin/env python3
"""Build immutable reference and labeled review boards for defense-tower art."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
TOWERS = [
    ("rabbit", "兔子哨塔", 2),
    ("falcon", "猎鹰瞭望塔", 3),
    ("boar", "野猪重弩塔", 3),
    ("squirrel", "松鼠掠金塔", 3),
    ("sparrow", "麻雀速弩塔", 4),
    ("turtle", "龟甲壁垒塔", 4),
    ("parrot", "鹦鹉双弩塔", 4),
    ("tiger", "老虎赏金塔", 5),
    ("golden_eagle", "金雕领空塔", 5),
    ("mammoth", "猛犸震地塔", 5),
]


def _font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    name = "msyhbd.ttc" if bold else "msyh.ttc"
    path = Path("C:/Windows/Fonts") / name
    return ImageFont.truetype(str(path), size=size)


def _fit(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    image = image.convert("RGBA")
    image.thumbnail(size, Image.Resampling.LANCZOS)
    return image


def build_reference_sheet(output: Path) -> None:
    cell_w, art_h, label_h = 512, 512, 64
    sheet = Image.new("RGBA", (cell_w * 5, (art_h + label_h) * 2), "#F5F2E8")
    draw = ImageDraw.Draw(sheet)
    font = _font(26, bold=True)
    for index, (animal_id, _, _) in enumerate(TOWERS):
        column, row = index % 5, index // 5
        left, top = column * cell_w, row * (art_h + label_h)
        source = Image.open(ROOT / "assets" / "card_art" / "animals" / f"{animal_id}.png")
        art = _fit(source, (460, 460))
        x = left + (cell_w - art.width) // 2
        y = top + (art_h - art.height) // 2
        sheet.alpha_composite(art, (x, y))
        label = f"{index + 1:02d}  {animal_id}"
        box = draw.textbbox((0, 0), label, font=font)
        draw.text(
            (left + (cell_w - (box[2] - box[0])) // 2, top + art_h + 13),
            label,
            fill="#172033",
            font=font,
        )
        draw.rectangle((left, top, left + cell_w - 1, top + art_h + label_h - 1), outline="#8A93A3", width=2)
    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.convert("RGB").save(output, quality=95)


def label_review_board(source: Path, output: Path, variant: str, display_name: str = "") -> dict[str, object]:
    source = source.resolve()
    output = output.resolve()
    raw = Image.open(source).convert("RGBA")
    width, height = raw.size
    half = height // 2
    title_h, label_h = 96, 58
    canvas = Image.new("RGBA", (width, height + title_h + label_h * 2), "#151D2C")
    canvas.alpha_composite(raw.crop((0, 0, width, half)), (0, title_h))
    canvas.alpha_composite(raw.crop((0, half, width, height)), (0, title_h + half + label_h))
    draw = ImageDraw.Draw(canvas)
    title_font = _font(max(24, width // 44), bold=True)
    label_font = _font(max(16, width // 80), bold=True)
    status_font = _font(max(14, width // 100))
    variant_title = f"{variant}（{display_name}）" if display_name else variant
    title = f"防御塔建筑化包装方案 {variant_title} · 候选评审图"
    draw.text((28, 17), title, fill="#FFFFFF", font=title_font)
    status = "建筑主体 · 无完整动物站塔 · NOT_RUNTIME · 需制作人整组确认"
    status_box = draw.textbbox((0, 0), status, font=status_font)
    draw.text((width - (status_box[2] - status_box[0]) - 28, 34), status, fill="#FFCB5C", font=status_font)
    rarity_colors = {2: "#57C761", 3: "#3D9EFF", 4: "#AB42E6", 5: "#FF9E14"}
    cell_w = width / 5.0
    for index, (_, name, rarity) in enumerate(TOWERS):
        column, row = index % 5, index // 5
        band_y = title_h + half if row == 0 else title_h + height + label_h
        x0 = int(column * cell_w)
        x1 = int((column + 1) * cell_w)
        draw.rectangle((x0, band_y, x1 - 1, band_y + label_h - 1), fill="#202B40")
        draw.rectangle((x0 + 8, band_y + 8, x0 + 18, band_y + label_h - 9), fill=rarity_colors[rarity])
        label = f"{index + 1:02d} {name} · 品质{rarity}"
        box = draw.textbbox((0, 0), label, font=label_font)
        tx = x0 + (x1 - x0 - (box[2] - box[0])) // 2 + 5
        draw.text((tx, band_y + 13), label, fill="#FFFFFF", font=label_font)
        draw.rectangle((x0, title_h + (0 if row == 0 else half + label_h), x1 - 1,
                        title_h + (half - 1 if row == 0 else height + label_h - 1)),
                       outline=rarity_colors[rarity], width=4)
    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.convert("RGB").save(output, quality=96)
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    cell_order = []
    for index, (animal_id, name, rarity) in enumerate(TOWERS):
        column, row = index % 5, index // 5
        x0, x1 = int(column * width / 5), int((column + 1) * width / 5)
        y0, y1 = int(row * height / 2), int((row + 1) * height / 2)
        cell_order.append({
            "cell": index + 1,
            "animal_id": animal_id,
            "tower_name": name,
            "rarity": rarity,
            "source_cell_rect": [x0, y0, x1 - x0, y1 - y0],
        })
    try:
        source_path = source.relative_to(ROOT).as_posix()
    except ValueError:
        source_path = str(source)
    return {
        "variant": variant,
        "path": output.relative_to(ROOT).as_posix(),
        "sha256": digest,
        "status": "NOT_RUNTIME",
        "board_size": [canvas.width, canvas.height],
        "source_path": source_path,
        "source_size": [width, height],
        "source_sha256": hashlib.sha256(source.read_bytes()).hexdigest(),
        "cell_order": cell_order,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    reference = subparsers.add_parser("reference")
    reference.add_argument("--output", type=Path, required=True)
    label = subparsers.add_parser("label")
    label.add_argument("--source", type=Path, required=True)
    label.add_argument("--output", type=Path, required=True)
    label.add_argument("--variant", required=True)
    label.add_argument("--display-name", default="")
    label.add_argument("--manifest", type=Path)
    args = parser.parse_args()
    if args.command == "reference":
        build_reference_sheet(args.output)
        return
    record = label_review_board(args.source, args.output, args.variant, args.display_name)
    if args.manifest:
        args.manifest.parent.mkdir(parents=True, exist_ok=True)
        payload: dict[str, object] = {
            "feature_id": "F-ZC-DEFENSE-TOWER-005",
            "version": "2.1",
            "direction": "architecture_first_animal_motifs",
            "status": "NOT_RUNTIME",
            "approval": None,
            "review_status": "READY_FOR_PRODUCER_DIRECTION_SELECTION",
            "runtime_readiness": "DIRECTION_REVIEW_ONLY_REGENERATE_TRANSPARENT_ASSETS_AFTER_APPROVAL",
            "constraints": [
                "tower_body_is_primary",
                "no_full_animal_on_tower",
                "animal_motifs_are_architectural_only",
                "one_primary_weapon_or_skill_prop",
            ],
            "boards": [],
        }
        if args.manifest.exists():
            payload = json.loads(args.manifest.read_text(encoding="utf-8"))
        payload["version"] = "2.1"
        payload["direction"] = "architecture_first_animal_motifs"
        payload["status"] = "NOT_RUNTIME"
        payload["approval"] = None
        payload["review_status"] = "READY_FOR_PRODUCER_DIRECTION_SELECTION"
        payload["runtime_readiness"] = "DIRECTION_REVIEW_ONLY_REGENERATE_TRANSPARENT_ASSETS_AFTER_APPROVAL"
        payload["constraints"] = [
            "tower_body_is_primary",
            "no_full_animal_on_tower",
            "animal_motifs_are_architectural_only",
            "one_primary_weapon_or_skill_prop",
        ]
        boards = [item for item in payload.get("boards", []) if item.get("variant") != args.variant]
        boards.append(record)
        payload["boards"] = sorted(boards, key=lambda item: item["variant"])
        args.manifest.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
