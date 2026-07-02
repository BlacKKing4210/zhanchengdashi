from __future__ import annotations

import csv
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any

from reportlab.lib import colors
from reportlab.lib.pagesizes import A4, landscape
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.pdfbase import pdfmetrics
from reportlab.pdfbase.ttfonts import TTFont
from reportlab.platypus import PageBreak, Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle


ROOT = Path(__file__).resolve().parents[1]
CARDS_CSV = ROOT / "config" / "tables" / "cards.csv"
DOC_MD = ROOT / "docs" / "CARD_REDESIGN_DESIGN.md"
DOC_PDF = ROOT / "output" / "pdf" / "card-redesign-design.pdf"


BASE_BY_TIER: dict[int, dict[str, float]] = {
    1: {"attack": 8, "max_hp": 64, "move_speed": 64, "summon": 3.2},
    2: {"attack": 12, "max_hp": 86, "move_speed": 62, "summon": 3.6},
    3: {"attack": 17, "max_hp": 112, "move_speed": 61, "summon": 4.2},
    4: {"attack": 22, "max_hp": 145, "move_speed": 59, "summon": 4.8},
    5: {"attack": 29, "max_hp": 188, "move_speed": 57, "summon": 5.6},
    6: {"attack": 37, "max_hp": 245, "move_speed": 55, "summon": 6.6},
}

ROLE_MODS: dict[str, dict[str, float]] = {
    "swarm": {"attack": 0.72, "max_hp": 0.65, "move_speed": 1.14, "range": 40, "summon": -0.75},
    "scout": {"attack": 0.88, "max_hp": 0.82, "move_speed": 1.22, "range": 42, "summon": -0.35},
    "striker": {"attack": 1.24, "max_hp": 0.88, "move_speed": 1.08, "range": 46, "summon": 0.05},
    "guard": {"attack": 0.82, "max_hp": 1.42, "move_speed": 0.82, "range": 40, "summon": 0.35},
    "bruiser": {"attack": 1.12, "max_hp": 1.15, "move_speed": 0.96, "range": 44, "summon": 0.20},
    "ranged": {"attack": 1.02, "max_hp": 0.78, "move_speed": 0.92, "range": 130, "summon": 0.30},
    "support": {"attack": 0.74, "max_hp": 0.86, "move_speed": 0.96, "range": 92, "summon": 0.45},
    "controller": {"attack": 0.86, "max_hp": 0.92, "move_speed": 0.88, "range": 108, "summon": 0.55},
    "siege": {"attack": 1.30, "max_hp": 0.90, "move_speed": 0.78, "range": 155, "summon": 0.75},
}


RARITY_BY_TIER = {
    1: "common",
    2: "common",
    3: "rare",
    4: "rare",
    5: "epic",
    6: "legendary",
}


@dataclass(frozen=True)
class Skill:
    skill_id: str
    trigger: str
    effect: str
    power: float
    cooldown: float
    text: str
    tags: str


@dataclass(frozen=True)
class CardDef:
    card_id: str
    name: str
    tier: int
    art: str
    role: str
    notes: str
    skill: Skill | None = None


def skill(skill_id: str, trigger: str, effect: str, power: float, cooldown: float, text: str, tags: str) -> Skill:
    return Skill(skill_id, trigger, effect, power, cooldown, text, tags)


