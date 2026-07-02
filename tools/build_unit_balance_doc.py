from __future__ import annotations

import csv
from collections import defaultdict
from datetime import date
from pathlib import Path
from statistics import mean
from typing import Any

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    LongTable,
    PageBreak,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.cidfonts import UnicodeCIDFont
from reportlab.pdfbase.ttfonts import TTFont


ROOT = Path(__file__).resolve().parents[1]
DOCS_DIR = ROOT / "docs"
PDF_DIR = ROOT / "output" / "pdf"
MD_PATH = DOCS_DIR / "UNIT_BALANCE_DESIGN.md"
PDF_PATH = PDF_DIR / "unit-balance-design.pdf"


def read_csv(path: str) -> list[dict[str, str]]:
    with (ROOT / path).open("r", encoding="utf-8-sig", newline="") as handle:
        return [
            {key: (value or "").strip() for key, value in row.items()}
            for row in csv.DictReader(handle)
        ]


def load_data() -> dict[str, Any]:
    localization_rows = read_csv("config/tables/localization_zh_runtime.csv")
    localization = {row["key"]: row["zh_cn"] for row in localization_rows}
    skills = {row["id"]: row for row in read_csv("config/tables/skills.csv")}
    units = read_csv("config/tables/units.csv")
    defenses = read_csv("config/tables/defenses.csv")
    card_pools = read_csv("config/tables/card_random_pools.csv")
    price_pools = read_csv("config/tables/cell_price_pools.csv")
    board_cells = read_csv("config/tables/board_cell_types.csv")
    board_rules = read_csv("config/tables/board_rules.csv")
    reveal_rules = read_csv("config/tables/cell_reveal_rules.csv")
    economy = read_csv("config/tables/economy.csv")
    return {
        "localization": localization,
        "skills": skills,
        "units": units,
        "defenses": defenses,
        "card_pools": card_pools,
        "price_pools": price_pools,
        "board_cells": board_cells,
        "board_rules": board_rules,
        "reveal_rules": reveal_rules,
        "economy": economy,
    }


def name_for(localization: dict[str, str], row: dict[str, str]) -> str:
    return localization.get(row.get("name_key", ""), row.get("id", ""))


def skill_summary(localization: dict[str, str], skills: dict[str, dict[str, str]], skill_id: str) -> str:
    skill = skills.get(skill_id, {})
    desc = localization.get(skill.get("description_key", ""), skill_id)
    tags = skill.get("effect_tags", "")
    cooldown = skill.get("cooldown_sec", "")
    if tags:
        return f"{desc} [{tags}; CD {cooldown}s]"
    return f"{desc} [CD {cooldown}s]"


def dps(row: dict[str, str]) -> float:
    damage = float(row.get("base_damage") or 0)
    cooldown = float(row.get("attack_cooldown_sec") or 1)
    if cooldown <= 0:
        return 0.0
    return damage / cooldown


def md_escape(value: Any) -> str:
    text = str(value)
    return text.replace("|", "\\|").replace("\n", " ")


def md_table(headers: list[str], rows: list[list[Any]]) -> str:
    output = ["| " + " | ".join(headers) + " |"]
    output.append("| " + " | ".join(["---"] * len(headers)) + " |")
    for row in rows:
        output.append("| " + " | ".join(md_escape(cell) for cell in row) + " |")
    return "\n".join(output)


def rarity_stats(units: list[dict[str, str]]) -> list[list[Any]]:
    rows: list[list[Any]] = []
    order = ["common", "rare", "epic", "legendary"]
    for rarity in order:
        group = [row for row in units if row["rarity"] == rarity]
        if not group:
            continue
        rows.append(
            [
                rarity,
                len(group),
                round(mean(int(row["max_hp"]) for row in group), 1),
                round(mean(float(row["move_speed"]) for row in group), 2),
                round(mean(float(row["attack_range"]) for row in group), 2),
                round(mean(int(row["base_damage"]) for row in group), 1),
                round(mean(dps(row) for row in group), 2),
            ]
        )
    return rows


