from __future__ import annotations

import html
import re
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
    KeepTogether,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "docs" / "CURRENT_GAME_STYLE_REFERENCE_RESET.md"
OUTPUT = ROOT / "output" / "pdf" / "current-game-style-reference-reset.pdf"
FONT_REGULAR = Path("C:/Windows/Fonts/msyh.ttc")
FONT_BOLD = Path("C:/Windows/Fonts/msyhbd.ttc")


def register_fonts() -> None:
    pdfmetrics.registerFont(TTFont("CN", str(FONT_REGULAR), subfontIndex=0))
    pdfmetrics.registerFont(TTFont("CN-Bold", str(FONT_BOLD), subfontIndex=0))


def styles() -> dict[str, ParagraphStyle]:
    base = getSampleStyleSheet()
    return {
        "title": ParagraphStyle(
            "TitleCN",
            parent=base["Title"],
            fontName="CN-Bold",
            fontSize=23,
            leading=31,
            textColor=colors.HexColor("#24211D"),
            spaceAfter=10,
        ),
        "h1": ParagraphStyle(
            "H1CN",
            parent=base["Heading1"],
            fontName="CN-Bold",
            fontSize=17,
            leading=23,
            textColor=colors.HexColor("#24211D"),
            spaceBefore=7,
            spaceAfter=7,
        ),
        "h2": ParagraphStyle(
            "H2CN",
            parent=base["Heading2"],
            fontName="CN-Bold",
            fontSize=13.5,
            leading=19,
            textColor=colors.HexColor("#B54131"),
            spaceBefore=8,
            spaceAfter=5,
        ),
        "h3": ParagraphStyle(
            "H3CN",
            parent=base["Heading3"],
            fontName="CN-Bold",
            fontSize=10.5,
            leading=15,
            textColor=colors.HexColor("#287463"),
            spaceBefore=6,
            spaceAfter=3,
        ),
        "body": ParagraphStyle(
            "BodyCN",
            parent=base["BodyText"],
            fontName="CN",
            fontSize=9.1,
            leading=14.1,
            textColor=colors.HexColor("#24211D"),
            spaceAfter=3,
        ),
        "small": ParagraphStyle(
            "SmallCN",
            parent=base["BodyText"],
            fontName="CN",
            fontSize=7.6,
            leading=11,
            textColor=colors.HexColor("#24211D"),
        ),
        "note": ParagraphStyle(
            "NoteCN",
            parent=base["BodyText"],
            fontName="CN",
            fontSize=8.8,
            leading=13.5,
            textColor=colors.HexColor("#5E5147"),
            backColor=colors.HexColor("#FFF4CF"),
            borderColor=colors.HexColor("#E5B94B"),
            borderWidth=0.8,
            borderPadding=8,
            spaceAfter=6,
        ),
    }


def inline_markup(value: str) -> str:
    escaped = html.escape(value)
    escaped = re.sub(
        r"\[([^\]]+)\]\((https?://[^)]+)\)",
        r'<link href="\2" color="#1E6B81"><u>\1</u></link>',
        escaped,
    )
    escaped = re.sub(r"`([^`]+)`", r'<font name="CN-Bold">\1</font>', escaped)
    escaped = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", escaped)
    return escaped


def swatch_table(line: str, body_style: ParagraphStyle) -> Table | None:
    colors_found = re.findall(r"#[0-9A-Fa-f]{6}", line)
    if len(colors_found) < 4:
        return None
    labels = [part.strip() for part in line.split("/")]
    row = []
    for index, color_value in enumerate(colors_found):
        label = labels[index] if index < len(labels) else color_value
        label = re.sub(r"`?#[0-9A-Fa-f]{6}`?", "", label).strip()
        row.append(
            Table(
                [
                    [""],
                    [Paragraph(f"<b>{color_value}</b><br/>{html.escape(label)}", body_style)],
                ],
                colWidths=[26 * mm],
                rowHeights=[13 * mm, 12 * mm],
                style=TableStyle(
                    [
                        ("BACKGROUND", (0, 0), (0, 0), colors.HexColor(color_value)),
                        ("BOX", (0, 0), (-1, -1), 0.6, colors.HexColor("#8F806E")),
                        ("VALIGN", (0, 1), (0, 1), "MIDDLE"),
                        ("ALIGN", (0, 1), (0, 1), "CENTER"),
                        ("LEFTPADDING", (0, 1), (0, 1), 2),
                        ("RIGHTPADDING", (0, 1), (0, 1), 2),
                    ]
                ),
            )
        )
    return Table([row], hAlign="LEFT", colWidths=[27 * mm] * len(row))


