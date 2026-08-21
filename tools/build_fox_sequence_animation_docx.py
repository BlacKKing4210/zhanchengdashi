from __future__ import annotations

from pathlib import Path

from docx import Document
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Cm, Pt, RGBColor


ROOT = Path(__file__).resolve().parents[1]
TEMPLATE = Path(
    r"C:\Users\76398\.codex\skills\game-feature-design-docs\assets\simple-feature-design-template.docx"
)
OUTPUT = ROOT / "docs" / "FOX_SEQUENCE_ANIMATION_AND_GENERIC_FALLBACK_DESIGN_v1.0.docx"

INK = "172033"
BLUE = "2E74B5"
TEAL = "197A78"
GRAY = "5B6574"
LIGHT_BLUE = "EAF3FA"
LIGHT_GOLD = "FFF4D6"
LIGHT_GRAY = "F2F4F7"
LIGHT_RED = "FDECEC"
WHITE = "FFFFFF"

FRAME_PREVIEWS = [
    (ROOT / "assets" / "animal_sequences" / "fox" / "idle" / "frame_007.png", "待机，第 7 / 13 帧"),
    (ROOT / "assets" / "animal_sequences" / "fox" / "move" / "frame_008.png", "行走，第 8 / 15 帧"),
    (ROOT / "assets" / "animal_sequences" / "fox" / "attack" / "frame_005.png", "施法攻击，第 5 / 10 帧"),
]


def set_run_font(run, size: float = 10.5, bold: bool = False, color: str = INK) -> None:
    run.font.name = "Microsoft YaHei"
    fonts = run._element.get_or_add_rPr().rFonts
    for key in ("ascii", "hAnsi", "eastAsia"):
        fonts.set(qn(f"w:{key}"), "Microsoft YaHei")
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.color.rgb = RGBColor.from_string(color)


def set_cell_shading(cell, color: str) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = tc_pr.find(qn("w:shd"))
    if shd is None:
        shd = OxmlElement("w:shd")
        tc_pr.append(shd)
    shd.set(qn("w:fill"), color)


def set_cell_margins(cell, top: int = 90, start: int = 105, bottom: int = 90, end: int = 105) -> None:
    tc_pr = cell._tc.get_or_add_tcPr()
    tc_mar = tc_pr.first_child_found_in("w:tcMar")
    if tc_mar is None:
        tc_mar = OxmlElement("w:tcMar")
        tc_pr.append(tc_mar)
    for edge, value in (("top", top), ("start", start), ("bottom", bottom), ("end", end)):
        element = tc_mar.find(qn(f"w:{edge}"))
        if element is None:
            element = OxmlElement(f"w:{edge}")
            tc_mar.append(element)
        element.set(qn("w:w"), str(value))
        element.set(qn("w:type"), "dxa")


def set_cell_text(cell, text: str, *, bold: bool = False, color: str = INK, size: float = 9.3) -> None:
    cell.text = ""
    paragraph = cell.paragraphs[0]
    paragraph.paragraph_format.space_after = Pt(0)
    paragraph.paragraph_format.line_spacing = 1.08
    set_run_font(paragraph.add_run(text), size, bold, color)
    cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER
    set_cell_margins(cell)


def set_repeat_table_header(row) -> None:
    tr_pr = row._tr.get_or_add_trPr()
    repeat = OxmlElement("w:tblHeader")
    repeat.set(qn("w:val"), "true")
    tr_pr.append(repeat)


def set_table_fixed_layout(table) -> None:
    tbl_pr = table._tbl.tblPr
    layout = tbl_pr.find(qn("w:tblLayout"))
    if layout is None:
        layout = OxmlElement("w:tblLayout")
        tbl_pr.append(layout)
    layout.set(qn("w:type"), "fixed")


def add_table(doc: Document, headers: list[str], rows: list[list[str]], widths_cm: list[float]):
    table = doc.add_table(rows=1, cols=len(headers))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.style = "Table Grid"
    table.autofit = False
    set_table_fixed_layout(table)
    for index, header in enumerate(headers):
        cell = table.rows[0].cells[index]
        cell.width = Cm(widths_cm[index])
        set_cell_shading(cell, BLUE)
        set_cell_text(cell, header, bold=True, color=WHITE)
    set_repeat_table_header(table.rows[0])
    for row_index, values in enumerate(rows):
        cells = table.add_row().cells
        for index, value in enumerate(values):
            cells[index].width = Cm(widths_cm[index])
            if row_index % 2 == 1:
                set_cell_shading(cells[index], LIGHT_GRAY)
            set_cell_text(cells[index], str(value))
    spacer = doc.add_paragraph()
    spacer.paragraph_format.space_after = Pt(0)
    return table


