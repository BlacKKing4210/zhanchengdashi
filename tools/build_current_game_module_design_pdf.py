from __future__ import annotations

import os
from datetime import date
from pathlib import Path
from xml.sax.saxutils import escape

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase.cidfonts import UnicodeCIDFont
from reportlab.pdfbase.pdfmetrics import registerFont
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    Image as RLImage,
    KeepTogether,
    LongTable,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    TableStyle,
)
from PIL import Image as PILImage


ROOT = Path(__file__).resolve().parents[1]


def project_path_from_env(name: str, default: Path) -> Path:
    value = os.environ.get(name, "").strip()
    if value == "":
        return default
    path = Path(value)
    return path if path.is_absolute() else ROOT / path


def project_relative(path: Path) -> str:
    try:
        return path.relative_to(ROOT).as_posix()
    except ValueError:
        return str(path)


SOURCE_PATH = project_path_from_env("DOC_SOURCE_PATH", ROOT / "design" / "current_game_module_design.md")
OUTPUT_PATH = project_path_from_env("DOC_OUTPUT_PATH", ROOT / "output" / "pdf" / "current-game-module-design.pdf")
DOC_TITLE = os.environ.get("DOC_TITLE", "Jungle Law current game module design")
SOURCE_LABEL = project_relative(SOURCE_PATH)


def register_project_font() -> str:
    candidates = [
        Path("C:/Windows/Fonts/NotoSansSC-VF.ttf"),
        Path("C:/Windows/Fonts/msyh.ttc"),
        Path("C:/Windows/Fonts/simhei.ttf"),
    ]
    for font_path in candidates:
        if font_path.exists():
            registerFont(TTFont("ProjectSans", str(font_path)))
            return "ProjectSans"
    registerFont(UnicodeCIDFont("STSong-Light"))
    return "STSong-Light"


def paragraph(text: str, style: ParagraphStyle) -> Paragraph:
    return Paragraph(escape(text), style)


def markdown_inline(text: str) -> str:
    escaped = escape(text)
    parts = escaped.split("`")
    for index in range(1, len(parts), 2):
        parts[index] = f'<font color="#0f766e">{parts[index]}</font>'
    return "".join(parts)


def rich_paragraph(text: str, style: ParagraphStyle) -> Paragraph:
    return Paragraph(markdown_inline(text), style)


def bullet_paragraph(text: str, style: ParagraphStyle) -> Paragraph:
    return Paragraph(markdown_inline(text), style, bulletText="-")


def markdown_image(line: str) -> tuple[str, Path] | None:
    if not line.startswith("![") or "](" not in line or not line.endswith(")"):
        return None
    label_end = line.find("]")
    path_start = line.find("](")
    alt = line[2:label_end].strip()
    raw_path = line[path_start + 2 : -1].strip()
    if "://" in raw_path:
        return None
    image_path = Path(raw_path)
    candidates = [image_path] if image_path.is_absolute() else [SOURCE_PATH.parent / image_path, ROOT / image_path]
    for candidate in candidates:
        resolved = candidate.resolve()
        if resolved.exists():
            return alt, resolved
    return alt, candidates[0].resolve()


def split_table_row(line: str) -> list[str]:
    return [cell.strip() for cell in line.strip().strip("|").split("|")]


def is_table_separator(line: str) -> bool:
    stripped = line.strip()
    if not stripped.startswith("|"):
        return False
    cells = split_table_row(stripped)
    return all(cell.replace("-", "").replace(":", "").strip() == "" for cell in cells)


def table_widths(column_count: int) -> list[float]:
    total = 174 * mm
    if column_count == 2:
        return [54 * mm, total - 54 * mm]
    if column_count == 3:
        return [42 * mm, 42 * mm, total - 84 * mm]
    if column_count == 4:
        return [32 * mm, 34 * mm, 56 * mm, total - 122 * mm]
    return [total / max(1, column_count)] * column_count