def markdown_table(lines: list[str], start: int, style_map: dict[str, ParagraphStyle]) -> tuple[Table, int]:
    rows: list[list[str]] = []
    index = start
    while index < len(lines) and lines[index].strip().startswith("|"):
        cells = [cell.strip() for cell in lines[index].strip().strip("|").split("|")]
        if not all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells):
            rows.append(cells)
        index += 1
    column_count = max(len(row) for row in rows)
    available = A4[0] - 32 * mm
    data = []
    for row in rows:
        row += [""] * (column_count - len(row))
        data.append([Paragraph(inline_markup(cell), style_map["small"]) for cell in row])
    table = Table(data, colWidths=[available / column_count] * column_count, repeatRows=1)
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#F2C14E")),
                ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#75695C")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    return table, index


def build_story(style_map: dict[str, ParagraphStyle]) -> list[object]:
    lines = SOURCE.read_text(encoding="utf-8").splitlines()
    story: list[object] = []
    index = 0
    first_title = True
    while index < len(lines):
        stripped = lines[index].strip()
        if stripped.startswith("|"):
            table, index = markdown_table(lines, index, style_map)
            story.extend([table, Spacer(1, 4 * mm)])
            continue
        if stripped.startswith(">"):
            note_lines = []
            while index < len(lines) and lines[index].strip().startswith(">"):
                note = lines[index].strip()[1:].strip()
                if note:
                    note_lines.append(note)
                index += 1
            story.append(Paragraph(inline_markup(" ".join(note_lines)), style_map["note"]))
            continue
        if stripped.startswith("### "):
            story.append(Paragraph(inline_markup(stripped[4:]), style_map["h3"]))
        elif stripped.startswith("## "):
            title = stripped[3:]
            if title.startswith(("3.", "4.", "5.", "6.")) and story:
                story.append(PageBreak())
            story.append(Paragraph(inline_markup(title), style_map["h2"]))
        elif stripped.startswith("# "):
            style_name = "title" if first_title else "h1"
            story.append(Paragraph(inline_markup(stripped[2:]), style_map[style_name]))
            first_title = False
        elif stripped.startswith("- "):
            story.append(Paragraph(f"- {inline_markup(stripped[2:])}", style_map["body"]))
        elif re.match(r"^\d+\. ", stripped):
            story.append(Paragraph(inline_markup(stripped), style_map["body"]))
        elif stripped:
            swatches = swatch_table(stripped, style_map["small"])
            if swatches:
                story.extend([KeepTogether(swatches), Spacer(1, 4 * mm)])
            else:
                story.append(Paragraph(inline_markup(stripped), style_map["body"]))
        else:
            story.append(Spacer(1, 2 * mm))
        index += 1
    return story


def footer(canvas, document) -> None:
    canvas.saveState()
    canvas.setStrokeColor(colors.HexColor("#D7C8A7"))
    canvas.line(16 * mm, 13 * mm, A4[0] - 16 * mm, 13 * mm)
    canvas.setFont("CN", 7.5)
    canvas.setFillColor(colors.HexColor("#6B6055"))
    canvas.drawString(16 * mm, 8.5 * mm, "占城大师 - 简化视觉风格参考初筛（非效果图）")
    canvas.drawRightString(A4[0] - 16 * mm, 8.5 * mm, str(document.page))
    canvas.restoreState()


def main() -> None:
    register_fonts()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    document = SimpleDocTemplate(
        str(OUTPUT),
        pagesize=A4,
        rightMargin=16 * mm,
        leftMargin=16 * mm,
        topMargin=14 * mm,
        bottomMargin=17 * mm,
        title="占城大师 - 简化视觉风格参考初筛",
        author="Codex Game Studio",
    )
    document.build(build_story(styles()), onFirstPage=footer, onLaterPages=footer)
    print(OUTPUT)


if __name__ == "__main__":
    main()
