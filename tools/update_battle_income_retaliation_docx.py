from __future__ import annotations

from pathlib import Path

from docx import Document


ROOT = Path(__file__).resolve().parents[1]
DOCX_PATH = ROOT / "docs" / "CURRENT_GAME_DESIGN.docx"
CHANGE_HEADING = "16. 2026-08-25 金币反馈、受击反击与中心金矿修订"


def replace_paragraph_start(document: Document, prefix: str, replacement: str) -> None:
    for paragraph in document.paragraphs:
        if paragraph.text.startswith(prefix):
            paragraph.text = replacement
            return
    raise RuntimeError(f"missing paragraph prefix: {prefix}")


def replace_table_row(document: Document, first_cell: str, values: list[str]) -> None:
    for table in document.tables:
        for row in table.rows:
            if row.cells and row.cells[0].text == first_cell:
                if len(row.cells) != len(values):
                    raise RuntimeError(
                        f"column mismatch for {first_cell}: {len(row.cells)} != {len(values)}"
                    )
                for cell, value in zip(row.cells, values, strict=True):
                    cell.text = value
                return
    raise RuntimeError(f"missing table row: {first_cell}")


def insert_income_feedback_rule(document: Document) -> None:
    marker = "基地与金矿共用当前 3 秒收入计时。"
    if any(paragraph.text.startswith(marker) for paragraph in document.paragraphs):
        return
    for paragraph in document.paragraphs:
        if paragraph.text.startswith("后续如果要统一规则"):
            inserted = paragraph.insert_paragraph_before(
                "基地与金矿共用当前 3 秒收入计时。每座有效基地和金矿都在建筑下方显示由空到满的紧凑生产进度条；周期完成时按建筑逐座结算，并在对应建筑上方播放金币图标与 +12 或 +10 上浮淡出动效。该显示只拆分反馈来源，不改变总收入、计时周期或淘汰队伍不再结算的规则。"
            )
            inserted.style = "Normal"
            return
    raise RuntimeError("missing income insertion anchor")


def append_change_record(document: Document) -> None:
    if any(paragraph.text == CHANGE_HEADING for paragraph in document.paragraphs):
        return
    document.add_heading(CHANGE_HEADING, level=1)
    document.add_heading("16.1 基地与金矿生产反馈", level=2)
    for text in (
        "基地和金矿继续共用 3 秒收入周期，每座建筑显示同类紧凑生产进度条。",
        "每次周期完成后逐建筑结算：基地 +12、金矿 +10；每座建筑上方分别播放金币图标与对应 +数值上浮淡出动效，总收入不变。",
        "进度和动效属于世界内反馈，不改变建筑生命、攻击、收入配置、多人队伍独立金币或淘汰判定。",
    ):
        document.add_paragraph(text, style="List Bullet")
    document.add_heading("16.2 移动受击反击", level=2)
    for text in (
        "动物没有有效攻击目标且受到敌方单位、基地或防御塔的实际伤害时，锁定实际伤害来源并向其移动，直到进入射程完成第一次反击。",
        "受击时已有仍存活、仍敌对且仍有效的攻击目标，则保持原目标，不被后来的攻击者抢走。",
        "第一次反击后取消临时追击例外；后续按普通锁敌规则，在目标死亡、关系失效或离开射程时释放并重新选择。",
    ):
        document.add_paragraph(text, style="List Bullet")
    document.add_heading("16.3 额外金矿中心圈", level=2)
    for text in (
        "每名玩家仍固定拥有 1 个基地相邻起始金矿和 1 个非相邻额外金矿，不增减经济配额。",
        "额外金矿优先选择本方全部合法候选中六边格中心距离最小的圈，同圈再由布局种子稳定打散。",
        "1V1/2V2 保持镜像，3V3 与自由混战保持六重旋转；额外金矿不能落在基地相邻圈，因此开局不能直接解锁两座金矿。",
    ):
        document.add_paragraph(text, style="List Bullet")


