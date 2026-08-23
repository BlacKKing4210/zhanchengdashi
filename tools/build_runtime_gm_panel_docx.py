from __future__ import annotations

import os
from pathlib import Path

from docx import Document
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


ROOT = Path(__file__).resolve().parents[1]
TEMPLATE_OVERRIDE = os.environ.get("ZC_FEATURE_TEMPLATE", "").strip()
TEMPLATE = (
    Path(TEMPLATE_OVERRIDE)
    if TEMPLATE_OVERRIDE
    else Path.home() / ".codex" / "skills" / "game-feature-design-docs" / "assets" / "general-feature-design-template.docx"
)
OUTPUT = ROOT / "docs" / "RUNTIME_GM_PANEL_DESIGN_v1.0.docx"

INK = "172033"
BLUE = "2E74B5"
TEAL = "197A78"
GRAY = "5B6574"
RED = "C23B3B"
GREEN = "2F8F5B"
LIGHT_BLUE = "EAF3FA"
LIGHT_GOLD = "FFF4D6"
LIGHT_GRAY = "F2F4F7"
LIGHT_RED = "FDECEC"
LIGHT_GREEN = "EAF6EF"
WHITE = "FFFFFF"


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


def set_cell_text(cell, text: str, *, bold: bool = False, color: str = INK, size: float = 9.3) -> None:
    cell.text = ""
    paragraph = cell.paragraphs[0]
    paragraph.paragraph_format.space_after = Pt(0)
    paragraph.paragraph_format.line_spacing = 1.03
    set_run_font(paragraph.add_run(text), size, bold, color)
    cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER


def set_repeat_table_header(row) -> None:
    tr_pr = row._tr.get_or_add_trPr()
    repeat = OxmlElement("w:tblHeader")
    repeat.set(qn("w:val"), "true")
    tr_pr.append(repeat)


def keep_table_row_together(row) -> None:
    tr_pr = row._tr.get_or_add_trPr()
    cant_split = OxmlElement("w:cantSplit")
    cant_split.set(qn("w:val"), "true")
    tr_pr.append(cant_split)


def add_table(doc: Document, headers: list[str], rows: list[list[str]], widths: list[float] | None = None):
    table = doc.add_table(rows=1, cols=len(headers))
    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.style = "Table Grid"
    for index, header in enumerate(headers):
        set_cell_shading(table.rows[0].cells[index], BLUE)
        set_cell_text(table.rows[0].cells[index], header, bold=True, color=WHITE)
        if widths:
            table.rows[0].cells[index].width = Inches(widths[index])
    set_repeat_table_header(table.rows[0])
    keep_table_row_together(table.rows[0])
    for row_index, values in enumerate(rows):
        cells = table.add_row().cells
        for index, value in enumerate(values):
            if row_index % 2 == 1:
                set_cell_shading(cells[index], LIGHT_GRAY)
            set_cell_text(cells[index], value)
            if widths:
                cells[index].width = Inches(widths[index])
        keep_table_row_together(table.rows[-1])
    doc.add_paragraph().paragraph_format.space_after = Pt(0)
    return table


def add_body(doc: Document, text: str, *, color: str = INK, bold: bool = False) -> None:
    paragraph = doc.add_paragraph()
    paragraph.paragraph_format.space_after = Pt(6)
    paragraph.paragraph_format.line_spacing = 1.15
    set_run_font(paragraph.add_run(text), bold=bold, color=color)


def add_bullet(doc: Document, text: str, level: int = 0) -> None:
    paragraph = doc.add_paragraph(style="List Bullet" if level == 0 else "List Bullet 2")
    paragraph.paragraph_format.space_after = Pt(4)
    set_run_font(paragraph.add_run(text))


def add_step(doc: Document, index: int, text: str) -> None:
    paragraph = doc.add_paragraph()
    paragraph.paragraph_format.left_indent = Inches(0.24)
    paragraph.paragraph_format.first_line_indent = Inches(-0.24)
    paragraph.paragraph_format.space_after = Pt(4)
    set_run_font(paragraph.add_run(f"{index}.  {text}"))