def add_body(doc: Document, text: str, *, bold: bool = False, color: str = INK) -> None:
    paragraph = doc.add_paragraph()
    paragraph.paragraph_format.space_after = Pt(6)
    paragraph.paragraph_format.line_spacing = 1.15
    set_run_font(paragraph.add_run(text), bold=bold, color=color)


def add_bullet(doc: Document, text: str, level: int = 0) -> None:
    paragraph = doc.add_paragraph(style="List Bullet" if level == 0 else "List Bullet 2")
    paragraph.paragraph_format.space_after = Pt(4)
    set_run_font(paragraph.add_run(text))


def add_number(doc: Document, text: str) -> None:
    paragraph = doc.add_paragraph(style="List Number")
    paragraph.paragraph_format.space_after = Pt(4)
    set_run_font(paragraph.add_run(text))


def add_callout(doc: Document, text: str, color: str = LIGHT_GOLD) -> None:
    table = doc.add_table(rows=1, cols=1)
    table.style = "Table Grid"
    set_repeat_table_header(table.rows[0])
    set_cell_shading(table.cell(0, 0), color)
    set_cell_text(table.cell(0, 0), text, bold=True, size=10.2)
    doc.add_paragraph().paragraph_format.space_after = Pt(0)


def add_field(paragraph, instruction: str, cached: str = "") -> None:
    run = paragraph.add_run()
    begin = OxmlElement("w:fldChar")
    begin.set(qn("w:fldCharType"), "begin")
    instr = OxmlElement("w:instrText")
    instr.set(qn("xml:space"), "preserve")
    instr.text = instruction
    separate = OxmlElement("w:fldChar")
    separate.set(qn("w:fldCharType"), "separate")
    text = OxmlElement("w:t")
    text.text = cached
    end = OxmlElement("w:fldChar")
    end.set(qn("w:fldCharType"), "end")
    for element in (begin, instr, separate, text, end):
        run._r.append(element)


def set_update_fields(doc: Document) -> None:
    settings = doc.settings._element
    update = settings.find(qn("w:updateFields"))
    if update is None:
        update = OxmlElement("w:updateFields")
        settings.append(update)
    update.set(qn("w:val"), "true")


def clear_template_body(doc: Document) -> None:
    body = doc._element.body
    section_properties = body.sectPr
    for child in list(body):
        if child is not section_properties:
            body.remove(child)


def style_document(doc: Document) -> None:
    section = doc.sections[0]
    section.page_width = Cm(21.0)
    section.page_height = Cm(29.7)
    section.top_margin = Cm(1.5)
    section.bottom_margin = Cm(1.5)
    section.left_margin = Cm(1.5)
    section.right_margin = Cm(1.5)
    section.header_distance = Cm(0.7)
    section.footer_distance = Cm(0.7)

    normal = doc.styles["Normal"]
    normal.font.name = "Microsoft YaHei"
    normal._element.rPr.rFonts.set(qn("w:eastAsia"), "Microsoft YaHei")
    normal.font.size = Pt(10.5)
    normal.paragraph_format.space_after = Pt(5)
    normal.paragraph_format.line_spacing = 1.15

    for style_name, size, color, before, after in (
        ("Heading 1", 16, BLUE, 13, 6),
        ("Heading 2", 12.5, TEAL, 9, 5),
        ("Heading 3", 11, GRAY, 7, 4),
    ):
        style = doc.styles[style_name]
        style.font.name = "Microsoft YaHei"
        style._element.rPr.rFonts.set(qn("w:eastAsia"), "Microsoft YaHei")
        style.font.size = Pt(size)
        style.font.bold = True
        style.font.color.rgb = RGBColor.from_string(color)
        style.paragraph_format.space_before = Pt(before)
        style.paragraph_format.space_after = Pt(after)
        style.paragraph_format.keep_with_next = True

    for list_name in ("List Bullet", "List Bullet 2", "List Number"):
        style = doc.styles[list_name]
        style.font.name = "Microsoft YaHei"
        style._element.rPr.rFonts.set(qn("w:eastAsia"), "Microsoft YaHei")
        style.font.size = Pt(10.5)

    header = section.header.paragraphs[0]
    header.text = "丛林法则｜动物序列帧选择与通用动效回退"
    set_run_font(header.runs[0], 8.5, color=GRAY)
    footer = section.footer.paragraphs[0]
    footer.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    footer.text = "v1.0｜2026-08-21｜"
    set_run_font(footer.runs[0], 8.5, color=GRAY)
    add_field(footer, "PAGE", "1")
    set_run_font(footer.add_run(" / "), 8.5, color=GRAY)
    add_field(footer, "NUMPAGES", "1")


