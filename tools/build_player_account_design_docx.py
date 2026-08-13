from pathlib import Path

from docx import Document
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn
from docx.shared import Inches, Pt, RGBColor


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs" / "PLAYER_ACCOUNT_AND_SERVER_PROFILE_DESIGN_v1.4.docx"


def set_font(run, size=11, bold=False, color="20252B"):
    run.font.name = "Microsoft YaHei"
    fonts = run._element.get_or_add_rPr().rFonts
    for key in ("ascii", "hAnsi", "eastAsia"):
        fonts.set(qn(f"w:{key}"), "Microsoft YaHei")
    run.font.size = Pt(size)
    run.bold = bold
    run.font.color.rgb = RGBColor.from_string(color)


doc = Document()
section = doc.sections[0]
section.page_width = Inches(8.5)
section.page_height = Inches(11)
section.top_margin = section.bottom_margin = Inches(1)
section.left_margin = section.right_margin = Inches(1)
section.header_distance = section.footer_distance = Inches(0.492)

normal = doc.styles["Normal"]
normal.font.name = "Microsoft YaHei"
normal._element.rPr.rFonts.set(qn("w:eastAsia"), "Microsoft YaHei")
normal.font.size = Pt(11)
normal.paragraph_format.space_after = Pt(6)
normal.paragraph_format.line_spacing = 1.1
for name, size, before, after in [("Heading 1", 16, 16, 8), ("Heading 2", 13, 12, 6)]:
    style = doc.styles[name]
    style.font.name = "Microsoft YaHei"
    style._element.rPr.rFonts.set(qn("w:eastAsia"), "Microsoft YaHei")
    style.font.size = Pt(size)
    style.font.bold = True
    style.font.color.rgb = RGBColor(46, 116, 181)
    style.paragraph_format.space_before = Pt(before)
    style.paragraph_format.space_after = Pt(after)

list_style = doc.styles["List Bullet"]
list_style.font.name = "Microsoft YaHei"
list_style._element.rPr.rFonts.set(qn("w:eastAsia"), "Microsoft YaHei")
list_style.paragraph_format.left_indent = Inches(0.5)
list_style.paragraph_format.first_line_indent = Inches(-0.25)
list_style.paragraph_format.space_after = Pt(8)
list_style.paragraph_format.line_spacing = 1.167

header = section.header.paragraphs[0]
header.text = "战城大师 · 功能规格"
set_font(header.runs[0], 9, color="6B7280")
footer = section.footer.paragraphs[0]
footer.alignment = WD_ALIGN_PARAGRAPH.RIGHT
footer.text = "v1.4 · 2026-08-13"
set_font(footer.runs[0], 9, color="6B7280")

title = doc.add_paragraph()
title.paragraph_format.space_after = Pt(4)
set_font(title.add_run("玩家账号与服务器资料设计"), 23, True, "111827")
subtitle = doc.add_paragraph()
subtitle.paragraph_format.space_after = Pt(16)
set_font(subtitle.add_run("跨安装账号密码登录、安全凭据查看与服务端权威进度"), 13, color="4B5563")