CARD_DEFS: list[CardDef] = [
    CardDef("mouse", "老鼠", 1, "mouse.png", "swarm", "低成本铺路，适合快速占小格。"),
    CardDef("ant", "蚂蚁", 1, "ant.png", "swarm", "成群推进型低费单位。", skill("ant_rally", "aura", "buff_attack", 1, 6.0, "附近友军攻击+1。", "aura|attack")),
    CardDef("sparrow", "麻雀", 1, "sparrow.png", "scout", "最快的基础侦察单位，用来抢中线。"),
    CardDef("frog", "青蛙", 1, "frog.png", "controller", "低价控制，伤害偏低。", skill("frog_mire", "on_attack", "slow", 25, 4.0, "攻击有概率让目标减速。", "slow|control")),
    CardDef("rabbit", "兔子", 1, "rabbit.png", "guard", "便宜前排，保护早期兵营。", skill("rabbit_guard", "on_spawn", "shield", 18, 0.0, "出生时获得护盾。", "shield|frontline")),
    CardDef("chicken", "鸡", 1, "chicken.png", "support", "低费辅助，单兵能力弱。", skill("chicken_cheer", "on_spawn", "buff_attack", 1, 0.0, "出生时使最近友军攻击+1。", "buff|support")),
    CardDef("pigeon", "鸽子", 1, "pigeon.png", "scout", "低血高速，失败损失小。", skill("pigeon_salvage", "on_death", "gold", 3, 0.0, "阵亡时返还少量金币。", "gold|economy")),
    CardDef("hamster", "仓鼠", 1, "hamster.png", "support", "经济倾向的基础卡。", skill("hamster_store", "on_interval", "gold", 2, 8.0, "存活时周期产出少量金币。", "gold|economy")),
    CardDef("snail", "蜗牛", 1, "snail.png", "guard", "无技能纯肉盾，属性效率最高。"),
    CardDef("tadpole", "蝌蚪", 1, "tadpole.png", "swarm", "超快召唤的炮灰单位。"),
    CardDef("cat", "猫", 2, "cat.png", "striker", "普通高攻近战，无技能换取稳定输出。"),
    CardDef("dog", "狗", 2, "dog.png", "guard", "守线前排。", skill("dog_protect", "aura", "shield", 10, 7.0, "周期给附近低血友军护盾。", "shield|protect")),
    CardDef("duck", "鸭", 2, "duck.png", "swarm", "阵亡补位，单体属性偏低。", skill("duck_brood", "on_death", "summon", 1, 0.0, "阵亡时召唤1个低级小兵。", "summon|swarm")),
    CardDef("squirrel", "松鼠", 2, "squirrel.png", "scout", "抢格与游走兼具。", skill("squirrel_cache", "on_capture", "gold", 8, 0.0, "参与占领地块时获得金币。", "gold|capture")),
    CardDef("hedgehog", "刺猬", 2, "hedgehog.png", "bruiser", "反打型近战。", skill("hedgehog_spines", "on_damage", "thorns", 20, 0.0, "受到近战伤害时反刺。", "thorns|retaliate")),
    CardDef("turtle", "乌龟", 2, "turtle.png", "guard", "慢速高耐久。", skill("turtle_shell", "on_damage", "shield", 26, 8.0, "低血时获得龟壳护盾。", "shield|tank")),
    CardDef("goat", "山羊", 2, "goat.png", "support", "团队生命辅助。", skill("goat_banner", "aura", "buff_hp", 18, 8.0, "附近友军最大生命提高。", "aura|hp")),
    CardDef("sheep", "羊", 2, "sheep.png", "support", "群体保护，输出较低。", skill("sheep_wool", "on_spawn", "shield", 14, 0.0, "出生时给附近友军护盾。", "shield|support")),
    CardDef("parrot", "鹦鹉", 2, "parrot.png", "support", "复制玩法核心，基础属性低。", skill("parrot_mimic", "on_spawn", "copy", 1, 12.0, "复制最近友军的小额技能效果。", "copy|support")),
    CardDef("fox", "狐狸", 2, "fox.png", "scout", "无技能快攻单位，属性集中在速度和攻击。"),
    CardDef("monkey", "猴子", 3, "monkey.png", "support", "中期复制核心。", skill("monkey_trick", "on_spawn", "copy", 1, 10.0, "复制一个同价或更低友方单位。", "copy|tempo")),
    CardDef("pig", "猪", 3, "pig.png", "guard", "经济型前排。", skill("piggy_bank", "on_death", "gold", 18, 0.0, "阵亡时返还金币。", "gold|tank")),
    CardDef("deer", "鹿", 3, "deer.png", "striker", "突进输出。", skill("deer_charge", "on_spawn", "buff_speed", 22, 6.0, "出生后短时间移速提高。", "speed|charge")),
    CardDef("beaver", "河狸", 3, "beaver.png", "bruiser", "工程单位。", skill("beaver_repair", "on_interval", "repair", 22, 7.0, "周期修复附近己方建筑。", "repair|building")),
    CardDef("otter", "水獭", 3, "otter.png", "support", "防守型辅助。", skill("otter_bubble", "on_spawn", "shield", 28, 0.0, "给最近友军套泡泡护盾。", "shield|support")),
    CardDef("penguin", "企鹅", 3, "penguin.png", "support", "稳态光环。", skill("penguin_drill", "aura", "buff_attack", 2, 8.0, "附近友军攻击小幅提高。", "aura|attack")),
    CardDef("peacock", "孔雀", 3, "peacock.png", "ranged", "中距离爆发。", skill("peacock_fan", "on_spawn", "buff_attack", 7, 0.0, "出生后首次攻击伤害提高。", "burst|ranged")),
    CardDef("kangaroo", "袋鼠", 3, "kangaroo.png", "striker", "跃进切后排。", skill("kangaroo_leap", "on_attack", "damage", 8, 5.0, "每隔一段时间跳击目标。", "leap|burst")),
    CardDef("seal", "海豹", 3, "seal.png", "guard", "无技能高生命稀有前排。"),
    CardDef("swan", "天鹅", 3, "swan.png", "support", "优雅护盾辅助。", skill("swan_grace", "aura", "shield", 18, 8.0, "周期给附近友军护盾。", "shield|aura")),
    CardDef("wolf", "狼", 4, "wolf.png", "bruiser", "中后期进攻核心。", skill("wolf_pack", "aura", "buff_attack", 3, 7.0, "附近友军攻击提高。", "aura|attack")),
    CardDef("horse", "马", 4, "horse.png", "scout", "快速支援与补线。", skill("horse_gallop", "aura", "buff_speed", 18, 7.0, "附近友军移速提高。", "speed|aura")),
    CardDef("cow", "牛", 4, "cow.png", "guard", "占点经济。", skill("cow_supply", "on_capture", "gold", 20, 0.0, "参与占领后提供金币。", "gold|capture")),
    CardDef("zebra", "斑马", 4, "zebra.png", "scout", "快速光环单位。", skill("zebra_stripes", "aura", "buff_attack", 3, 8.0, "附近不同定位友军攻击提高。", "aura|attack")),
    CardDef("camel", "骆驼", 4, "camel.png", "guard", "远征前排。", skill("camel_reserve", "on_damage", "heal", 24, 8.0, "低血时回复生命。", "heal|tank")),
    CardDef("dolphin", "海豚", 4, "dolphin.png", "ranged", "远程保护。", skill("dolphin_wave", "on_attack", "shield", 16, 6.0, "攻击时给最近友军护盾。", "shield|ranged")),
    CardDef("falcon", "猎鹰", 4, "falcon.png", "ranged", "长射程点杀。", skill("falcon_mark", "on_attack", "damage", 10, 5.0, "标记远处目标并造成额外伤害。", "mark|ranged")),
    CardDef("boar", "野猪", 4, "boar.png", "bruiser", "冲线破阵。", skill("boar_charge", "on_spawn", "stun", 0.8, 7.0, "首次接敌时短暂眩晕目标。", "charge|stun")),
    CardDef("crane", "鹤", 4, "crane.png", "support", "高阶保护辅助。", skill("crane_blessing", "on_interval", "heal", 20, 7.0, "周期治疗附近友军。", "heal|support")),
    CardDef("lynx", "猞猁", 4, "lynx.png", "striker", "无技能稀有刺客，面板更高。"),
    CardDef("bear", "熊", 5, "bear.png", "guard", "史诗重前排。", skill("bear_roar", "on_spawn", "stun", 1.0, 9.0, "出生时震慑附近敌人。", "stun|tank")),
    CardDef("tiger", "老虎", 5, "tiger.png", "striker", "史诗高爆发。", skill("tiger_pounce", "on_attack", "damage", 16, 5.5, "周期扑击造成额外伤害。", "burst|melee")),
    CardDef("lion", "狮子", 5, "lion.png", "bruiser", "阵亡返场压力。", skill("lion_legacy", "on_death", "summon", 1, 0.0, "阵亡时召唤1个低阶兽类。", "summon|death")),
    CardDef("rhino", "犀牛", 5, "rhino.png", "guard", "推进破盾。", skill("rhino_impact", "on_spawn", "stun", 1.2, 9.0, "首次冲撞眩晕目标。", "charge|stun")),
    CardDef("hippo", "河马", 5, "hippo.png", "guard", "无技能超高生命前排。"),
    CardDef("giraffe", "长颈鹿", 5, "giraffe.png", "ranged", "远程支援。", skill("giraffe_watch", "aura", "buff_hp", 28, 8.0, "提高附近友军生命。", "aura|hp")),
    CardDef("gorilla", "大猩猩", 5, "gorilla.png", "bruiser", "范围压制。", skill("gorilla_slam", "on_attack", "damage", 18, 6.0, "周期重击造成范围伤害。", "aoe|melee")),
    CardDef("leopard", "豹子", 5, "leopard.png", "scout", "无技能高速史诗输出。"),
    CardDef("eagle", "老鹰", 5, "eagle.png", "ranged", "远程斩杀。", skill("eagle_dive", "on_attack", "execute", 18, 7.0, "优先打击低血敌人。", "execute|ranged")),
    CardDef("crocodile", "鳄鱼", 5, "crocodile.png", "bruiser", "持续撕咬。", skill("crocodile_bite", "on_attack", "slow", 18, 5.5, "攻击附带减速。", "slow|melee")),
    CardDef("elephant", "大象", 6, "elephant.png", "guard", "传说团队前排。", skill("elephant_standard", "aura", "buff_hp", 45, 9.0, "大范围提高友军生命。", "legendary|aura|hp")),
    CardDef("blue_whale", "蓝鲸", 6, "blue_whale.png", "support", "传说护军核心。", skill("whale_tide", "on_interval", "shield", 46, 8.0, "周期为多名友军提供护盾。", "legendary|shield")),
    CardDef("orca", "虎鲸", 6, "orca.png", "striker", "传说猎杀者。", skill("orca_hunt", "on_attack", "execute", 24, 6.0, "对低血目标造成斩杀伤害。", "legendary|execute")),
    CardDef("shark", "鲨鱼", 6, "shark.png", "striker", "无技能传说输出，面板最高。"),
    CardDef("python", "巨蟒", 6, "python.png", "controller", "传说控制核心。", skill("python_constrict", "on_attack", "stun", 1.4, 7.0, "周期缠绕目标并短暂眩晕。", "legendary|control")),
    CardDef("komodo_dragon", "科莫多龙", 6, "komodo_dragon.png", "bruiser", "传说毒压。", skill("komodo_venom", "on_attack", "slow", 30, 5.5, "攻击施加剧毒减速。", "legendary|poison")),
    CardDef("polar_bear", "北极熊", 6, "polar_bear.png", "guard", "传说冰墙前排。", skill("polar_freeze", "on_damage", "shield", 52, 8.0, "低血时获得冰盾。", "legendary|shield")),
    CardDef("silverback", "银背猩猩", 6, "silverback.png", "bruiser", "传说返场压迫。", skill("silverback_legacy", "on_death", "summon", 1, 0.0, "阵亡时召唤1个大猩猩。", "legendary|summon")),
    CardDef("golden_eagle", "金雕", 6, "golden_eagle.png", "ranged", "传说远程点杀。", skill("golden_eagle_judgement", "on_attack", "damage", 28, 6.5, "周期打击最远目标。", "legendary|ranged")),
    CardDef("mammoth", "猛犸象", 6, "mammoth.png", "guard", "传说终局肉盾。", skill("mammoth_wall", "on_spawn", "shield", 70, 0.0, "出生时为附近友军提供厚护盾。", "legendary|shield|tank")),
]