def add_title(doc: Document) -> None:
    title = doc.add_paragraph()
    title.paragraph_format.space_before = Pt(20)
    title.paragraph_format.space_after = Pt(6)
    set_run_font(title.add_run("动物序列帧选择与通用动效回退"), 22, True, INK)
    subtitle = doc.add_paragraph()
    subtitle.paragraph_format.space_after = Pt(14)
    set_run_font(subtitle.add_run("狐狸 idle / move / attack 首个实装｜无资源动物保持原程序动效"), 12, color=BLUE)

    add_table(
        doc,
        ["字段", "内容"],
        [
            ["文档类型", "Game Feature Design Simple｜IMPLEMENTATION_CONTRACT / NARROW"],
            ["请求 / 功能", "REQ-20260821-FOX-SEQUENCE-FALLBACK-001 / F-ZC-ANIMAL-ANIMATION-001"],
            ["版本 / 日期", "v1.0 / 2026-08-21"],
            ["批准与负责", "制作人：用户｜工程负责人：codex-primary"],
            ["玩家记忆点", "有专属帧的动物看起来真正活起来；其他动物的表现完全不退化。"],
            ["发布边界", "本地实现与 Godot 运行时验收；Android 包和公网发行权利另设门禁。"],
        ],
        [3.5, 14.2],
    )
    add_callout(
        doc,
        "硬规则：按动物 ID 和动作读取已验证清单。可用动作走序列帧；可选动作未登记时在有效待机帧上叠加原通用姿态；清单无效或整只动物未登记时完整沿用旧静态图 + UnitMotionFeedback。",
        LIGHT_BLUE,
    )
    doc.add_page_break()


def add_toc(doc: Document) -> None:
    doc.add_heading("目录", level=1)
    paragraph = doc.add_paragraph()
    add_field(paragraph, 'TOC \\o "1-3" \\h \\z \\u', "目录将在 Word 打开时更新")
    doc.add_page_break()


def add_frame_previews(doc: Document) -> None:
    for path, _caption in FRAME_PREVIEWS:
        if not path.is_file():
            raise FileNotFoundError(f"Missing frame preview: {path}")
    table = doc.add_table(rows=1, cols=3)
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False
    for index, (path, caption) in enumerate(FRAME_PREVIEWS):
        cell = table.cell(0, index)
        cell.width = Cm(5.7)
        paragraph = cell.paragraphs[0]
        paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
        run = paragraph.add_run()
        shape = run.add_picture(str(path), width=Cm(5.0))
        shape._inline.docPr.set("descr", f"狐狸序列帧预览：{caption}")
        caption_paragraph = cell.add_paragraph()
        caption_paragraph.alignment = WD_ALIGN_PARAGRAPH.CENTER
        set_run_font(caption_paragraph.add_run(caption), 8.5, color=GRAY)
        set_cell_margins(cell, 70, 70, 70, 70)
    set_repeat_table_header(table.rows[0])
    doc.add_paragraph().paragraph_format.space_after = Pt(0)


