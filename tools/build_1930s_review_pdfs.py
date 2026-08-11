from __future__ import annotations

import html
import re
from datetime import date
from pathlib import Path

from PIL import Image as PilImage
from reportlab.lib import colors
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import (
  Image as PdfImage,
  PageBreak,
  Paragraph,
  SimpleDocTemplate,
  Spacer,
  Table,
  TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
PDF_OUT = ROOT / "output" / "pdf"
OVERVIEW = ROOT / "output" / "visual_concepts" / "current_game_1930s_v15_m_uiux_pixel_polish_page_set_overview.png"
FONT_REGULAR = Path("C:/Windows/Fonts/msyh.ttc")
FONT_BOLD = Path("C:/Windows/Fonts/msyhbd.ttc")

DOCUMENTS = (
  (
    ROOT / "docs" / "CURRENT_GAME_1930S_PAGE_STYLE_OPTIONS.md",
    PDF_OUT / "current-game-1930s-page-style-options.pdf",
    "占城大师 1930s 页面效果图方案",
  ),
  (
    ROOT / "docs" / "CURRENT_GAME_1930S_UI_UX_PRO_MAX_AUDIT.md",
    PDF_OUT / "current-game-1930s-ui-ux-pro-max-audit.pdf",
    "占城大师 v15 UI/UX Pro Max 审计",
  ),
)


def register_fonts() -> None:
  pdfmetrics.registerFont(TTFont("CN", str(FONT_REGULAR), subfontIndex=0))
  pdfmetrics.registerFont(TTFont("CN-Bold", str(FONT_BOLD), subfontIndex=0))


def inline_markup(value: str) -> str:
  parts = re.split(r"(`[^`]*`)", value)
  output: list[str] = []
  for part in parts:
    if part.startswith("`") and part.endswith("`"):
      output.append(f'<font name="CN">{html.escape(part[1:-1])}</font>')
      continue
    escaped = html.escape(part)
    escaped = re.sub(r"\*\*(.+?)\*\*", r"<b>\1</b>", escaped)
    escaped = re.sub(r"\[(.+?)\]\((.+?)\)", r"\1", escaped)
    output.append(escaped)
  return "".join(output)


def scaled_image(path: Path, max_width: float, max_height: float) -> PdfImage:
  with PilImage.open(path) as image:
    width, height = image.size
  scale = min(max_width / width, max_height / height)
  return PdfImage(str(path), width=width * scale, height=height * scale)


def make_styles() -> dict[str, ParagraphStyle]:
  base = getSampleStyleSheet()
  return {
    "title": ParagraphStyle(
      "TitleCN",
      parent=base["Title"],
      fontName="CN-Bold",
      fontSize=22,
      leading=30,
      textColor=colors.HexColor("#301E16"),
      spaceAfter=10,
    ),
    "h1": ParagraphStyle(
      "H1CN",
      parent=base["Heading1"],
      fontName="CN-Bold",
      fontSize=18,
      leading=24,
      textColor=colors.HexColor("#301E16"),
      spaceBefore=8,
      spaceAfter=8,
    ),
    "h2": ParagraphStyle(
      "H2CN",
      parent=base["Heading2"],
      fontName="CN-Bold",
      fontSize=14,
      leading=20,
      textColor=colors.HexColor("#7A321F"),
      spaceBefore=9,
      spaceAfter=5,
    ),
    "h3": ParagraphStyle(
      "H3CN",
      parent=base["Heading3"],
      fontName="CN-Bold",
      fontSize=11.5,
      leading=17,
      textColor=colors.HexColor("#266B58"),
      spaceBefore=7,
      spaceAfter=4,
    ),
    "body": ParagraphStyle(
      "BodyCN",
      parent=base["BodyText"],
      fontName="CN",
      fontSize=9.2,
      leading=14.2,
      textColor=colors.HexColor("#301E16"),
      spaceAfter=3,
    ),
    "small": ParagraphStyle(
      "SmallCN",
      parent=base["BodyText"],
      fontName="CN",
      fontSize=7.2,
      leading=10.2,
      textColor=colors.HexColor("#301E16"),
    ),
    "meta": ParagraphStyle(
      "MetaCN",
      parent=base["BodyText"],
      fontName="CN",
      fontSize=9,
      leading=14,
      alignment=1,
      textColor=colors.HexColor("#675347"),
      spaceAfter=8,
    ),
  }


def markdown_image(line: str, document: Path) -> Path | None:
  match = re.fullmatch(r"!\[[^\]]*\]\(([^)]+)\)", line.strip())
  if not match:
    return None
  path = (document.parent / match.group(1)).resolve()
  return path if path.exists() else None


def parse_table(lines: list[str], start: int, styles: dict[str, ParagraphStyle]) -> tuple[Table, int]:
  raw_rows: list[list[str]] = []
  index = start
  while index < len(lines) and lines[index].strip().startswith("|"):
    cells = [cell.strip() for cell in lines[index].strip().strip("|").split("|")]
    if not all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells):
      raw_rows.append(cells)
    index += 1
  columns = max(len(row) for row in raw_rows)
  available = A4[0] - 32 * mm
  widths = [available / columns] * columns
  data = []
  for row in raw_rows:
    row += [""] * (columns - len(row))
    data.append([Paragraph(inline_markup(cell), styles["small"]) for cell in row])
  table = Table(data, colWidths=widths, repeatRows=1, hAlign="LEFT")
  table.setStyle(
    TableStyle(
      [
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#E8C97F")),
        ("TEXTCOLOR", (0, 0), (-1, -1), colors.HexColor("#301E16")),
        ("GRID", (0, 0), (-1, -1), 0.45, colors.HexColor("#7E644A")),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 3),
        ("RIGHTPADDING", (0, 0), (-1, -1), 3),
        ("TOPPADDING", (0, 0), (-1, -1), 3),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
      ]
    )
  )
  return table, index