def main() -> None:
    document = Document(DOCX_PATH)
    replace_paragraph_start(
        document,
        "动物出生或当前推进建筑死亡",
        "动物出生或当前推进建筑死亡、消失、转为盟友时，选择最近的敌方建筑并锁定为推进目标；寻路过程中不因出现新的动物或更近建筑而改道。动物只攻击自身攻击范围内的敌对动物或建筑。动物没有有效攻击目标且受到敌方单位或攻击建筑的实际伤害时，锁定伤害来源并追击至第一次反击；已有有效攻击目标时保持原目标。玩家拖动地图和查看地块不能改变上述目标。",
    )
    replace_paragraph_start(
        document,
        "动物营地/大厅的召唤进度条",
        "动物营地/大厅的召唤进度条使用更短、更细的小条；基地与金矿用同类小条显示统一 3 秒金币生产进度。建筑生命条同样收窄。战斗中的单位血条、建筑生命条和生产进度条只保留一条底槽加填充，不额外绘制下方黑色阴影条。",
    )
    insert_income_feedback_rule(document)
    replace_paragraph_start(
        document,
        "动物触发金币效果时",
        "动物触发金币效果时，在该动物头顶显示金币图标与 +数量，短暂上浮并淡出；同一动物在极短时间内连续触发时合并数字，避免大量单位同时产金造成信息噪音。基地与金矿周期完成时也在各自建筑上方显示同类动效，但按单座建筑分别显示对应基础收入。",
    )
    replace_paragraph_start(
        document,
        "每次更新只扫描攻击范围内",
        "没有有效攻击锁定时，才扫描攻击范围内的敌对动物和建筑并保存稳定锁定；普通范围外候选不能改变推进路径。",
    )
    replace_paragraph_start(
        document,
        "如果范围内存在攻击目标",
        "当前攻击目标仍存活、仍敌对且仍在射程内时持续攻击同一目标；目标死亡、关系失效或离开射程时才释放。没有攻击目标且受击时，临时锁定实际伤害来源并追击至第一次反击；受击前已有有效目标则不变。",
    )
    replace_paragraph_start(
        document,
        "不追逐攻击范围外的动物",
        "除受击后的首次反击例外外，不追逐攻击范围外的动物，也不因途中出现更近建筑而重新寻路；首次反击后立即恢复普通射程锁定。",
    )
    replace_paragraph_start(
        document,
        "每个基地保底 1 个相邻金矿",
        "每个基地有且仅有 1 个相邻起始金矿和 1 个 50 金币营地；每名玩家另有 1 个不与基地相邻的额外金矿。额外金矿位于全部合法候选中最靠近地图中心的六边格距离圈，同圈由布局种子稳定打散，并保持镜像或六重旋转对称。每名玩家的初始领地连通，整张地图也必须连通。",
    )
    replace_table_row(
        document,
        "初始可解锁金矿",
        [
            "金矿定额",
            "每个势力有且仅有 1 块基地相邻起始金矿和 1 块非相邻额外金矿；额外金矿优先放入最靠近地图中心的合法圈，同圈种子打散并保持地图对称，整图固定 2 块",
        ],
    )
    replace_table_row(
        document,
        "cell_gold_mine",
        [
            "cell_gold_mine",
            "gold_mine",
            "fixed",
            "50",
            "10 金币 / 3 秒",
            "0%",
            "不参与普通地块随机池；固定 1 块基地相邻矿和 1 块最靠近地图中心合法圈的非相邻矿；显示生产进度与结算动效",
        ],
    )
    replace_table_row(
        document,
        "cell_home_base",
        [
            "cell_home_base",
            "home_base",
            "free",
            "0",
            "12 金币 / 3 秒",
            "0%",
            "固定基地，不参与随机；显示生产进度与结算动效",
        ],
    )
    append_change_record(document)
    document.save(DOCX_PATH)
    print(f"updated {DOCX_PATH}")


if __name__ == "__main__":
    main()