def build_document() -> Document:
    doc = Document(TEMPLATE)
    clear_template_body(doc)
    style_document(doc)
    add_title(doc)
    add_toc(doc)

    doc.add_heading("1. 术语、版本与决策", level=1)
    add_table(
        doc,
        ["术语", "定义"],
        [
            ["序列动物", "`assets/animal_sequences/manifest.json` 中通过完整校验并至少拥有 idle 动作的动物 ID。"],
            ["动作序列", "同一动物下的 idle、move、attack 等有序 PNG 路径、播放方式、源区域和脚底基线。"],
            ["通用动效", "现有 `scripts/app/systems/unit_motion_feedback.gd` 提供的移动、攻击、受击、强化和死亡程序姿态。"],
            ["动作级回退", "可选动作未登记时，优先使用有效 idle 帧并叠加通用姿态；清单或动物注册无效时回到旧静态图。"],
        ],
        [4.0, 13.7],
    )
    add_table(
        doc,
        ["版本", "日期", "变更", "状态"],
        [["v1.0", "2026-08-21", "建立通用清单、狐狸三动作与安全回退合同", "制作人已授权实现"]],
        [2.0, 2.8, 9.2, 3.7],
    )

    doc.add_heading("2. 设计目的", level=1)
    doc.add_heading("2.1 主要目标", level=2)
    add_bullet(doc, "狐狸在战场待机、移动和攻击时显示对应的手绘序列，而不是只对一张静态图做位移和缩放。")
    add_bullet(doc, "建立可扩展的动物 ID + 动作清单；后续新增动物只放资源和登记清单，不再写一份专属渲染分支。")
    add_bullet(doc, "没有序列资源的动物保持现在的视觉节奏、碰撞位置和战斗行为。")
    doc.add_heading("2.2 次要目标", level=2)
    add_bullet(doc, "错误资源、断帧、错误路径或错误源区域均安全降级到可玩表现，并只记录一次诊断警告。")
    doc.add_heading("2.3 非目标", level=2)
    add_bullet(doc, "不修改数值、攻击冷却、技能触发、伤害时点、目标选择、网络权威、地图、UI、卡牌静态美术或音频。")
    add_bullet(doc, "不生成补帧，不替其他动物制作素材，不在本版本导出 Android 包。")

    doc.add_heading("3. 功能概述", level=1)
    add_number(doc, "进入现有战斗页并生成动物单位。")
    add_number(doc, "渲染器按单位 card ID 查询已验证的动画清单。")
    add_number(doc, "狐狸待机播放 idle 循环；移动播放 move 循环；攻击反馈窗口按进度播放 attack 非循环序列。")
    add_number(doc, "若当前可选动作没有登记，则用有效 idle 帧承接原通用姿态；若清单结构或动物注册无效，则走旧静态纹理和通用姿态。")
    add_number(doc, "只替换渲染采样，单位字典中的位置、生命、目标、冷却和网络快照语义不变。")

    doc.add_heading("4. UE 总流程与页面边界", level=1)
    add_callout(doc, "本功能不新增页面、按钮、HUD、弹窗、入口或跳转。现有战斗页是唯一 UE Frame，因此 Penpot 页面图在 v1.0 标记为 Not needed；任何未来布局或交互改动必须重新打开 UE 门禁。", LIGHT_GOLD)
    add_table(
        doc,
        ["战斗状态", "系统事件", "视觉结果", "下一状态"],
        [
            ["生成完成", "单位静止", "有效序列动物播放 idle；其他动物保持旧表现", "移动 / 攻击 / 受击"],
            ["寻路移动", "motion_moving=true", "优先 move 循环；缺失则 idle + 通用移动姿态", "停止 / 攻击"],
            ["发起攻击", "motion_kind=attack", "按攻击反馈进度播放一次 attack；缺失则通用攻击姿态", "待机 / 移动"],
            ["受击/强化", "hit / stat_gain / power_up", "在有效 idle 帧上叠加现有通用姿态", "原战斗状态"],
            ["死亡快照", "unit_death_snapshot", "有效 idle 帧叠加现有死亡姿态；无序列动物不变", "单位移除"],
        ],
        [3.0, 3.9, 7.3, 3.5],
    )

    doc.add_heading("5. 配置与资源来源", level=1)
    add_table(
        doc,
        ["名称", "字段 / 路径", "类型", "规则"],
        [
            ["动物注册", "assets/animal_sequences/manifest.json::animals.<card_id>", "Dictionary", "card_id 必须为安全小写 ID；整体校验失败则不注册。"],
            ["动作", "actions.idle / move / attack", "Dictionary", "idle 必需；动作只接受 allowlist 键。"],
            ["帧路径", "actions.<action>.frames[]", "Array[String]", "仅 res://assets/animal_sequences/ 下 PNG；顺序完整、路径唯一、资源存在。"],
            ["循环速率", "actions.<action>.fps", "Float", "循环动作 >0 且 <=60；attack 使用现有 motion progress，不改战斗计时。"],
            ["源区域", "source_rect", "[x,y,w,h]", "必须为正并位于 836 x 480 纹理内；狐狸 v1.0 使用统一 410 x 410 区域。"],
            ["脚底比例", "bottom_padding_ratio", "Float", "0..0.5；把可见脚底对齐原战场锚点。"],
            ["静态卡图", "config/tables/cards.csv::art_path", "String", "只读；卡牌、图鉴、弹窗继续使用旧狐狸静态图。"],
        ],
        [2.8, 6.5, 2.5, 5.9],
    )

    doc.add_heading("6. 系统逻辑", level=1)
    doc.add_heading("6.1 清单加载", level=2)
    add_number(doc, "首次需要战场单位纹理时读取 JSON；版本、动物 ID、动作键、帧路径、帧数量、FPS、源区域和脚底比例全部先校验。")
    add_number(doc, "完整清单按严格 schema 校验；任何已登记字段或资源无效都会拒绝整份清单，避免部分损坏配置被误当成有效。未登记的可选 move / attack 动作仍允许按规则回退。")
    add_number(doc, "纹理按实际帧惰性加载并缓存；单帧加载失败使该动作回退，不能让绘制函数抛错。")
    doc.add_heading("6.2 帧选择优先级", level=2)
    add_table(
        doc,
        ["优先级", "条件", "选取", "通用姿态"],
        [
            ["1", "attack 正在播放且 attack 有效", "按 motion progress 取 0..N-1", "抑制通用攻击位移，避免双重动作"],
            ["2", "正在移动且 move 有效", "按 ui_time + unit_id 种子循环", "抑制通用移动起伏，避免双重动作"],
            ["3", "idle 有效", "按 ui_time + unit_id 种子循环", "受击/强化等仍叠加通用姿态"],
            ["4", "无有效序列动物", "cards.csv 静态纹理", "完整沿用 UnitMotionFeedback"],
        ],
        [2.0, 5.4, 5.4, 4.9],
    )
    doc.add_heading("6.3 视觉与逻辑隔离", level=2)
    add_bullet(doc, "序列时间来自现有视觉状态和本地 ui_time；不写入伤害、冷却、移动或网络权威字段。")
    add_bullet(doc, "源区域通过 `draw_texture_rect_region` 在同一脚底锚点绘制；不修改逻辑坐标或碰撞。")
    add_bullet(doc, "帧动作不进入卡牌 UI；所有非战场 `_card_texture()` 调用保持不变。")

    doc.add_heading("7. 美术资源与显示规格", level=1)
    add_frame_previews(doc)
    add_bullet(doc, "来源归档：狐狸远程.zip，SHA-256 3235D0961681105B7F0F31A924C5BD4F255F6EB3DE435A1E04E857973501C0B6。")
    add_bullet(doc, "帧数：idle 13、move 15、attack 10；全部 836 x 480 RGBA；原始像素逐帧保留。")
    add_bullet(doc, "统一显示源区域只影响渲染采样，不生成重采样副本；各帧脚底落点继续由同一 bottom_padding_ratio 对齐。")
    add_bullet(doc, "后续动物必须提供完整来源哈希、动作命名、帧顺序、源区域、脚底比例和权利状态后才可登记。")

    doc.add_heading("8. 边界、异常与状态", level=1)
    add_table(
        doc,
        ["异常", "处理", "玩家结果"],
        [
            ["manifest 不存在/JSON 损坏/版本错误", "注册表为空并警告一次", "所有动物沿用旧通用动效"],
            ["动物 ID 或未知字段不合法", "拒绝该动物注册", "该动物沿用旧通用动效"],
            ["idle 断帧或资源缺失", "拒绝该动物注册", "该动物沿用旧通用动效"],
            ["move/attack 未登记", "保留该动物有效 idle", "有效 idle 帧 + 对应通用姿态"],
            ["运行时单帧加载失败", "缓存失败并回退", "同帧立即走安全回退，不出现空白单位"],
            ["网络快照缺少视觉字段", "按默认 idle 或静态路径", "不影响同步和战斗结果"],
        ],
        [4.3, 6.2, 7.2],
    )

    doc.add_heading("9. UI、音频、打点与相关系统", level=1)
    add_table(
        doc,
        ["领域", "要求"],
        [
            ["UI / UE", "无新增页面、布局、文案、按钮、HUD、点击区域或状态。"],
            ["音频", "无新增；攻击和技能音效继续由现有战斗事件触发。"],
            ["打点", "无新增玩家分析事件；调试仅允许记录动物 ID、动作和错误码，不记录本地绝对路径。"],
            ["网络", "单位逻辑快照格式不变；序列采样是客户端表现层。"],
            ["卡牌美术", "图鉴、套牌、卡片详情、弹窗和升级页仍读取 cards.csv::art_path。"],
            ["扩展", "未来新增动物只扩展资源目录和 manifest；若引入朝向、混合、事件帧或碰撞帧，升级为 material 合同。"],
        ],
        [3.1, 14.6],
    )

    doc.add_heading("10. QA 验收", level=1)
    add_table(
        doc,
        ["编号", "场景", "通过标准"],
        [
            ["ING-01", "归档导入", "严格匹配归档哈希、38 帧、3 动作、连续编号、836 x 480 RGBA、无越界路径。"],
            ["SEQ-01", "狐狸待机", "13 帧循环且脚底稳定；不再使用静态狐狸图。"],
            ["SEQ-02", "狐狸移动", "15 帧循环；通用移动起伏不叠加；逻辑位置不变。"],
            ["SEQ-03", "狐狸攻击", "10 帧按现有 attack 反馈进度播放一次；冷却和伤害时点不变。"],
            ["SEQ-04", "狐狸受击/强化/死亡", "有效 idle 帧承接现有通用姿态，不出现旧图闪回。"],
            ["FB-01", "兔子或任意未登记动物", "纹理与 UnitMotionFeedback 结果和基线一致。"],
            ["FB-02", "损坏 manifest / 缺帧 / 错误路径", "不崩溃、不画空白单位，按动作级或动物级规则回退。"],
            ["NET-01", "同一单位逻辑快照前后", "位置、生命、攻击、范围、目标、冷却和队伍字段无变化。"],
            ["VIS-01", "真实运行时捕获", "同屏狐狸使用序列帧，非序列动物使用旧通用动效；不是静态素材盘点。"],
            ["REG-01", "既有回归", "unit procedural motion、相关 battle regression、全项目解析与 tab 缩进检查通过。"],
            ["DOC-01", "DOCX", "结构检查通过；有可用渲染器时逐页 PNG 无裁切、重叠或乱码。"],
        ],
        [2.0, 5.6, 10.1],
    )

    doc.add_heading("11. 发布、回滚与升级条件", level=1)
    add_callout(doc, "本合同关闭只代表本地 Godot 实装与可见运行时验证。Android 包、阿里云部署、商店发行和素材公网分发权利均是独立门禁。", LIGHT_RED)
    add_bullet(doc, "回滚只需移除序列 manifest 注册、资源目录和窄集成；cards.csv 与旧静态纹理未改，因此所有动物可立即回到原通用动效。")
    add_bullet(doc, "新增朝向翻转、动画混合、关键帧伤害、碰撞帧、远程弹道同步或服务器权威动画时，必须升级为 MATERIAL 合同。")
    add_bullet(doc, "完成回执必须记录源归档与帧哈希、Godot 命令、截图、回归结果、提交范围、推送结果和未解决发行门禁。")

    doc.core_properties.title = "动物序列帧选择与通用动效回退"
    doc.core_properties.subject = "狐狸三动作序列帧首个实装与无资源动物安全回退合同"
    doc.core_properties.author = "Codex Game Studio"
    doc.core_properties.keywords = "Godot, fox, sequence frames, animation, fallback"
    set_update_fields(doc)
    return doc


if __name__ == "__main__":
    document = build_document()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    document.save(OUTPUT)
    print(OUTPUT)
