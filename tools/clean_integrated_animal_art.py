#!/usr/bin/env python3
"""Clean exported-board residue and audit battle groundlines for integrated animal art.

The cleanup is intentionally conservative: pixels with alpha >= 64 always survive,
and lower-alpha pixels survive when they are within eight source pixels of that
high-confidence subject mask. The tool never crops, scales, or repaints an image.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import json
import re
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter


ALPHA_CONFIDENCE_THRESHOLD = 64
SUBJECT_EDGE_RADIUS = 8
EXPECTED_CANVAS = (480, 480)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def integrated_ids(project_root: Path) -> list[str]:
    source = (project_root / "scripts/app/main.gd").read_text(encoding="utf-8")
    try:
        block = source.split("const INTEGRATED_ANIMAL_ART_CARD_IDS = {", 1)[1].split("}", 1)[0]
    except IndexError as error:
        raise RuntimeError("Unable to locate INTEGRATED_ANIMAL_ART_CARD_IDS in main.gd") from error
    ids = re.findall(r'^\s*"([^"]+)"\s*:', block, re.MULTILINE)
    if len(ids) != 40 or len(ids) != len(set(ids)):
        raise RuntimeError(f"Expected 40 unique integrated animal IDs, found {len(ids)}")
    return ids


def alpha_bottom_padding(image: Image.Image) -> int:
    alpha = image.convert("RGBA").getchannel("A")
    bounds = alpha.getbbox()
    if bounds is None:
        raise RuntimeError("Animal image has no non-transparent pixels")
    return image.height - bounds[3]


def cleaned_copy(image: Image.Image) -> tuple[Image.Image, int, int]:
    rgba = image.convert("RGBA")
    alpha = rgba.getchannel("A")
    confident = alpha.point(lambda value: 255 if value >= ALPHA_CONFIDENCE_THRESHOLD else 0)
    near_subject = confident.filter(ImageFilter.MaxFilter(SUBJECT_EDGE_RADIUS * 2 + 1))

    output = rgba.copy()
    source_pixels = rgba.load()
    output_pixels = output.load()
    keep_pixels = near_subject.load()
    removed = 0
    removed_confident = 0
    for y in range(rgba.height):
        for x in range(rgba.width):
            pixel = source_pixels[x, y]
            if pixel[3] == 0 or keep_pixels[x, y] != 0:
                continue
            removed += 1
            if pixel[3] >= ALPHA_CONFIDENCE_THRESHOLD:
                removed_confident += 1
            output_pixels[x, y] = (0, 0, 0, 0)
    return output, removed, removed_confident


def analyze(project_root: Path, apply: bool) -> list[dict[str, str | int]]:
    art_dir = project_root / "assets/card_art/animals"
    reports: list[dict[str, str | int]] = []
    for animal_id in integrated_ids(project_root):
        path = art_dir / f"{animal_id}.png"
        if not path.is_file():
            raise RuntimeError(f"Missing integrated animal source: {path}")
        before_hash = sha256(path)
        original = Image.open(path).convert("RGBA")
        if original.size != EXPECTED_CANVAS:
            raise RuntimeError(f"Unexpected canvas for {animal_id}: {original.size}")
        before_padding = alpha_bottom_padding(original)
        cleaned, removed, removed_confident = cleaned_copy(original)
        if removed_confident:
            raise RuntimeError(f"Cleanup would remove {removed_confident} alpha-64+ pixels from {animal_id}")
        after_padding = alpha_bottom_padding(cleaned)
        if apply and removed:
            cleaned.save(path, format="PNG", optimize=False, compress_level=9)
        after_hash = sha256(path) if apply else _image_sha256(cleaned)
        reports.append(
            {
                "card_id": animal_id,
                "width": original.width,
                "height": original.height,
                "sha256_before": before_hash,
                "sha256_after": after_hash,
                "removed_pixels": removed,
                "removed_alpha64_pixels": removed_confident,
                "bottom_padding_before": before_padding,
                "bottom_padding_after": after_padding,
                "changed": "yes" if removed else "no",
            }
        )
    return reports


def _image_sha256(image: Image.Image) -> str:
    digest = hashlib.sha256()
    digest.update(image.mode.encode("ascii"))
    digest.update(str(image.size).encode("ascii"))
    digest.update(image.tobytes())
    return digest.hexdigest()


def write_report(path: Path, reports: list[dict[str, str | int]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="", encoding="utf-8-sig") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(reports[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(reports)


def update_manifest(path: Path, project_root: Path, reports: list[dict[str, str | int]]) -> None:
    with path.open("r", newline="", encoding="utf-8-sig") as handle:
        rows = list(csv.DictReader(handle))
    report_by_id = {str(row["card_id"]): row for row in reports}
    for row in rows:
        animal_id = row.get("card_id", "")
        report = report_by_id.get(animal_id)
        if report is None:
            continue
        asset = project_root / "assets/card_art/animals" / f"{animal_id}.png"
        row["sha256"] = sha256(asset)
        if report["changed"] == "yes":
            marker = "deterministic low-alpha canvas cleanup 2026-08-11"
            notes = row.get("notes", "")
            if marker not in notes:
                row["notes"] = f"{notes}; {marker}" if notes else marker
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]), lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)


def make_source_board(project_root: Path, output: Path, reports: list[dict[str, str | int]]) -> None:
    cols = 4
    cell_w, cell_h = 250, 230
    rows = (len(reports) + cols - 1) // cols
    board = Image.new("RGB", (cols * cell_w, rows * cell_h), (151, 224, 111))
    draw = ImageDraw.Draw(board)
    art_dir = project_root / "assets/card_art/animals"
    foot_y = 174
    bar_top = foot_y + 18
    for index, report in enumerate(reports):
        animal_id = str(report["card_id"])
        image = Image.open(art_dir / f"{animal_id}.png").convert("RGBA")
        alpha_bounds = image.getchannel("A").getbbox()
        if alpha_bounds is None:
            raise RuntimeError(f"Empty source image: {animal_id}")
        visible_height = alpha_bounds[3] - alpha_bounds[1]
        scale = min(150.0 / visible_height, 150.0 / (alpha_bounds[2] - alpha_bounds[0]))
        rendered = image.resize(
            (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
            Image.Resampling.LANCZOS,
        )
        rendered_bounds = rendered.getchannel("A").getbbox()
        if rendered_bounds is None:
            raise RuntimeError(f"Empty rendered image: {animal_id}")
        x0 = (index % cols) * cell_w
        y0 = (index // cols) * cell_h
        subject_x = x0 + (cell_w - (rendered_bounds[2] - rendered_bounds[0])) // 2
        paste_x = subject_x - rendered_bounds[0]
        paste_y = y0 + foot_y - rendered_bounds[3]
        board.paste(rendered, (paste_x, paste_y), rendered)
        draw.line((x0 + 16, y0 + foot_y, x0 + cell_w - 16, y0 + foot_y), fill=(230, 45, 45), width=2)
        draw.rectangle((x0 + 91, y0 + bar_top, x0 + 159, y0 + bar_top + 10), fill=(12, 16, 21), outline="black")
        draw.rectangle((x0 + 96, y0 + bar_top + 3, x0 + 145, y0 + bar_top + 6), fill=(118, 192, 104))
        draw.rectangle((x0, y0, x0 + cell_w - 1, y0 + cell_h - 1), outline=(70, 90, 70))
        draw.text(
            (x0 + 8, y0 + 207),
            f"{index + 1:02d} {animal_id} pad={report['bottom_padding_after']}px",
            fill=(15, 20, 15),
        )
    output.parent.mkdir(parents=True, exist_ok=True)
    board.save(output)


def make_runtime_board(project_root: Path, screenshots: Path, output: Path) -> None:
    ids = integrated_ids(project_root)
    cols = 4
    crop_box = (240, 590, 480, 810)
    cell_w, cell_h = 260, 250
    rows = (len(ids) + cols - 1) // cols
    board = Image.new("RGB", (cols * cell_w, rows * cell_h), (232, 232, 232))
    draw = ImageDraw.Draw(board)
    missing = []
    for index, animal_id in enumerate(ids):
        source = screenshots / f"battle_{animal_id}.png"
        if not source.is_file():
            missing.append(str(source))
            continue
        screenshot = Image.open(source).convert("RGB")
        if screenshot.size != (720, 1280):
            raise RuntimeError(f"Unexpected runtime capture size for {animal_id}: {screenshot.size}")
        crop = screenshot.crop(crop_box)
        x0 = (index % cols) * cell_w
        y0 = (index // cols) * cell_h
        board.paste(crop, (x0 + 10, y0 + 10))
        draw.text((x0 + 10, y0 + 232), f"{index + 1:02d} {animal_id}", fill=(10, 10, 10))
        draw.rectangle((x0, y0, x0 + cell_w - 1, y0 + cell_h - 1), outline=(80, 80, 80))
    if missing:
        raise RuntimeError("Missing runtime captures:\n" + "\n".join(missing))
    output.parent.mkdir(parents=True, exist_ok=True)
    board.save(output)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--apply", action="store_true", help="Apply the conservative cleanup in place")
    parser.add_argument("--report", type=Path, help="Write the 40-card cleanup CSV")
    parser.add_argument("--manifest", type=Path, help="Update the existing source manifest after --apply")
    parser.add_argument("--source-board", type=Path, help="Write the 40-card cleaned-source board")
    parser.add_argument("--runtime-screenshots", type=Path, help="Directory containing 40 battle_*.png captures")
    parser.add_argument("--runtime-board", type=Path, help="Write a 40-card runtime crop board")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    project_root = args.project_root.resolve()
    reports = analyze(project_root, args.apply)
    if args.report:
        write_report(args.report.resolve(), reports)
    if args.manifest:
        if not args.apply:
            raise RuntimeError("--manifest requires --apply")
        update_manifest(args.manifest.resolve(), project_root, reports)
    if args.source_board:
        make_source_board(project_root, args.source_board.resolve(), reports)
    if args.runtime_screenshots or args.runtime_board:
        if not args.runtime_screenshots or not args.runtime_board:
            raise RuntimeError("--runtime-screenshots and --runtime-board must be used together")
        make_runtime_board(project_root, args.runtime_screenshots.resolve(), args.runtime_board.resolve())

    changed = [row for row in reports if row["changed"] == "yes"]
    result = {
        "status": "APPLIED" if args.apply else ("CLEAN" if not changed else "RESIDUE_FOUND"),
        "integrated_count": len(reports),
        "changed_count": len(changed),
        "removed_pixels": sum(int(row["removed_pixels"]) for row in reports),
        "removed_alpha64_pixels": sum(int(row["removed_alpha64_pixels"]) for row in reports),
        "changed_ids": [row["card_id"] for row in changed],
    }
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0 if args.apply or not changed else 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except Exception as error:  # pragma: no cover - CLI guard
        print(json.dumps({"status": "ERROR", "error": str(error)}, ensure_ascii=False, indent=2), file=sys.stderr)
        sys.exit(2)
