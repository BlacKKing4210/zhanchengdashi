from __future__ import annotations

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
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)


ROOT = Path(__file__).resolve().parents[1]
OUTPUT_PATH = ROOT / "output" / "pdf" / "project-foundation.pdf"


def paragraph(text: str, style: ParagraphStyle) -> Paragraph:
    return Paragraph(escape(text), style)


def add_section(story: list, heading: str, lines: list[str], styles: dict[str, ParagraphStyle]) -> None:
    story.append(paragraph(heading, styles["Heading2"]))
    for line in lines:
        story.append(paragraph(line, styles["Body"]))
    story.append(Spacer(1, 4 * mm))


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


def build_pdf() -> None:
    font_name = register_project_font()
    OUTPUT_PATH.parent.mkdir(parents=True, exist_ok=True)

    base = getSampleStyleSheet()
    styles = {
        "Title": ParagraphStyle(
            "Title",
            parent=base["Title"],
            fontName=font_name,
            fontSize=22,
            leading=28,
            textColor=colors.HexColor("#1f2937"),
            spaceAfter=8 * mm,
        ),
        "Meta": ParagraphStyle(
            "Meta",
            parent=base["Normal"],
            fontName=font_name,
            fontSize=9,
            leading=13,
            textColor=colors.HexColor("#64748b"),
            spaceAfter=8 * mm,
        ),
        "Heading2": ParagraphStyle(
            "Heading2",
            parent=base["Heading2"],
            fontName=font_name,
            fontSize=14,
            leading=19,
            textColor=colors.HexColor("#0f172a"),
            spaceBefore=4 * mm,
            spaceAfter=3 * mm,
        ),
        "Body": ParagraphStyle(
            "Body",
            parent=base["BodyText"],
            fontName=font_name,
            fontSize=10.5,
            leading=16,
            textColor=colors.HexColor("#1f2937"),
            spaceAfter=2 * mm,
        ),
        "Small": ParagraphStyle(
            "Small",
            parent=base["BodyText"],
            fontName=font_name,
            fontSize=9,
            leading=13,
            textColor=colors.HexColor("#334155"),
        ),
    }

    doc = SimpleDocTemplate(
        str(OUTPUT_PATH),
        pagesize=A4,
        rightMargin=18 * mm,
        leftMargin=18 * mm,
        topMargin=18 * mm,
        bottomMargin=16 * mm,
        title="zhanchengdashi project foundation",
        author="Codex",
    )

    story: list = []
    story.append(paragraph("战城大师 - 项目基础工程说明", styles["Title"]))
    story.append(paragraph(f"生成日期：{date.today().isoformat()} | 仓库：zhanchengdashi", styles["Meta"]))

    add_section(
        story,
        "一、当前完成内容",
        [
            "- 建立 Godot 4.6 项目入口：project.godot、最小主场景 scenes/main.tscn、ConfigDB 自动加载脚本。",
            "- 建立数据驱动配置流程：CSV 源表、Schema 校验、JSON 运行时导出。",
            "- 建立 Git/GitHub 基础：main 分支、SSH 远程、忽略规则、行尾规则、GitHub Actions 配置校验。",
            "- 建立项目文档：README、Git 工作流、配置表说明、项目基础说明与 PDF 审核版。",
        ],
        styles,
    )

    add_section(
        story,
        "二、推荐开发流程",
        [
            "- 设计师或程序先编辑 config/tables/*.csv。",
            "- 提交前运行 tools/validate_config.py，确保字段、类型、唯一 ID 和跨表引用正确。",
            "- 通过 tools/export_config.py 生成 runtime/config/*.json。",
            "- Godot 运行时通过 ConfigDB 读取导出的 JSON 表，再接入角色、技能、关卡、掉落和经济系统。",
        ],
        styles,
    )

    story.append(paragraph("三、配置表概览", styles["Heading2"]))
    table_data = [
        ["表", "文件", "用途"],
        ["Global", "config/tables/global.csv", "全局参数"],
        ["Units", "config/tables/units.csv", "玩家、敌人、召唤物、Boss"],
        ["Skills", "config/tables/skills.csv", "攻击、主动、被动和终极技能"],
        ["Items", "config/tables/items.csv", "装备、消耗品、升级项"],
        ["Stages", "config/tables/stages.csv", "章节、关卡、难度和地图引用"],
        ["Drop Pools", "config/tables/drop_pools.csv", "敌人池、奖励池和权重"],
        ["Economy", "config/tables/economy.csv", "金币、体力、经验等经济基础"],
        ["Localization ZH", "config/tables/localization_zh.csv", "中文与英文文本键"],
    ]
    table = Table(table_data, colWidths=[32 * mm, 58 * mm, 72 * mm], repeatRows=1)
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1d4ed8")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("FONTNAME", (0, 0), (-1, -1), font_name),
                ("FONTSIZE", (0, 0), (-1, 0), 9.5),
                ("FONTSIZE", (0, 1), (-1, -1), 8.8),
                ("LEADING", (0, 0), (-1, -1), 12),
                ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#cbd5e1")),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f8fafc")]),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("LEFTPADDING", (0, 0), (-1, -1), 5),
                ("RIGHTPADDING", (0, 0), (-1, -1), 5),
                ("TOPPADDING", (0, 0), (-1, -1), 4),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ]
        )
    )
    story.append(table)
    story.append(Spacer(1, 5 * mm))

    add_section(
        story,
        "四、下一步建议",
        [
            "- 确定目标平台、分辨率、输入方式和 Godot 渲染基线。",
            "- 在最小主场景上建立首个可玩闭环：移动、战斗、胜负、奖励。",
            "- 给 ConfigDB 增加单元测试或 Godot 启动检查，保证配置加载失败能快速暴露。",
            "- 当资源规模增大后，再评估是否启用 Git LFS 管理大型二进制资产。",
        ],
        styles,
    )

    def footer(canvas, document) -> None:
        canvas.saveState()
        canvas.setFont(font_name, 8)
        canvas.setFillColor(colors.HexColor("#64748b"))
        canvas.drawString(18 * mm, 10 * mm, "zhanchengdashi project foundation")
        canvas.drawRightString(A4[0] - 18 * mm, 10 * mm, f"Page {document.page}")
        canvas.restoreState()

    doc.build(story, onFirstPage=footer, onLaterPages=footer)


if __name__ == "__main__":
    build_pdf()