def pool_rarity_rows(card_pools: list[dict[str, str]]) -> list[list[Any]]:
    grouped: dict[str, dict[str, float]] = defaultdict(lambda: defaultdict(float))
    counts: dict[str, int] = defaultdict(int)
    for row in card_pools:
        grouped[row["pool_id"]][row["rarity"]] += float(row["probability_pct"])
        counts[row["pool_id"]] += 1

    rows: list[list[Any]] = []
    for pool_id in sorted(grouped):
        rarity = grouped[pool_id]
        rows.append(
            [
                pool_id,
                counts[pool_id],
                rarity.get("common", 0),
                rarity.get("rare", 0),
                rarity.get("epic", 0),
                rarity.get("legendary", 0),
            ]
        )
    return rows


def unit_rows(data: dict[str, Any]) -> list[list[Any]]:
    localization = data["localization"]
    skills = data["skills"]
    rows = []
    for row in data["units"]:
        if row["role"] != "summon":
            continue
        rows.append(
            [
                name_for(localization, row),
                row["species"],
                row["rarity"],
                row["shop_cost"],
                row["max_hp"],
                row["move_speed"],
                row["attack_range"],
                f'{row["base_damage"]}/{row["attack_cooldown_sec"]} ({dps(row):.1f})',
                row["tags"],
                skill_summary(localization, skills, row["skill_id"]),
            ]
        )
    rarity_order = {"common": 0, "rare": 1, "epic": 2, "legendary": 3}
    return sorted(rows, key=lambda item: (item[1], rarity_order.get(str(item[2]), 9), item[0]))


def defense_rows(data: dict[str, Any]) -> list[list[Any]]:
    localization = data["localization"]
    skills = data["skills"]
    rows = []
    for row in data["defenses"]:
        rows.append(
            [
                name_for(localization, row),
                row["rarity"],
                row["max_hp"],
                row["attack_range"],
                f'{row["base_damage"]}/{row["attack_cooldown_sec"]} ({dps(row):.1f})',
                row["tags"],
                skill_summary(localization, skills, row["skill_id"]),
            ]
        )
    return rows


def card_pool_detail_rows(data: dict[str, Any]) -> list[list[Any]]:
    localization = data["localization"]
    unit_lookup = {row["id"]: row for row in data["units"]}
    defense_lookup = {row["id"]: row for row in data["defenses"]}
    rows = []
    for row in data["card_pools"]:
        lookup = unit_lookup if row["entry_type"] == "unit" else defense_lookup
        card = lookup.get(row["entry_id"], {})
        name = name_for(localization, card) if card else row["entry_id"]
        rows.append(
            [
                row["pool_id"],
                name,
                row["entry_type"],
                row["rarity"],
                row["weight"],
                row["probability_pct"],
            ]
        )
    return rows