sections = [
    ("1. 目标", [
        "每名玩家拥有服务器生成且不可修改的 UserID；卡牌数量、卡牌星级、出战编组、抽卡券、段位星数与 ELO 均以服务器资料为权威。",
        "本机已有长期令牌时，游戏启动进入大厅后自动联网恢复同一账号，不依赖点击中央基地，也不读取 MAC、硬盘序列号或其他物理地址。",
        "受支持的 Windows 与 Android 客户端可在不同安装上使用同一命名账号和密码登录，并恢复同一 UserID 与服务器资料。Web 浏览器与 iOS 在完成独立传输适配及真机验收前不纳入支持声明。",
    ]),
    ("2. 默认设备账号流程", [
        "客户端首次启动生成 32 字节随机安装 ID，并保存到 user://client/device_account.json。",
        "首次连接时服务器创建游客账号和 UserID，仅在首次响应中签发 32 字节随机长期登录令牌。",
        "后续启动使用安装 ID 与长期令牌自动连接并登录；服务器再签发仅用于当前连接的短期会话令牌。",
        "账号密码手动登录成功后，服务器校验当前安装 ID，把该账号加入本机档案集合并设为当前档案；新安装得到独立长期令牌，同一账号仍指向同一 UserID 与资料。",
        "登录响应返回账号名、UserID 和“已设置密码”状态，但绝不返回密码、盐或密码派生值。",
    ]),
    ("3. 本机账号切换", [
        "一个安装最多拥有 8 个独立服务器档案；账号列表只返回当前安装凭据所属档案的 UserID、段位、星数和动物总数量。",
        "账号中心用“切换账号”替代“注销账号”；切换时服务器撤销旧短会话，签发新短会话并同步所选档案资料。",
        "列表底部的黄色“新建账号”创建全新服务器档案，发放新手动物、基础建筑、10 张抽卡券和青铜 1 星资料。",
        "账号密码手动登录成功后，该账号加入当前安装的可切换集合并成为当前档案；账号列表可显示命名账号，游客档案明确标为未绑定。",
    ]),
    ("4. 安全边界", [
        "服务器只保存安装 ID 的 SHA-256 摘要、随机盐和长期令牌哈希，不保存安装 ID 或令牌明文。",
        "客户端只在 user:// 保存随机安装 ID 与随机长期令牌，不保存账号密码；长期令牌错误时服务器统一拒绝认证。服务器账号记录只保存随机盐与单向密码派生值，历史明文密码不可恢复。",
        "网络 peer 只能读写其当前会话对应的玩家资料；断线与切换都会解除旧 peer 到用户的映射。",
        "账号中心只可临时查看本次手动登录时玩家刚输入的密码：默认遮罩，点击查看后短时显示；应用失焦、进入后台、断线、切换账号或进程退出立即清空。自动登录只显示账号名和“密码已设置”，不能显示旧密码。",
        "删除应用数据或丢失本机凭据会失去自动登录能力；正式发行前需补充安全改密、可信找回、登录限速、令牌撤销及版本化密码 KDF。",
        "公网注册和口令登录必须使用校验证书的加密认证通道。当前普通 ENet UDP 口令 RPC 只能作为开发阶段能力，不能通过正式发行安全门禁。",
    ]),
    ("5. 分段获胜阵容", [
        "每次段位赛获胜后，按开局时所在分段记录获胜者的 8 张卡组、卡牌等级、星数、UserID 和记录时间。",
        "本地记录保存在 user://rank_mirror_db.json，并通过 rank_mirrors 字段同步到玩家服务器资料。",
        "服务端每个分段最多保留 15 条记录，卡组最多 8 张；无效类型、空卡牌和超量数据会被过滤。",
        "服务器暂无记录时不以空数据覆盖本机历史记录，客户端会在下一次资料同步时补传。",
    ]),
    ("6. 页面入口", [
        "账号与密码输入使用引擎原生 LineEdit，支持鼠标、触摸、移动端软键盘、密码键盘类型、提交键和失焦隐藏键盘。",
        "手动登录后账号中心显示账号名、UserID、同步状态和遮罩密码。只有当前前台会话仍持有本次输入时，“查看”按钮才可短时显示；否则提示重新登录验证。",
        "主页面点击基地仅打开账号中心，不再负责触发自动登录；可切换或新建档案、阅读玩家协议并切换音乐与音效。",
    ]),
    ("7. 验收", [
        "全新安装首次连接后得到 UserID、长期令牌和默认服务器资料；已有长期令牌时启动客户端无需点击基地便自动恢复账号。",
        "两个不同安装用同一账号密码登录后得到相同 UserID 和服务器资料，各自长期令牌彼此独立且不可交叉使用。",
        "账号密码手动登录后重启客户端，自动登录到同一 UserID，并显示账号名；本地凭据文件、服务端响应和日志均不包含明文密码。",
        "本次输入的密码默认遮罩，可短时查看；应用失焦、进入后台、断线或切换账号后无法继续查看。自动登录从不提供旧密码。",
        "同一安装可列出并切换全部所属档案；新建档案和切换档案不会混用旧档案资料。",
        "服务器重启后，同一安装 ID 与长期令牌登录到相同 UserID，且长期令牌不会再次返回。",
        "不同安装获得不同 UserID；伪造安装 ID、错误令牌及未认证资料写入均被拒绝。",
        "分段获胜阵容在服务器重启和同账号换设备后仍可恢复，且服务器只保留规范化后的卡组数据。",
        "Windows 鼠标键盘与 Android 触摸软键盘均能聚焦账号/密码框、输入、切换遮罩并提交。",
        "账号存储测试、跨安装身份回归、账号凭据 UI 回归和 Godot 全项目解析通过。",
    ]),
    ("8. 发布门禁", [
        "阿里云 staging 或 production 的部署档案必须包含目标、域名端口、TLS、健康检查、备份、回滚、监控与负责人，并获得明确远程写授权。缺失时状态为 NOT READY: Aliyun deployment profile。",
        "正式完成必须由 Windows 与 Android 导出包经外网连接阿里云测试环境，完成相同账号双向登录、资料恢复、抓包无明文口令、服务重启持久化和回滚验证。",
        "客户端整包覆盖资料且无 revision 的并发冲突与可信度问题属于 P0 服务端改造项；在服务器权威命令化或版本冲突控制完成前，不宣称多设备并发存档达到生产标准。",
    ]),
]

for heading, items in sections:
    doc.add_heading(heading, level=1)
    for item in items:
        paragraph = doc.add_paragraph(style="List Bullet")
        set_font(paragraph.add_run(item))

doc.core_properties.title = "玩家账号与服务器资料设计"
doc.core_properties.subject = "跨安装账号登录、安全凭据查看与服务端权威资料规格"
doc.core_properties.author = "Codex Game Studio"
doc.save(OUT)
print(OUT)