def rarity_for_tier(tier: int) -> str:
    return RARITY_BY_TIER[tier]


def stat_row(card: CardDef) -> dict[str, Any]:
    base = BASE_BY_TIER[card.tier]
    mods = ROLE_MODS[card.role]
    skill_penalty = 0.90 if card.skill else 1.0
    hp_penalty = 0.92 if card.skill else 1.0
    summon_penalty = 0.25 if card.skill else 0.0
    attack = max(1, round(base["attack"] * mods["attack"] * skill_penalty))
    max_hp = max(1, round(base["max_hp"] * mods["max_hp"] * hp_penalty))
    move_speed = round(base["move_speed"] * mods["move_speed"], 1)
    attack_range = round(mods["range"], 1)
    summon_interval = round(max(1.8, base["summon"] + mods["summon"] + summon_penalty), 2)
    skill_data = card.skill
    tags = [f"tier_{card.tier}", rarity_for_tier(card.tier), card.role]
    if skill_data:
        tags.extend(skill_data.tags.split("|"))
        tags.append("skill")
    else:
        tags.append("no_skill")

    return {
        "id": card.card_id,
        "name": card.name,
        "rarity": rarity_for_tier(card.tier),
        "tier": card.tier,
        "art_path": f"res://assets/card_art/animals/{card.art}",
        "attack": attack,
        "max_hp": max_hp,
        "move_speed": move_speed,
        "attack_range": attack_range,
        "summon_interval_sec": summon_interval,
        "skill_id": skill_data.skill_id if skill_data else "",
        "skill_trigger": skill_data.trigger if skill_data else "",
        "skill_effect": skill_data.effect if skill_data else "",
        "skill_power": skill_data.power if skill_data else "",
        "skill_cooldown_sec": skill_data.cooldown if skill_data else "",
        "skill_text": skill_data.text if skill_data else "无技能：拥有更高基础属性。",
        "tags": "|".join(dict.fromkeys(tags)),
        "design_notes": card.notes,
    }