def write_markdown(data: dict[str, Any]) -> None:
    summon_units = [row for row in data["units"] if row["role"] == "summon"]
    pooled_units = {
        row["entry_id"]
        for row in data["card_pools"]
        if row["entry_type"] == "unit"
    }
    missing_units = sorted({row["id"] for row in summon_units} - pooled_units)

    board_rows = [
        [
            row["id"],
            row["cell_type"],
            row["price_mode"],
            row["fixed_price"] or row["price_pool_id"],
            row["income_amount"],
            row["income_interval_sec"],
            row["appearance_probability_pct"],
            row["notes"],
        ]
        for row in data["board_cells"]
    ]

    price_rows = [
        [
            row["price"],
            row["probability_pct"],
            row["quality_tier"],
            row["unit_card_pool_id"],
            row["defense_card_pool_id"],
        ]
        for row in data["price_pools"]
    ]

    reveal_rows = [
        [row["pool_id"], row["entry_id"], row["entry_type"], row["probability_pct"], row["min_count"], row["max_count"]]
        for row in data["reveal_rules"]
    ]

    lines = [
        "# 单位属性与卡池平衡设计文档",
        "",
        f"生成日期：{date.today().isoformat()}",
        "",
        "## 设计目标",
        "",
        "- 让每个移植来的单位族群都能在卡池中实际出现，而不是只停留在单位表。",
        "- 地块价格在开局完成随机，单位/防御价格越高，越倾向抽到高品质卡牌。",
        "- 上下半图以地图中心水平镜像，保证双方信息结构和资源机会一致。",
        "- 普通卡负责铺场和识别基础玩法，稀有卡提供战术主题，史诗/传说卡制造阵容核心和翻盘点。",
        "",
        "## 当前规则快照",
        "",
        md_table(
            ["地块ID", "类型", "价格模式", "价格/价格池", "产出", "产出间隔", "出现概率%", "说明"],
            board_rows,
        ),
        "",
        "## 问号与地块翻开规则",
        "",
        md_table(
            ["池ID", "结果", "类型", "概率%", "最小数量", "最大数量"],
            reveal_rows,
        ),
        "",
        "## 单位/防御价格池",
        "",
        md_table(
            ["价格", "概率%", "品质档", "单位卡池", "防御卡池"],
            price_rows,
        ),
        "",
        "## 品质数值概览",
        "",
        md_table(
            ["品质", "数量", "平均HP", "平均速度", "平均射程", "平均伤害", "平均DPS"],
            rarity_stats(summon_units),
        ),
        "",
        "## 召唤单位全表",
        "",
        md_table(
            ["名称", "族群/外形", "品质", "内部费用", "HP", "速度", "射程", "伤害/CD(DPS)", "标签", "技能效果"],
            unit_rows(data),
        ),
        "",
        "## 防御塔全表",
        "",
        md_table(
            ["名称", "品质", "HP", "射程", "伤害/CD(DPS)", "标签", "技能效果"],
            defense_rows(data),
        ),
        "",
        "## 卡池品质分布",
        "",
        md_table(
            ["卡池", "条目数", "普通%", "稀有%", "史诗%", "传说%"],
            pool_rarity_rows(data["card_pools"]),
        ),
        "",
        "## 卡池明细",
        "",
        md_table(
            ["卡池", "卡牌", "类型", "品质", "权重", "概率%"],
            card_pool_detail_rows(data),
        ),
        "",
        "## 平衡设计说明",
        "",
        "- 50金币单位池：用于早期铺场，普通单位权重最高，同时保留少量稀有和极低概率史诗，让低价地块有惊喜但不稳定。",
        "- 100金币单位池：中期主力池，稀有单位覆盖最多，史诗稳定出现，传说保持低概率，避免中价位过早决定胜负。",
        "- 250金币单位池：高投入高回报，史诗和传说成为主要权重，适合作为玩家围绕经济优势做出的明确赌点。",
        "- 防御池：同价位逻辑与单位一致，但条目更少；这会让防御地块更可读，也方便后续按塔型扩展。",
        "- 族群差异：野兽偏速度和群体攻速，邪裔偏高风险爆发，龙裔偏远程范围，元素偏弹射/护盾，机械偏炮击/修复，沼泽偏毒和回复，海蛇偏远程控制，海盗偏高攻和炮击，豪猪偏冲锋反击，亡灵偏群涌和返场。",
        "- 外形资产：当前配置已经让所有移植单位进入卡池；实际美术资源仍需要按族群补齐 sprite/序列帧或程序化变体。",
        "",
        "## 调参检查清单",
        "",
        "- 改 `card_random_pools.csv` 后，同一个 `pool_id` 的 `probability_pct` 应合计100。",
        "- 低价池不要放太多传说，否则25问号和50单位地块会过早破坏节奏。",
        "- 高价池可以提高传说权重，但要同步观察金矿和大本营每3秒产出的经济节奏。",
        "- 新增单位时，先补 `units.csv` 和 `skills.csv`，再加入至少一个 `card_random_pools.csv` 池。",
        "- 新增防御塔时，先补 `defenses.csv`，再加入对应防御池。",
        "",
        "## 覆盖状态",
        "",
        f"- 召唤单位总数：{len(summon_units)}",
        f"- 已进入单位卡池：{len(pooled_units)}",
        f"- 未进入卡池：{', '.join(missing_units) if missing_units else '无'}",
        "",
    ]

    DOCS_DIR.mkdir(parents=True, exist_ok=True)
    MD_PATH.write_text("\n".join(lines), encoding="utf-8", newline="\n")