def markdown_story(document: Path, styles: dict[str, ParagraphStyle]) -> list[object]:
  lines = document.read_text(encoding="utf-8").splitlines()
  story: list[object] = []
  index = 0
  in_code = False
  while index < len(lines):
    line = lines[index].rstrip()
    stripped = line.strip()
    if stripped.startswith("```"):
      in_code = not in_code
      index += 1
      continue
    if in_code:
      story.append(Paragraph(inline_markup(stripped), styles["small"]))
      index += 1
      continue
    image_path = markdown_image(stripped, document)
    if image_path:
      image = scaled_image(image_path, A4[0] - 36 * mm, 225 * mm)
      image.hAlign = "CENTER"
      story.extend([Spacer(1, 4 * mm), image, Spacer(1, 4 * mm)])
      index += 1
      continue
    if stripped.startswith("|"):
      table, index = parse_table(lines, index, styles)
      story.extend([table, Spacer(1, 4 * mm)])
      continue
    if stripped.startswith("### "):
      story.append(Paragraph(inline_markup(stripped[4:]), styles["h3"]))
    elif stripped.startswith("## "):
      story.append(Paragraph(inline_markup(stripped[3:]), styles["h2"]))
    elif stripped.startswith("# "):
      story.append(Paragraph(inline_markup(stripped[2:]), styles["h1"]))
    elif stripped.startswith("- "):
      story.append(Paragraph(f"• {inline_markup(stripped[2:])}", styles["body"]))
    elif re.match(r"^\d+\. ", stripped):
      story.append(Paragraph(inline_markup(stripped), styles["body"]))
    elif stripped:
      story.append(Paragraph(inline_markup(stripped), styles["body"]))
    else:
      story.append(Spacer(1, 2.4 * mm))
    index += 1
  return story


def page_footer(canvas, doc, title: str) -> None:
  canvas.saveState()
  canvas.setFont("CN", 7.5)
  canvas.setFillColor(colors.HexColor("#675347"))
  canvas.drawString(16 * mm, 10 * mm, title)
  canvas.drawRightString(A4[0] - 16 * mm, 10 * mm, f"{doc.page}")
  canvas.restoreState()


def build_pdf(document: Path, output: Path, title: str) -> None:
  styles = make_styles()
  output.parent.mkdir(parents=True, exist_ok=True)
  pdf = SimpleDocTemplate(
    str(output),
    pagesize=A4,
    leftMargin=16 * mm,
    rightMargin=16 * mm,
    topMargin=15 * mm,
    bottomMargin=17 * mm,
    title=title,
    author="Codex",
  )
  story: list[object] = [
    Paragraph(title, styles["title"]),
    Paragraph(f"纯效果图评审稿 · {date.today().isoformat()} · 禁止实装", styles["meta"]),
  ]
  if OVERVIEW.exists():
    overview = scaled_image(OVERVIEW, 142 * mm, 210 * mm)
    overview.hAlign = "CENTER"
    story.extend([overview, PageBreak()])
  story.extend(markdown_story(document, styles))
  pdf.build(
    story,
    onFirstPage=lambda canvas, doc: page_footer(canvas, doc, title),
    onLaterPages=lambda canvas, doc: page_footer(canvas, doc, title),
  )


def main() -> int:
  register_fonts()
  for document, output, title in DOCUMENTS:
    build_pdf(document, output, title)
    print(f"Wrote {output.relative_to(ROOT).as_posix()}")
  return 0


if __name__ == "__main__":
  raise SystemExit(main())