def write_cards(rows: list[dict[str, Any]]) -> None:
    CARDS_CSV.parent.mkdir(parents=True, exist_ok=True)
    fieldnames = [
        "id",
        "name",
        "rarity",
        "tier",
        "art_path",
        "attack",
        "max_hp",
        "move_speed",
        "attack_range",
        "summon_interval_sec",
        "skill_id",
        "skill_trigger",
        "skill_effect",
        "skill_power",
        "skill_cooldown_sec",
        "skill_text",
        "tags",
        "design_notes",
    ]
    with CARDS_CSV.open("w", encoding="utf-8", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def md_table(rows: list[dict[str, Any]]) -> str:
    lines = [
        "| 品质 | 卡牌 | 定位 | 攻击 | 生命 | 移速 | 射程 | 召唤间隔 | 技能 |",
        "| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | --- |",
    ]
    for row in rows:
        role = row["tags"].split("|")[2]
        skill_text = row["skill_text"]
        lines.append(
            f"| {row['rarity']} | {row['name']} | {role} | {row['attack']} | {row['max_hp']} | "
            f"{row['move_speed']} | {row['attack_range']} | {row['summon_interval_sec']} | {skill_text} |"
        )
    return "\n".join(lines)


def write_markdown(rows: list[dict[str, Any]]) -> None:
    DOC_MD.parent.mkdir(parents=True, exist_ok=True)
    today = date.today().isoformat()
    rarity_counts: dict[str, int] = {}
    skill_count = 0
    for row in rows:
        rarity_counts[row["rarity"]] = rarity_counts.get(row["rarity"], 0) + 1
        if row["skill_id"]:
            skill_count += 1

    content = f"""# 卡牌重设计方案

生成日期：{today}

## 1. 目标

- 完全保留当前 60 张动物卡的形象、名字、品质和收藏结构。
- 按占城玩法重做战斗属性：攻击、生命、移动速度、攻击距离、召唤间隔、技能。
- 所有属性进入 `config/tables/cards.csv`，运行时导出到 `runtime/config/cards.json`。
- 有技能效果的卡牌承担功能价值，因此基础攻击、生命和召唤效率会比同定位无技能卡更低。

## 2. 数据源

| 文件 | 用途 |
| --- | --- |
| `config/tables/cards.csv` | 卡牌主表，策划直接调数 |
| `runtime/config/cards.json` | Godot 运行时读取 |
| `scripts/app/main.gd` | 编组页展示，并在战斗建筑生成单位时读取卡牌属性 |

## 3. 品质与数量

| 品质 | 数量 |
| --- | ---: |
| common | {rarity_counts.get('common', 0)} |
| rare | {rarity_counts.get('rare', 0)} |
| epic | {rarity_counts.get('epic', 0)} |
| legendary | {rarity_counts.get('legendary', 0)} |

有技能卡牌：{skill_count} / {len(rows)}。

## 4. 数值口径

| 属性 | 说明 |
| --- | --- |
| 攻击 | 单次攻击造成的基础伤害 |
| 生命 | 单位最大生命 |
| 移动速度 | 战斗场景内每秒移动速度 |
| 攻击距离 | 近战约 40-50，辅助中程约 90，远程约 130+ |
| 召唤间隔 | 建筑每隔多少秒生成该单位 |
| 技能 | 当前先完成配置、UI 展示和实现协议；具体效果可逐个接入战斗逻辑 |

## 5. 设计原则

1. 低阶卡负责开局铺路、抢格和基础防守。
2. 中阶卡开始提供推进节奏、建筑修复、经济返还和局部光环。
3. 高阶卡提供决定战线的控制、斩杀、厚盾、团队光环和死亡返场。
4. 无技能卡拥有更直接的面板效率，适合作为稳定输出或稳定前排。
5. 有技能卡的攻击和生命会被折价，同时召唤间隔略增，避免技能卡同时拥有最高面板。

## 6. 全卡牌明细

{md_table(rows)}
"""
    DOC_MD.write_text(content, encoding="utf-8", newline="\n")


def paragraph(text: str, style: ParagraphStyle) -> Paragraph:
    return Paragraph(text.replace("|", "&#124;"), style)


def write_pdf(rows: list[dict[str, Any]]) -> None:
    DOC_PDF.parent.mkdir(parents=True, exist_ok=True)
    font_path = Path("C:/Windows/Fonts/simhei.ttf")
    font_name = "SimHei" if font_path.exists() else "Helvetica"
    if font_path.exists() and "SimHei" not in pdfmetrics.getRegisteredFontNames():
        pdfmetrics.registerFont(TTFont("SimHei", str(font_path)))

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle("TitleCN", parent=styles["Title"], fontName=font_name, fontSize=22, leading=28)
    h_style = ParagraphStyle("HeadingCN", parent=styles["Heading2"], fontName=font_name, fontSize=14, leading=18, spaceBefore=8, spaceAfter=6)
    body_style = ParagraphStyle("BodyCN", parent=styles["BodyText"], fontName=font_name, fontSize=9.5, leading=14)
    small_style = ParagraphStyle("SmallCN", parent=styles["BodyText"], fontName=font_name, fontSize=7.2, leading=9)

    doc = SimpleDocTemplate(
        str(DOC_PDF),
        pagesize=landscape(A4),
        rightMargin=10 * mm,
        leftMargin=10 * mm,
        topMargin=10 * mm,
        bottomMargin=10 * mm,
    )
    story: list[Any] = [
        Paragraph("卡牌重设计方案", title_style),
        Paragraph(f"生成日期：{date.today().isoformat()}", body_style),
        Spacer(1, 5 * mm),
        Paragraph("设计目标", h_style),
        Paragraph("保留当前 60 张动物卡的形象、名字和品质；按占城玩法重做攻击、生命、移动速度、攻击距离、召唤间隔和技能；所有属性进入 cards.csv 并导出为 runtime/config/cards.json。", body_style),
        Paragraph("技能折价原则", h_style),
        Paragraph("无技能卡提供更高面板效率；有技能卡以功能价值换取较低攻击、生命和更长召唤间隔。当前版本完成配置、UI 展示和战斗属性接入，技能效果字段作为后续逐个实现的协议。", body_style),
        Spacer(1, 4 * mm),
    ]

    summary_data = [
        ["品质", "common", "rare", "epic", "legendary", "总数"],
        [
            "数量",
            sum(1 for row in rows if row["rarity"] == "common"),
            sum(1 for row in rows if row["rarity"] == "rare"),
            sum(1 for row in rows if row["rarity"] == "epic"),
            sum(1 for row in rows if row["rarity"] == "legendary"),
            len(rows),
        ],
    ]
    summary_table = Table(summary_data, colWidths=[28 * mm, 26 * mm, 26 * mm, 26 * mm, 30 * mm, 24 * mm])
    summary_table.setStyle(TableStyle([
        ("FONTNAME", (0, 0), (-1, -1), font_name),
        ("FONTSIZE", (0, 0), (-1, -1), 9),
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#324A7A")),
        ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
        ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#B8C3D9")),
        ("ALIGN", (1, 1), (-1, -1), "CENTER"),
    ]))
    story.append(summary_table)
    story.append(PageBreak())

    header = ["品质", "卡牌", "定位", "攻", "生", "速", "距", "召唤", "技能"]
    table_rows: list[list[Any]] = [header]
    for row in rows:
        role = row["tags"].split("|")[2]
        table_rows.append([
            row["rarity"],
            row["name"],
            role,
            row["attack"],
            row["max_hp"],
            row["move_speed"],
            row["attack_range"],
            row["summon_interval_sec"],
            paragraph(row["skill_text"], small_style),
        ])

    chunk_size = 24
    for start in range(1, len(table_rows), chunk_size):
        chunk = [header] + table_rows[start:start + chunk_size]
        story.append(Paragraph("全卡牌明细", h_style))
        table = Table(chunk, repeatRows=1, colWidths=[22 * mm, 25 * mm, 24 * mm, 14 * mm, 16 * mm, 16 * mm, 16 * mm, 18 * mm, 102 * mm])
        table.setStyle(TableStyle([
            ("FONTNAME", (0, 0), (-1, -1), font_name),
            ("FONTSIZE", (0, 0), (-1, -1), 7.2),
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#324A7A")),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("BACKGROUND", (0, 1), (-1, -1), colors.HexColor("#F7FAFF")),
            ("ROWBACKGROUNDS", (0, 1), (-1, -1), [colors.HexColor("#FFFFFF"), colors.HexColor("#EFF5FF")]),
            ("GRID", (0, 0), (-1, -1), 0.25, colors.HexColor("#B8C3D9")),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("ALIGN", (3, 1), (7, -1), "RIGHT"),
            ("LEFTPADDING", (0, 0), (-1, -1), 3),
            ("RIGHTPADDING", (0, 0), (-1, -1), 3),
            ("TOPPADDING", (0, 0), (-1, -1), 3),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
        ]))
        story.append(table)
        if start + chunk_size < len(table_rows):
            story.append(PageBreak())

    doc.build(story)


def main() -> int:
    rows = [stat_row(card) for card in CARD_DEFS]
    write_cards(rows)
    write_markdown(rows)
    write_pdf(rows)
    print(f"Wrote {CARDS_CSV.relative_to(ROOT)}")
    print(f"Wrote {DOC_MD.relative_to(ROOT)}")
    print(f"Wrote {DOC_PDF.relative_to(ROOT)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
