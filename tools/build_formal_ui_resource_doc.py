from __future__ import annotations

from datetime import date
from pathlib import Path

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import Image as PdfImage
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


ROOT = Path(__file__).resolve().parents[1]
DOC_PATH = ROOT / "docs" / "FORMAL_UI_RESOURCE_INTEGRATION.md"
PDF_PATH = ROOT / "output" / "pdf" / "formal-ui-resource-integration.pdf"
PREVIEW_PATH = ROOT / "output" / "formal_page_options" / "formal_page_option_b_generated_ui.png"

RESOURCES = [
    ("UI 源图", "assets/ui/formal_arcade/arcade_ui_overlay_source.png", "AI 生成原图，保留洋红背景，便于回溯。"),
    ("透明 UI 覆盖层", "assets/ui/formal_arcade/arcade_ui_overlay_alpha.png", "去除洋红背景后的原始比例透明层。"),
    ("720x1280 覆盖层", "assets/ui/formal_arcade/arcade_ui_overlay_alpha_720x1280.png", "规范化到游戏页面尺寸，用于大厅合成。"),
    ("顶部资源条", "assets/ui/formal_arcade/components/top_resource_bar.png", "金币、宝石、券和设置入口。"),
    ("模式进度条", "assets/ui/formal_arcade/components/mode_progress_panel.png", "荣耀之路、宝箱节点和进度表达。"),
    ("编组卡槽面板", "assets/ui/formal_arcade/components/squad_card_panel.png", "出战动物卡槽和编组区域。"),
    ("主按钮", "assets/ui/formal_arcade/components/primary_cta_button.png", "开始战斗按钮底图。"),
    ("次按钮", "assets/ui/formal_arcade/components/secondary_button.png", "编组或次级操作按钮底图。"),
    ("底部导航", "assets/ui/formal_arcade/components/bottom_nav_bar.png", "大厅、编组、战斗、宝箱、商店五入口。"),
    ("合成预览", "output/formal_page_options/formal_page_option_b_generated_ui.png", "B 街机营地版与生成 UI 资源配合后的页面稿。"),
]


def register_font() -> str:
    for path in [
        Path("C:/Windows/Fonts/NotoSansSC-VF.ttf"),
        Path("C:/Windows/Fonts/msyh.ttc"),
        Path("C:/Windows/Fonts/simhei.ttf"),
    ]:
        if path.exists():
            name = "FormalUiSans"
            if name not in pdfmetrics.getRegisteredFontNames():
                pdfmetrics.registerFont(TTFont(name, str(path)))
            return name
    return "Helvetica"


def write_markdown() -> None:
    DOC_PATH.parent.mkdir(parents=True, exist_ok=True)
    lines = [
        "# 正式 UI 资源配合说明",
        "",
        f"生成日期：{date.today().isoformat()}",
        "",
        "## 目标",
        "",
        "- 解决上一版只有背景正式、UI 仍像系统图的问题。",
        "- 为 B 街机营地版生成一套可复用 UI 资源：资源条、进度面板、卡槽、按钮和底部导航。",
        "- 保持当前动物 PNG 不变，只让 UI 与背景、建筑、动物统一到蓝金街机风。",
        "",
        "## 资源清单",
        "",
        "| 类型 | 路径 | 用途 |",
        "| --- | --- | --- |",
    ]
    for label, path, note in RESOURCES:
        lines.append(f"| {label} | `{path}` | {note} |")
    lines.extend(
        [
            "",
            "## 合成原则",
            "",
            "- 背景继续使用 `background_b_arcade_jungle.png`。",
            "- 动物仍来自 `assets/card_art/animals/`，没有重新生成或改形。",
            "- UI 使用 `arcade_ui_overlay_alpha_720x1280.png` 作为主覆盖层。",
            "- 中文文字、数值和动物卡槽内容由脚本二次叠加，避免 AI 生成乱码。",
            "- 后续进 Godot 时，可以先用整张 overlay 走快速验证，再逐步替换为 components 下的独立切片。",
            "",
            "## 下一步落地建议",
            "",
            "1. 先把大厅改成 `background_b_arcade_jungle.png` 加 `arcade_ui_overlay_alpha_720x1280.png` 的结构。",
            "2. 将资源条数值、关卡进度、编组卡槽和底部导航文字保留为 Godot 绘制文本。",
            "3. 组件成熟后，再用 `components/` 里的切片替换整张 overlay，方便做按钮反馈和局部动效。",
            "4. 主按钮文字目前与双剑图标共享空间，正式落地时建议做成文字在右侧或图标在左侧的固定布局。",
        ]
    )
    DOC_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_pdf() -> None:
    PDF_PATH.parent.mkdir(parents=True, exist_ok=True)
    font_name = register_font()
    base = getSampleStyleSheet()
    title = ParagraphStyle("TitleCN", parent=base["Title"], fontName=font_name, fontSize=22, leading=28)
    heading = ParagraphStyle("HeadingCN", parent=base["Heading2"], fontName=font_name, fontSize=14, leading=18)
    body = ParagraphStyle("BodyCN", parent=base["BodyText"], fontName=font_name, fontSize=9.2, leading=13.5)
    small = ParagraphStyle("SmallCN", parent=base["BodyText"], fontName=font_name, fontSize=7.2, leading=9.4)

    doc = SimpleDocTemplate(
        str(PDF_PATH),
        pagesize=landscape(A4),
        rightMargin=10 * mm,
        leftMargin=10 * mm,
        topMargin=9 * mm,
        bottomMargin=9 * mm,
        title="Formal UI resource integration",
        author="Codex",
    )

    rows = [["类型", "路径", "用途"]]
    for label, path, note in RESOURCES:
        rows.append([label, path, Paragraph(note, small)])
    resource_table = Table(rows, colWidths=[28 * mm, 92 * mm, 78 * mm], repeatRows=1)
    resource_table.setStyle(
        TableStyle(
            [
                ("FONTNAME", (0, 0), (-1, -1), font_name),
                ("FONTSIZE", (0, 0), (-1, -1), 7.0),
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1f5f8b")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#b9c4d0")),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f7fafc")]),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 3),
                ("RIGHTPADDING", (0, 0), (-1, -1), 3),
                ("TOPPADDING", (0, 0), (-1, -1), 3),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
            ]
        )
    )

    preview = PdfImage(str(PREVIEW_PATH), width=82 * mm, height=145.8 * mm)
    notes = [
        Paragraph("正式 UI 资源配合说明", title),
        Paragraph(f"生成日期：{date.today().isoformat()}", body),
        Spacer(1, 3 * mm),
        Paragraph("目标", heading),
        Paragraph("为 B 街机营地版生成可复用 UI 资源，让资源条、按钮、卡槽和底部导航与背景、建筑、现有动物 PNG 形成统一蓝金街机风。", body),
        Spacer(1, 3 * mm),
        Paragraph("资源清单", heading),
        resource_table,
    ]
    layout = Table([[preview, notes]], colWidths=[90 * mm, 176 * mm])
    layout.setStyle(
        TableStyle(
            [
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 0),
                ("RIGHTPADDING", (0, 0), (-1, -1), 6),
                ("TOPPADDING", (0, 0), (-1, -1), 0),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 0),
            ]
        )
    )
    doc.build([layout])


def main() -> int:
    write_markdown()
    write_pdf()
    print(f"Wrote {DOC_PATH.relative_to(ROOT)}")
    print(f"Wrote {PDF_PATH.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