def register_font() -> str:
    font_path = Path("C:/Windows/Fonts/msyh.ttc")
    if font_path.exists():
        try:
            pdfmetrics.registerFont(TTFont("MicrosoftYaHei", str(font_path)))
            return "MicrosoftYaHei"
        except Exception:
            pass
    pdfmetrics.registerFont(UnicodeCIDFont("STSong-Light"))
    return "STSong-Light"


def para(text: Any, style: ParagraphStyle) -> Paragraph:
    return Paragraph(str(text).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;"), style)


def pdf_table(headers: list[str], rows: list[list[Any]], style: ParagraphStyle, widths: list[float]) -> LongTable:
    data = [[para(header, style) for header in headers]]
    for row in rows:
        data.append([para(cell, style) for cell in row])
    table = LongTable(data, colWidths=widths, repeatRows=1)
    table.setStyle(
        TableStyle(
            [
                ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#1f4e79")),
                ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
                ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#c9d3df")),
                ("VALIGN", (0, 0), (-1, -1), "TOP"),
                ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.white, colors.HexColor("#f5f8fb")]),
                ("LEFTPADDING", (0, 0), (-1, -1), 4),
                ("RIGHTPADDING", (0, 0), (-1, -1), 4),
                ("TOPPADDING", (0, 0), (-1, -1), 3),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
            ]
        )
    )
    return table


