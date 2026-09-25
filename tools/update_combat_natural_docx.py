"""Apply the approved narrow combat amendment without rebuilding the document."""
from copy import deepcopy
from pathlib import Path
from zipfile import ZipFile

from lxml import etree


ROOT = Path(__file__).resolve().parents[1]
DOCX = ROOT / "docs" / "CURRENT_GAME_DESIGN.docx"
NS = {"w": "http://schemas.openxmlformats.org/wordprocessingml/2006/main"}
W = "{" + NS["w"] + "}"
HEADING = "17. 2026-09-25 弹体表现与建筑状态修订"
RULES = [
    "本轮按制作人要求取消子弹拖尾、改为自然弹体，修正空血防御塔状态，并为刺猬技能增加对建筑无效限制。以下规则覆盖同类旧描述；其余战斗属性、范围、攻击时序与既有布局不变，运行时完成状态以本轮验收证据为准。",
    "取消路径拖尾和夸张的十字命中闪光。弹体使用小体积、低饱和且有实物轮廓的种子、水滴、羽毛、小石块、弩箭、铁弹与坚果七类造型；飞行中保持实体轮廓，终点仅保留弹体自身 0.08 秒收缩淡出。发射、飞行与终点均须可见，不改变伤害时机或弹速。",
    "动物弹体：麻雀用种子；青蛙、鸭子、天鹅用水滴；鹦鹉、鹤及猛禽用羽毛；狐狸及其他未单独定义的来源用小石块。防御塔弹体：兔子哨塔和麻雀速弩塔用轻弩箭，猎鹰瞭望塔和金雕领空塔用长弩箭，野猪重弩塔和老虎赏金塔用铁弹，松鼠掠金塔用坚果，龟甲壁垒塔用较重石块，鹦鹉双弩塔用双羽弹；基地用小石块。猛犸震地塔保留全体脉冲。仅替换表现，不改变攻击或额外目标机制。",
    "建筑在同帧伤害或反应结算中被摧毁后，后续攻击、冷却或周期更新不得用旧地块副本恢复它。真正归零的建筑必须进入既有摧毁和占领流程；不能只隐藏血条。受伤且生命大于 0 的建筑即使剩余比例极低，生命填充仍至少保留 3 个逻辑像素；满血隐藏、阵营编号与其他进度条规则不变。",
    "刺猬技能正式描述：受到伤害时，对伤害来源造成1点伤害；对建筑无效。以 config/tables/cards.csv::hedgehog.skill_text 为源并导出 runtime/config/cards.json；沿用动物表 V3 的实际生命伤害触发，包含近战与远程来源，反伤不递归，保留既有致死处理和护盾完全吸收不触发的边界。伤害来源为基地、防御塔或其他建筑时，该技能不造成反伤；刺猬对建筑的普通攻击照常。本条取代历史“仅近战、3 点反伤”口径。",
    "验收覆盖七类弹体、不同动物与塔的映射、终点短暂收缩、低血建筑可见填充、同帧建筑销毁后不复原，以及刺猬对近战动物、远程动物和建筑来源的区别；复核普通攻击建筑、护盾完全吸收、既有致死边界与其余战斗数值不变。本节为本轮正式规则修订，不等同于运行时通过。",
]


def paragraph_text(paragraph):
    return "".join(paragraph.xpath(".//w:t/text()", namespaces=NS))


def set_text(paragraph, text):
    run_properties = paragraph.find("w:r/w:rPr", NS)
    for child in list(paragraph):
        if child.tag != W + "pPr":
            paragraph.remove(child)
    run = etree.SubElement(paragraph, W + "r")
    if run_properties is not None:
        run.append(deepcopy(run_properties))
    etree.SubElement(run, W + "t").text = text


def main():
    with ZipFile(DOCX) as archive:
        records = [(item, archive.read(item.filename)) for item in archive.infolist()]
    source = next(data for item, data in records if item.filename == "word/document.xml")
    tree = etree.fromstring(source)
    body = tree.find("w:body", NS)
    paragraphs = body.findall("w:p", NS)
    existing = next((p for p in paragraphs if paragraph_text(p) == HEADING), None)
    if existing is not None:
        actual = [paragraph_text(p) for p in existing.itersiblings() if p.tag == W + "p"]
        if actual != RULES:
            raise RuntimeError("The existing amendment was edited; preserve it for manual review.")
        print("The approved amendment already exists; no document changes made.")
        return
    heading_template = next(p for p in paragraphs if paragraph_text(p).startswith("16. 2026-08-25"))
    normal_template = next(p for p in paragraphs if paragraph_text(p).startswith("本文档整理当前"))
    date = next(p for p in paragraphs if paragraph_text(p).startswith("更新日期："))
    set_text(date, "更新日期：2026-09-25")
    section = body.find("w:sectPr", NS)
    position = body.index(section) if section is not None else len(body)
    for template, value in [(heading_template, HEADING), *[(normal_template, rule) for rule in RULES]]:
        paragraph = deepcopy(template)
        set_text(paragraph, value)
        body.insert(position, paragraph)
        position += 1
    updated = etree.tostring(tree, encoding="UTF-8", xml_declaration=True, standalone=True)
    with ZipFile(DOCX, "w") as archive:
        for item, data in records:
            archive.writestr(item, updated if item.filename == "word/document.xml" else data)
    print("Updated existing formal DOCX; all other package members preserved byte-for-byte.")


if __name__ == "__main__":
    main()