def add_table(story: list, rows: list[list[str]], styles: dict[str, ParagraphStyle]) -> None:
    if len(rows) < 2:
        return
    header = rows[0]
    body = rows[2:] if len(rows) > 2 and is_table_separator("|" + "|".join(rows[1]) + "|") else rows[1:]
    data = [[rich_paragraph(cell, styles["TableHead"]) for cell in header]]
    for row in body:
        padded = row + [""] * (len(header) - len(row))
        data.append([rich_paragraph(cell, styles["TableCell"]) for cell in padded[: len(header)]])
    table = LongTable(data, colWidths=table_widths(len(header)), repeatRows=1)
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1f5f8b")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#b9c4d0")),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f7fafc")]),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    story.append(table)
    story.append(Spacer(1, 4 * mm))


def add_code_block(story: list, lines: list[str], styles: dict[str, ParagraphStyle]) -> None:
    if not lines:
        return
    block = []
    for line in lines:
        block.append(paragraph(line if line else " ", styles["Code"]))
    story.append(KeepTogether(block))
    story.append(Spacer(1, 4 * mm))


def add_markdown_image(story: list, alt: str, path: Path, styles: dict[str, ParagraphStyle]) -> None:
    if not path.exists():
        story.append(rich_paragraph(f"[图片缺失] {alt}: {project_relative(path)}", styles["Body"]))
        story.append(Spacer(1, 3 * mm))
        return
    with PILImage.open(path) as image:
        width_px, height_px = image.size
    max_width = 174 * mm
    max_height = 112 * mm
    scale = min(max_width / width_px, max_height / height_px)
    preview = RLImage(str(path), width=width_px * scale, height=height_px * scale)
    story.append(KeepTogether([preview, paragraph(f"图：{alt} | {project_relative(path)}", styles["Caption"])]))
    story.append(Spacer(1, 4 * mm))


def build_story(markdown: str, styles: dict[str, ParagraphStyle]) -> list:
    story: list = []
    lines = markdown.splitlines()
    index = 0
    in_code = False
    code_lines: list[str] = []
    table_rows: list[list[str]] = []

    def flush_table() -> None:
        nonlocal table_rows
        if table_rows:
            add_table(story, table_rows, styles)
            table_rows = []

    while index < len(lines):
        raw = lines[index]
        line = raw.rstrip()

        if line.startswith("```"):
            if in_code:
                add_code_block(story, code_lines, styles)
                code_lines = []
                in_code = False
            else:
                flush_table()
                in_code = True
            index += 1
            continue

        if in_code:
            code_lines.append(line)
            index += 1
            continue

        if line.startswith("|"):
            table_rows.append(split_table_row(line))
            index += 1
            continue

        flush_table()

        stripped = line.strip()
        if not stripped:
            story.append(Spacer(1, 2 * mm))
        elif image_info := markdown_image(stripped):
            add_markdown_image(story, image_info[0], image_info[1], styles)
        elif stripped.startswith("# "):
            story.append(paragraph(stripped[2:], styles["Title"]))
            story.append(paragraph(f"PDF 生成日期：{date.today().isoformat()} | 源文件：{SOURCE_LABEL}", styles["Meta"]))
        elif stripped.startswith("## "):
            if stripped.startswith("## 1."):
                story.append(PageBreak())
            story.append(paragraph(stripped[3:], styles["Heading2"]))
        elif stripped.startswith("### "):
            story.append(paragraph(stripped[4:], styles["Heading3"]))
        elif stripped.startswith("- "):
            story.append(bullet_paragraph(stripped[2:], styles["Bullet"]))
        elif stripped[:2].isdigit() and ". " in stripped[:5]:
            story.append(rich_paragraph(stripped, styles["Bullet"]))
        else:
            story.append(rich_paragraph(stripped, styles["Body"]))
        index += 1

    flush_table()
    if code_lines:
        add_code_block(story, code_lines, styles)
    return story