def write_pdf(data: dict[str, Any]) -> None:
    PDF_DIR.mkdir(parents=True, exist_ok=True)
    font = register_font()
    styles = getSampleStyleSheet()
    title = ParagraphStyle("TitleZH", parent=styles["Title"], fontName=font, fontSize=20, leading=25)
    h1 = ParagraphStyle("H1ZH", parent=styles["Heading1"], fontName=font, fontSize=14, leading=18, spaceBefore=10)
    body = ParagraphStyle("BodyZH", parent=styles["BodyText"], fontName=font, fontSize=8.5, leading=11)
    small = ParagraphStyle("SmallZH", parent=styles["BodyText"], fontName=font, fontSize=6.4, leading=8)

    def page_number(canvas, doc) -> None:
        canvas.saveState()
        canvas.setFont(font, 8)
        canvas.setFillColor(colors.HexColor("#5b6770"))
        canvas.drawRightString(285 * mm, 10 * mm, f"单位平衡设计 - {doc.page}")
        canvas.restoreState()

    doc = SimpleDocTemplate(
        str(PDF_PATH),
        pagesize=landscape(A4),
        leftMargin=12 * mm,
        rightMargin=12 * mm,
        topMargin=12 * mm,
        bottomMargin=16 * mm,
    )
    story: list[Any] = [
        Paragraph("单位属性与卡池平衡设计文档", title),
        Paragraph(f"生成日期：{date.today().isoformat()}", body),
        Spacer(1, 5 * mm),
        Paragraph("设计目标", h1),
        Paragraph(
            "所有移植单位都进入卡池；开局完成地块类型和价格随机；单位/防御价格越高，高品质卡权重越高；上下地图以中心水平镜像，保证双方机会一致。",
            body,
        ),
        Paragraph("当前规则快照", h1),
        pdf_table(
            ["地块", "类型", "价格模式", "价格/池", "产出", "间隔", "出现%"],
            [
                [row["id"], row["cell_type"], row["price_mode"], row["fixed_price"] or row["price_pool_id"], row["income_amount"], row["income_interval_sec"], row["appearance_probability_pct"]]
                for row in data["board_cells"]
            ],
            small,
            [42 * mm, 26 * mm, 24 * mm, 40 * mm, 18 * mm, 18 * mm, 18 * mm],
        ),
        Spacer(1, 3 * mm),
        Paragraph("价格池与品质分布", h1),
        pdf_table(
            ["价格", "概率%", "品质档", "单位卡池", "防御卡池"],
            [[row["price"], row["probability_pct"], row["quality_tier"], row["unit_card_pool_id"], row["defense_card_pool_id"]] for row in data["price_pools"]],
            small,
            [20 * mm, 20 * mm, 24 * mm, 55 * mm, 55 * mm],
        ),
        Spacer(1, 3 * mm),
        pdf_table(
            ["卡池", "条目", "普通%", "稀有%", "史诗%", "传说%"],
            pool_rarity_rows(data["card_pools"]),
            small,
            [55 * mm, 18 * mm, 20 * mm, 20 * mm, 20 * mm, 20 * mm],
        ),
        PageBreak(),
        Paragraph("召唤单位全表", h1),
        pdf_table(
            ["名称", "族群", "品质", "费", "HP", "速", "射程", "伤害/CD(DPS)", "标签", "技能效果"],
            unit_rows(data),
            small,
            [23 * mm, 20 * mm, 17 * mm, 10 * mm, 14 * mm, 12 * mm, 12 * mm, 23 * mm, 35 * mm, 96 * mm],
        ),
        PageBreak(),
        Paragraph("防御塔全表", h1),
        pdf_table(
            ["名称", "品质", "HP", "射程", "伤害/CD(DPS)", "标签", "技能效果"],
            defense_rows(data),
            small,
            [30 * mm, 18 * mm, 18 * mm, 18 * mm, 30 * mm, 50 * mm, 100 * mm],
        ),
        Spacer(1, 4 * mm),
        Paragraph("卡池明细", h1),
        pdf_table(
            ["卡池", "卡牌", "类型", "品质", "权重", "概率%"],
            card_pool_detail_rows(data),
            small,
            [58 * mm, 38 * mm, 18 * mm, 18 * mm, 16 * mm, 18 * mm],
        ),
        PageBreak(),
        Paragraph("平衡设计说明", h1),
        Paragraph(
            "50金币池强调铺场，普通卡占主要权重；100金币池承接中期阵容成形，稀有和史诗明显提高；250金币池作为高投入赌点，史诗和传说成为主体。防御池条目较少，目的是保持防御地块结果清晰，并方便后续按塔型扩展。",
            body,
        ),
        Spacer(1, 3 * mm),
        Paragraph(
            "族群定位：野兽偏速度和群体攻速，邪裔偏高风险爆发，龙裔偏远程范围，元素偏弹射/护盾，机械偏炮击/修复，沼泽偏毒和回复，海蛇偏远程控制，海盗偏高攻和炮击，豪猪偏冲锋反击，亡灵偏群涌和返场。",
            body,
        ),
        Spacer(1, 3 * mm),
        Paragraph(
            "外形资产状态：配置已经让所有移植单位进入卡池，但实际 sprite 资源仍需要按族群补齐。当前可以先通过颜色、缩放、武器/特效和程序化动作区分，后续再补专属序列帧。",
            body,
        ),
    ]
    doc.build(story, onFirstPage=page_number, onLaterPages=page_number)


def main() -> int:
    data = load_data()
    write_markdown(data)
    write_pdf(data)
    print(f"Wrote {MD_PATH.relative_to(ROOT)}")
    print(f"Wrote {PDF_PATH.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