def add_callout(doc: Document, text: str, color: str = LIGHT_GOLD, text_color: str = INK) -> None:
    table = doc.add_table(rows=1, cols=1)
    table.style = "Table Grid"
    set_cell_shading(table.cell(0, 0), color)
    set_cell_text(table.cell(0, 0), text, bold=True, color=text_color, size=10.2)
    doc.add_paragraph().paragraph_format.space_after = Pt(0)


def clear_template_body(doc: Document) -> None:
    body = doc._element.body
    section_properties = body.sectPr
    for child in list(body):
        if child is not section_properties:
            body.remove(child)


def style_document(doc: Document) -> None:
    section = doc.sections[0]
    section.page_width = Inches(8.27)
    section.page_height = Inches(11.69)
    section.top_margin = Inches(0.72)
    section.bottom_margin = Inches(0.68)
    section.left_margin = Inches(0.75)
    section.right_margin = Inches(0.75)
    section.header_distance = Inches(0.28)
    section.footer_distance = Inches(0.28)

    normal = doc.styles["Normal"]
    normal.font.name = "Microsoft YaHei"
    normal._element.rPr.rFonts.set(qn("w:eastAsia"), "Microsoft YaHei")
    normal.font.size = Pt(10.5)
    normal.paragraph_format.space_after = Pt(5)
    normal.paragraph_format.line_spacing = 1.15

    for style_name, size, color, before, after in (
        ("Heading 1", 16, BLUE, 13, 7),
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
    header.text = "丛林法则｜运行时 GM 资源面板"
    set_run_font(header.runs[0], 8.5, color=GRAY)
    footer = section.footer.paragraphs[0]
    footer.alignment = WD_ALIGN_PARAGRAPH.RIGHT
    footer.text = "v1.0｜2026-08-23｜INTERNAL DEBUG ONLY"
    set_run_font(footer.runs[0], 8.5, color=GRAY)


def add_title_page(doc: Document) -> None:
    title = doc.add_paragraph()
    title.paragraph_format.space_before = Pt(34)
    title.paragraph_format.space_after = Pt(7)
    set_run_font(title.add_run("运行时 GM 资源面板"), 25, True, INK)

    subtitle = doc.add_paragraph()
    subtitle.paragraph_format.space_after = Pt(18)
    set_run_font(subtitle.add_run("F2 调试入口｜本地资源修改｜线上与发行环境硬隔离"), 12.5, False, BLUE)

    add_table(
        doc,
        ["字段", "内容"],
        [
            ["文档类型", "IMPLEMENTATION_CONTRACT｜INTERNAL_DEBUG_ONLY"],
            ["请求编号", "REQ-20260823-RUNTIME-GM-PANEL"],
            ["功能编号", "F-ZC-GM-001"],
            ["版本 / 日期", "v1.0 / 2026-08-23"],
            ["主策划 / 制作人", "用户制作人（需求与边界批准）"],
            ["制作程序", "codex-primary"],
            ["目标环境", "Godot 4.6 Debug；Windows 开发验证"],
            ["正式发行状态", "禁止启用；不进入 Release / Android 正式包"],
            ["设计源说明", "内部工程工具，不建立生产 Penpot/Figma 页面；本文状态表与运行时截图为验收源"],
        ],
        [1.45, 5.1],
    )
    add_callout(
        doc,
        "红线：GM 面板不得修改在线对战状态、登录账号的云端资源、服务器档案或后台发放记录；不得携带任何管理员凭据。",
        LIGHT_RED,
        RED,
    )
    doc.add_page_break()


def add_toc(doc: Document) -> None:
    doc.add_heading("目录", level=1)
    for line in (
        "1. 术语缩写与修订标记",
        "2. 设计目的",
        "3. 功能概述",
        "4. 系统框架",
        "5. UE 总流程与节点覆盖",
        "6. 参考与当前基线",
        "7. 配置与数据源调整",
        "8. 系统逻辑",
        "9. UI 界面及状态",
        "10. 相关需求",
        "11. 关联拓展",
        "12. 验收与 QA",
    ):
        paragraph = doc.add_paragraph()
        paragraph.paragraph_format.left_indent = Inches(0.25)
        paragraph.paragraph_format.space_after = Pt(3)
        set_run_font(paragraph.add_run(line), 10, color=GRAY)
    doc.add_page_break()


def build_document() -> Document:
    doc = Document(TEMPLATE)
    clear_template_body(doc)
    style_document(doc)
    add_title_page(doc)
    add_toc(doc)

    doc.add_heading("1. 术语缩写与修订标记", level=1)
    add_table(
        doc,
        ["术语", "定义"],
        [
            ["GM", "Game Master 调试能力；本功能仅指客户端开发态资源修改工具。"],
            ["Debug Build", "`OS.is_debug_build()` 为 true 的工程运行或调试导出。"],
            ["账号资源", "抽卡券、卡牌数量、卡牌等级；登录后会进入服务器档案同步范围。"],
            ["战斗资源", "本地经典战斗的即时金币；随战斗重置，不属于账号档案。"],
            ["会话本地", "仅修改当前客户端进程内存，不写服务器、不调用管理后台、不承诺重启保留。"],
        ],
        [1.45, 5.1],
    )
    add_table(
        doc,
        ["版本", "日期", "更新内容", "状态"],
        [["v1.0", "2026-08-23", "建立 F2 GM 面板、资源操作、安全门禁与 QA 合同", "制作人已批准实施"]],
        [0.75, 1.05, 4.05, 1.0],
    )

    doc.add_heading("2. 设计目的", level=1)
    doc.add_heading("2.1 主要目标", level=2)
    add_bullet(doc, "开发人员在当前 Godot 游戏运行时按 F2 即可打开或关闭 GM 弹窗，无需退出战斗或手改存档。")
    add_bullet(doc, "在一个清晰面板中查看当前值，对允许资源执行增加、减少或设为指定整数，并立即看到结果。")
    add_bullet(doc, "所有修改先经过同一套规则与边界校验，错误不产生半次修改，成功与失败均有可见反馈。")
    doc.add_heading("2.2 次要目标", level=2)
    add_bullet(doc, "实际控件支持鼠标点击与键盘输入，Modal 打开时不穿透到底层地图、卡组或房间交互。")
    add_bullet(doc, "规则层与 UI 层解耦，便于自动化验证和后续增加新的本地调试项。")
    doc.add_heading("2.3 非目标", level=2)
    add_bullet(doc, "不制作线上运营后台、不授予真实玩家云资源、不修改账号服务或多人协议。")
    add_bullet(doc, "不为 Android 正式包增加 GM 入口，也不通过触屏手势替代 F2。")
    add_bullet(doc, "不新增美术、音效、埋点、配置表或持久化存档格式。")

    doc.add_heading("3. 功能概述", level=1)
    for index, item in enumerate((
        "入口：Debug 运行时按 F2。在线对战中或非 Debug 构建中不打开，并给出明确拒绝理由。",
        "选择：从战斗金币、抽卡券、卡牌数量、卡牌等级中选资源；卡牌类资源同时选择具体卡牌。",
        "操作：选择增加、减少或设为，输入十进制整数，点击“执行修改”。",
        "反馈：系统读取实时当前值，完成门禁、格式、边界和上下文校验；成功后刷新当前值并显示前后差异。",
        "结束：再次按 F2、按 Escape 或点击关闭按钮；焦点与底层输入恢复。",
    ), start=1):
        add_step(doc, index, item)
    add_callout(doc, "一分钟主循环：F2 → 选资源 → 选操作 → 输入整数 → 执行 → 看结果 → F2/Escape 关闭。", LIGHT_GREEN, GREEN)

    doc.add_heading("4. 系统框架", level=1)
    add_table(
        doc,
        ["层", "职责", "实现源", "禁止事项"],
        [
            ["输入 / 生命周期", "捕获 F2/Escape，创建唯一实例，维护显隐", "scripts/app/main.gd", "不得让 F2 进入地图点击逻辑"],
            ["GM Modal UI", "控件、焦点、资源/卡牌/操作选择、提示与当前值", "scripts/app/ui/runtime_gm_panel.gd", "不得直接写游戏变量"],
            ["GM 规则", "门禁、操作归一化、整数解析、上下界与结果计算", "scripts/app/systems/gm_resource_rules.gd", "不得引用服务器或场景树"],
            ["主应用适配", "读取实时上下文与当前值；仅在规则通过后原子赋值", "scripts/app/main.gd", "不得调用 OnlineRoom.save_player_profile 或后台 grant API"],
            ["QA", "纯规则、运行时输入、拒绝路径与截图", "tests/test_*gm* / capture_runtime_gm_panel.gd", "不得用静态文件存在代替运行证据"],
        ],
        [1.0, 1.65, 2.05, 2.1],
    )
    doc.add_heading("4.1 权威数据边界", level=2)
    add_table(
        doc,
        ["资源 ID", "显示名", "当前值来源", "允许上下文", "持久化"],
        [
            ["battle_gold", "战斗金币", "main.gd::gold", "本地经典战斗且非在线", "本场战斗内存"],
            ["gacha_tickets", "抽卡券", "main.gd::gacha_tickets", "未登录游客且非在线对战", "当前进程内存"],
            ["card_count", "卡牌数量", "main.gd::card_counts[card_id]", "未登录游客且非在线对战", "当前进程内存"],
            ["card_level", "卡牌等级", "main.gd::card_levels[card_id]", "未登录游客且非在线对战", "当前进程内存"],
        ],
        [1.05, 1.05, 1.8, 2.0, 1.0],
    )

    doc.add_heading("5. UE 总流程与节点覆盖", level=1)
    add_body(doc, "本功能是发行禁用的内部工程工具，不建立生产玩家页面，也不宣称 Penpot/Figma 评审完成。以下状态与节点表是实现权威；运行时 1080×1920 截图是视觉验收证据。", color=GRAY)
    add_table(
        doc,
        ["节点", "触发 / 玩家动作", "条件", "系统反馈", "返回 / 异常"],
        [
            ["GM-00 关闭", "按 F2", "Debug 且无在线比赛", "打开 Modal 并刷新全部上下文", "拒绝时保持关闭并 Toast"],
            ["GM-01 默认", "选择资源", "资源存在", "刷新当前值、限制说明与卡牌选择器", "资源不可用时禁用执行"],
            ["GM-02 编辑", "选择操作并输入整数", "输入框有焦点", "移动端键盘类型为数字；物理键盘可输入", "Escape 先关闭 Modal"],
            ["GM-03 执行", "点击执行修改", "规则、上下文、范围全部通过", "原子写值；显示旧值→新值", "失败不写值并显示原因"],
            ["GM-04 完成", "再次操作或关闭", "当前值已刷新", "可连续修改；F2/Escape/关闭键退出", "退出后恢复底层输入"],
        ],
        [1.05, 1.55, 1.55, 1.75, 1.45],
    )
    doc.add_heading("5.1 控件覆盖", level=2)
    add_table(
        doc,
        ["控件 ID", "显示", "交互", "数据源", "状态"],
        [
            ["gm_title", "GM 调试面板", "无", "固定文案", "始终"],
            ["resource_option", "资源", "下拉选择", "规则层资源目录", "始终"],
            ["card_option", "卡牌", "下拉选择", "main.gd::cards", "仅卡牌数量/等级"],
            ["operation_option", "操作", "增加/减少/设为", "规则层操作目录", "始终"],
            ["amount_input", "数值", "整数输入；Enter 可执行", "用户输入", "始终"],
            ["current_value", "当前值", "只读", "主应用适配器", "选择变化后刷新"],
            ["apply_button", "执行修改", "点击", "当前选择与输入", "不满足上下文时禁用"],
            ["feedback_label", "结果 / 原因", "只读", "规则或适配器返回", "成功绿色、失败红色"],
            ["close_button", "关闭", "点击", "无", "始终"],
        ],
        [1.05, 1.15, 1.55, 1.6, 1.55],
    )

    doc.add_heading("6. 参考与当前基线", level=1)
    add_table(
        doc,
        ["来源", "版本 / 哈希", "用途"],
        [
            ["制作人需求", "2026-08-23", "F2 入口与资源发放/修改目标"],
            ["scripts/app/main.gd", "SHA-256 8d5f38c…794135b8e", "现有输入、资源、账号同步和经典/多人状态"],
            ["scripts/app/systems/card_rules.gd", "当前工作树", "九级升级费用对应最高卡牌等级 10"],
            ["docs/WORKFLOW.md / AGENTS.md", "v1", "文档优先、RAG、Debug/线上边界、Godot QA"],
            ["项目 RAG", "e88beb67…52f77cb8", "78 源、1107 分块、16/16 查询通过"],
        ],
        [2.2, 2.15, 2.5],
    )
    add_body(doc, "外部资料：无。本功能完全由制作人要求、当前工程代码和项目工作流确定，不需要互联网研究。")

    doc.add_heading("7. 配置与数据源调整", level=1)
    add_body(doc, "不修改 config/tables 或 runtime/config。以下常量全部属于 GM 规则脚本，防止调试数值散落在 UI。")
    add_table(
        doc,
        ["名称", "字段 / 值", "类型", "说明"],
        [
            ["资源通用上限", "MAX_RESOURCE_VALUE = 1,000,000", "int", "战斗金币、抽卡券和卡牌数量的防溢出上限"],
            ["卡牌等级下限", "MIN_CARD_LEVEL = 1", "int", "任何操作后不得低于 1"],
            ["卡牌等级上限", "MAX_CARD_LEVEL = CardRules.LEVEL_COSTS.size() + 1 = 10", "int", "与现有升级费用链一致"],
            ["默认输入", "DEFAULT_AMOUNT_TEXT = 100", "string", "打开后便于常用资源发放"],
            ["操作", "add / subtract / set", "id", "界面显示增加 / 减少 / 设为"],
            ["发行门禁", "OS.is_debug_build()", "bool", "false 时不实例化、不响应 F2"],
        ],
        [1.4, 2.6, 0.85, 2.0],
    )

    doc.add_heading("8. 系统逻辑", level=1)
    doc.add_heading("8.1 打开与关闭", level=2)
    add_step(doc, 1, "`_input` 优先识别非重复 F2；若不是 Debug，直接忽略且不创建 GM UI。")
    add_step(doc, 2, "若在线比赛已激活，保持关闭并 Toast“在线对战禁止使用 GM”。")
    add_step(doc, 3, "首次允许打开时创建一个 CanvasLayer Modal；后续只切换同一实例，避免重复连接信号。")
    add_step(doc, 4, "F2、Escape、关闭按钮均可关闭；Modal 可见时标记输入已处理，底层 `_unhandled_input` 不再收到本次事件。")
    doc.add_heading("8.2 修改事务", level=2)
    add_step(doc, 1, "UI 发送 resource_id、operation_id、amount_text、card_id，不直接持有主应用变量引用。")
    add_step(doc, 2, "规则层依次验证 Debug、在线状态、登录状态、场景上下文、资源/卡牌、整数格式与边界。")
    add_step(doc, 3, "规则层返回 `{ok, next_value, message}`；只有 ok=true 时主应用执行一次赋值。")
    add_step(doc, 4, "赋值后重新读取权威当前值并刷新 UI；成功反馈包含旧值和新值。")
    add_step(doc, 5, "任何拒绝、解析失败或缺失卡牌均不修改资源，也不调用云端保存。")

    doc.add_heading("8.3 操作公式与边界", level=2)
    add_table(
        doc,
        ["操作", "候选值", "结果"],
        [
            ["增加", "current + amount", "夹取到资源上下界；必须输入 amount ≥ 0"],
            ["减少", "current - amount", "夹取到资源上下界；必须输入 amount ≥ 0"],
            ["设为", "amount", "夹取到资源上下界；必须输入 amount ≥ 0"],
            ["非法输入", "空、负数、小数、非数字、超 32 位", "失败；保持 current"],
        ],
        [1.1, 2.4, 3.35],
    )

    doc.add_heading("8.4 状态与边界矩阵", level=2)
    add_table(
        doc,
        ["场景", "打开", "战斗金币", "账号资源", "反馈"],
        [
            ["Debug + 游客 + 大厅/卡组/抽卡/房间", "是", "禁用：不在经典战斗", "允许，会话本地", "显示资源当前值与范围"],
            ["Debug + 游客 + 本地经典战斗", "是", "允许，本场战斗", "允许，会话本地", "成功显示旧值→新值"],
            ["Debug + 已登录 + 非在线比赛", "是", "仅本地经典战斗允许", "禁止", "提示账号资源受云档案保护"],
            ["Debug + 在线比赛进行中", "否", "禁止", "禁止", "Toast 在线对战禁止使用 GM"],
            ["Release 构建", "否", "禁止", "禁止", "无 GM 节点、无 F2 响应"],
            ["输入非法 / 卡牌缺失", "保持原状态", "不修改", "不修改", "红色错误说明"],
        ],
        [1.85, 0.65, 1.55, 1.45, 1.7],
    )

    doc.add_heading("9. UI 界面及状态", level=1)
    doc.add_heading("9.1 页面清单", level=2)
    add_table(
        doc,
        ["页面 ID / 名称", "入口", "退出", "主要状态", "归属"],
        [["GM-MODAL / GM 调试面板", "Debug 运行时 F2", "F2 / Escape / 关闭", "默认、受限、校验失败、执行成功", "内部开发工具"]],
        [1.75, 1.4, 1.6, 2.0, 1.05],
    )
    doc.add_heading("9.2 布局与交互合同", level=2)
    add_bullet(doc, "使用全屏半透明遮罩与居中面板；遮罩 `MOUSE_FILTER_STOP`，阻止底层点击。")
    add_bullet(doc, "最小面板宽度适配 720×1280 逻辑画布和 1080×1920 竖屏；文本不依赖缩放后的自绘小字号。")
    add_bullet(doc, "资源、卡牌、操作均使用 OptionButton；数值使用真实 LineEdit，数字键盘类型、回车提交与全选可用。")
    add_bullet(doc, "不可执行时按钮禁用，同时保留可读原因；不能只靠颜色表达状态。")
    add_bullet(doc, "成功反馈绿色，错误反馈红色，顶部持续显示“仅限 Debug / 会话本地”。")
    add_bullet(doc, "UI 不新增贴图、图标、动画或音效，避免调试工具影响游戏美术与音频资源。")

    doc.add_heading("10. 相关需求", level=1)
    add_table(
        doc,
        ["类型", "需求", "结论"],
        [
            ["美术", "新资产", "无；使用 Godot Control、Theme 与纯色样式"],
            ["音效", "打开/成功/失败音", "无；内部工具保持静默"],
            ["埋点", "记录 GM 操作", "无；不进入玩家分析系统"],
            ["服务端", "资源发放接口", "禁止；本功能不接后台和账号服务"],
            ["隐私/安全", "凭据与账号数据", "不读取、不显示、不存储管理员凭据；登录账号资源只读"],
            ["输入", "F2 / Escape / LineEdit", "主应用高优先级输入 + Modal 消费"],
        ],
        [1.1, 2.1, 3.75],
    )

    doc.add_heading("11. 关联拓展", level=1)
    add_bullet(doc, "后续如需生命、胜负、地图或技能调试，应先新增独立规则 ID、上下文门禁和测试，不得绕过资源事务入口。")
    add_bullet(doc, "若未来要求云端正式发放，必须另立功能，使用阿里云授权环境、后台审计、权限模型、幂等事务和回滚；不得复用本地 GM 路径。")
    add_bullet(doc, "若未来要求移动端测试入口，必须由制作人另行决定可发现性、手势、包渠道和防泄漏门禁。")

    doc.add_heading("12. 验收与 QA", level=1)
    doc.add_heading("12.1 交付验收", level=2)
    add_table(
        doc,
        ["ID", "验收项", "证据", "通过标准"],
        [
            ["GM-QA-01", "F2 生命周期", "test_runtime_gm_panel.gd", "首次创建唯一实例；F2/Escape/关闭均正确"],
            ["GM-QA-02", "资源事务", "test_gm_resource_rules.gd", "三种操作、四类资源、上下界与非法输入全覆盖"],
            ["GM-QA-03", "线上隔离", "规则 + 运行时测试", "在线比赛打不开；登录账号资源不可写；无 save/grant 调用"],
            ["GM-QA-04", "发行隔离", "规则测试 + 工程检查", "debug=false 时不可用，Release 不实例化"],
            ["GM-QA-05", "输入不穿透", "运行时输入测试", "Modal 可见时鼠标/触摸/键盘不触发底层操作"],
            ["GM-QA-06", "玩家可见证据", "1080×1920 PNG", "真实 MainApp 运行路径中面板完整、清晰、无裁切"],
            ["GM-QA-07", "工程健康", "Godot 4.6.3 + 回归", "无解析/缩进错误；经典战斗、账号与房间核心测试通过"],
            ["GM-QA-08", "文档", "DOCX 全页 PNG", "无模板提示、重叠、裁切或孤行；交付仅 DOCX"],
        ],
        [0.85, 1.7, 1.85, 2.7],
    )
    doc.add_heading("12.2 必测用例", level=2)
    add_table(
        doc,
        ["场景", "步骤", "预期"],
        [
            ["本地金币增加", "进入经典战斗；F2；金币/增加/100；执行", "金币 +100，当前值和成功反馈刷新"],
            ["金币扣到下限", "金币/减少/999999；执行", "结果为 0，不出现负数"],
            ["游客券设值", "未登录；抽卡券/设为/25；执行", "当前进程变为 25，不发送服务器保存"],
            ["卡牌数量", "选择卡牌；数量/增加/3", "该 card_id 数量 +3，其余卡牌不变"],
            ["卡牌等级", "选择卡牌；等级/设为/99", "等级夹取到 10"],
            ["登录保护", "设置 current_user_id；尝试券/卡牌修改", "按钮禁用或执行拒绝，数据不变"],
            ["在线保护", "激活 online_match_id；按 F2", "面板不打开，出现禁止提示"],
            ["非法输入", "输入空、小数、负数、字母", "均失败，资源不变，原因可读"],
            ["关闭与焦点", "LineEdit 聚焦时 F2/Escape/关闭", "面板关闭，焦点释放，底层没有误操作"],
        ],
        [1.45, 3.15, 2.5],
    )
    doc.add_heading("12.3 待确认与评审记录", level=2)
    add_table(
        doc,
        ["问题 / 决策", "状态", "责任人", "结论与影响"],
        [
            ["是否允许线上账号资源修改", "已决策", "制作人 / 工程", "否；使用正式后台发放系统，GM 保持本地隔离"],
            ["是否进入 Android Release", "已决策", "制作人 / 工程", "否；`OS.is_debug_build()` 硬门禁"],
            ["是否需要生产 Penpot 页面", "不适用", "制作人 / UI", "内部工具不进入玩家 UE；以状态表和运行时截图验收"],
            ["是否保存游客 GM 修改", "已决策", "制作人 / 工程", "v1.0 仅当前进程；持久化另立需求"],
        ],
        [2.4, 0.9, 1.2, 2.65],
    )
    return doc


def main() -> None:
    document = build_document()
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    document.save(OUTPUT)
    print(OUTPUT)


if __name__ == "__main__":
    main()