def footer(canvas, doc) -> None:
    canvas.saveState()
    canvas.setFont("ProjectSans", 8)
    canvas.setFillColor(colors.HexColor("#64748b"))
    canvas.drawRightString(196 * mm, 10 * mm, f"Page {doc.page}")
    canvas.restoreState()


def build_pdf() -> None:
    font_name = register_project_font()
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    base = getSampleStyleSheet()
    styles = {
        "Title": ParagraphStyle(
            "Title",
            parent=base["Title"],
            fontName=font_name,
            fontSize=21,
            leading=28,
            textColor=colors.HexColor("#123047"),
            spaceAfter=5 * mm,
        ),
        "Meta": ParagraphStyle(
            "Meta",
            parent=base["Normal"],
            fontName=font_name,
            fontSize=8.5,
            leading=12,
            textColor=colors.HexColor("#64748b"),
            spaceAfter=8 * mm,
        ),
        "Heading2": ParagraphStyle(
            "Heading2",
            parent=base["Heading2"],
            fontName=font_name,
            fontSize=14.5,
            leading=19,
            textColor=colors.HexColor("#0f172a"),
            spaceBefore=4 * mm,
            spaceAfter=3 * mm,
        ),
        "Heading3": ParagraphStyle(
            "Heading3",
            parent=base["Heading3"],
            fontName=font_name,
            fontSize=11.5,
            leading=16,
            textColor=colors.HexColor("#1f5f8b"),
            spaceBefore=2.5 * mm,
            spaceAfter=2 * mm,
        ),
        "Body": ParagraphStyle(
            "Body",
            parent=base["BodyText"],
            fontName=font_name,
            fontSize=9.7,
            leading=14.2,
            textColor=colors.HexColor("#1f2937"),
            spaceAfter=1.4 * mm,
        ),
        "Bullet": ParagraphStyle(
            "Bullet",
            parent=base["BodyText"],
            fontName=font_name,
            fontSize=9.5,
            leading=13.8,
            leftIndent=5 * mm,
            firstLineIndent=0,
            bulletIndent=0,
            bulletFontName=font_name,
            bulletFontSize=9.5,
            textColor=colors.HexColor("#1f2937"),
            spaceAfter=1.1 * mm,
        ),
        "Code": ParagraphStyle(
            "Code",
            parent=base["BodyText"],
            fontName=font_name,
            fontSize=8.2,
            leading=11,
            leftIndent=3 * mm,
            rightIndent=3 * mm,
            backColor=colors.HexColor("#f1f5f9"),
            textColor=colors.HexColor("#334155"),
            spaceAfter=0.5 * mm,
        ),
        "Caption": ParagraphStyle(
            "Caption",
            parent=base["BodyText"],
            fontName=font_name,
            fontSize=7.8,
            leading=10,
            alignment=1,
            textColor=colors.HexColor("#64748b"),
            spaceBefore=1.2 * mm,
        ),
        "TableHead": ParagraphStyle(
            "TableHead",
            parent=base["BodyText"],
            fontName=font_name,
            fontSize=8.1,
            leading=10.5,
            textColor=colors.white,
        ),
        "TableCell": ParagraphStyle(
            "TableCell",
            parent=base["BodyText"],
            fontName=font_name,
            fontSize=7.8,
            leading=10.4,
            textColor=colors.HexColor("#1f2937"),
        ),
    }

    doc = SimpleDocTemplate(
        str(OUTPUT_PATH),
        pagesize=A4,
        rightMargin=18 * mm,
        leftMargin=18 * mm,
        topMargin=17 * mm,
        bottomMargin=16 * mm,
        title=DOC_TITLE,
        author="Codex",
    )
    markdown = SOURCE_PATH.read_text(encoding="utf-8")
    story = build_story(markdown, styles)
    doc.build(story, onFirstPage=footer, onLaterPages=footer)


if __name__ == "__main__":
    build_pdf()
