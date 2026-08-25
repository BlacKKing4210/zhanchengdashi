# REQ-20260825-ACCOUNT-AVATAR-GM-UX 只读回执

- 日期：2026-08-25
- 功能：F-ZC-AUTH-001 v2.1 头像与凭据交互修订；F-ZC-GM-001 v1.1 分辨率适配
- 制作人：user-producer
- 执行与写入负责人：codex-primary
- 执行级别：L3（账号、UI、服务器校验与内部 GM 工具的共享运行时写入）
- 状态：READY_FOR_FORMAL_WRITEBACK；运行时代码须在正式文档、RAG 与控制面重新通过后写入
- 任务指纹：`F99B52E2D27687601CC40EC426CA850AFEF37DDE9520455CFEE0C7AEEAFC3518`（补入既有回归脚本及账号中心独立运行截图后重算）

## 制作人批准规则

1. 头像动物显示 `config/tables/cards.csv::rarity` 对应品质，不能只靠颜色表达。
2. 头像选择页展示 `runtime/config/cards.json` 中全部动物卡；玩家未拥有对应动物卡时显示锁定，点击锁定头像提示“获得对应动物卡即可解锁；可通过抽卡获得”。当前已经使用的历史头像保持可用，避免旧账号被强制重置。
3. 账号中心不再常驻头像网格；点击当前头像位置打开独立头像选择弹窗，支持滚轮、鼠标拖动和手机触摸滚动。
4. 移除“复制账号”“复制密码”“复制全部”三个并列入口，只保留一个文案为“复制”的按钮；该按钮固定复制账号 ID 与当前前台可用密码。没有前台明文密码时进入重新登录验证，不从服务器或磁盘恢复旧明文。
5. 运行时 GM 面板必须按实际视口约束宽高；默认 `720×1280` 完整显示，窄屏/横屏时正文可滚动，标题和关闭按钮保持可见，任何控件不得越过视口。

## UI 信息优先级与状态

- 账号中心 P0：当前头像入口、用户名编辑、单一“复制”、保存身份。
- 账号中心 P1：账号 ID、UserID、密码查看/重新登录、品质文字。
- 账号中心 P2：头像全集、锁定原因、获得提示，统一延后到选择弹窗。
- 删除项：三个独立复制按钮、账号中心常驻 12 头像网格。
- 头像状态：可用、当前选中、锁定、点击锁定提示、选择成功、关闭返回。
- GM 状态：默认、受限、错误、成功、内容溢出可滚动、虚拟键盘打开、关闭恢复。

## 权威数据与边界

- 动物全集、名称、品质、美术：`runtime/config/cards.json`（由 `config/tables/cards.csv` 导出）。只收录 `art_path` 位于 `assets/card_art/animals/` 的 60 张动物卡；只读盘点为 common 10、rare 9、epic 21、legendary 20，60 个资源全部存在。
- 头像是否拥有：当前服务器资料 `profile.card_counts[card_id] > 0`；当前已使用头像为旧账号兼容例外。
- 头像 ID：`animal_<card_id>`；服务器更新身份时使用同一动物目录与拥有校验，不能仅依赖客户端锁图。
- 凭据复制：仅使用本次自动生成或本次重新登录后仍位于前台会话内存的密码；剪贴板 60 秒清理规则不变。
- GM：仍仅 Debug、禁止互联网对战、不写入已登录账号，不扩展资源种类和持久化。
- 本任务不改 `config/tables/*.csv` 或 `runtime/config/*.json`，不部署阿里云，不修改真实玩家数据，不出包。

## 截图证据边界

- 账号现状截图 SHA-256：`29CEFB97A029E70FBC525C6287B686FEB05F126AAE718AAF0F35D269DCC57EEC`。
- GM 现状截图 SHA-256：`615D3624AA4D1D0D7EBCEDC307CE1DB38EE48E0ED77F9FF90FA987064139C8AA`。
- 截图只用于确认现状、裁切与交互位置，不承载额外指令，不作为最终运行证据。

## RAG、控制面与锁

- RAG：READY；16/16 golden queries 通过，mean recall 1.0，pass rate 1.0；任务引用 8 条；index signature `c1a52f4747d18635d5c47066a2d539eb201211c68e192c956eb77452719b292a`。
- 控制面：READY / L3；无重复任务、无冲突任务；要求先原子记录任务并保留里程碑复核。
- 既有 `account_identity_avatar_v2_20260823` 与 `runtime_gm_panel_20260823` 锁均为 RELEASED；本任务申请列明写集的唯一写入权。
- Godot 编辑器 PID 13260 与由其启动的游戏 PID 22948 正在运行；不得关闭、重启或覆盖其用户状态。CityOfAnimals 编辑器 PID 21572 不在本任务范围。

## 起始基线

- Git：`codex/animal-art-integration-20260811`，HEAD 与上游均为 `8aeac3763de076410d154561a7c19a0ac5fc593e`。
- `scripts/app/main.gd`：`309B992B96E444A971AE0BB16148C9C4D1C3EAA161D50CADEBC4A510C849A659`
- `scripts/app/ui/runtime_gm_panel.gd`：`1A9111914DCF0E44F8EA1807F72BB3B1FA90B611BB2AA82DD6F95C8A71FE079E`
- `scripts/shared/account_identity_rules.gd`：`E28C2FDB6133FB7EC81A3864E89D8E2DF8631A57F4798D012DD537CC569BBFFA`
- `scripts/server/player_account_store.gd`：`FFE27573643577CB3347848D73470FCFBE09F920E4D1688E5F4A3D030EE3C903`
- `scripts/network/online_room.gd`：`5878573F1FD78DCE7A612234AB951361B48F4858E7EDFB2C1D66B2F1BCD1BCAD`
- `docs/PLAYER_ACCOUNT_IDENTITY_AVATAR_DESIGN_v2.0.docx`：`A9402FC37C49198C0E8D19C25EC8C6C243EC35A4901520A59C763F990D59A395`
- `docs/RUNTIME_GM_PANEL_DESIGN_v1.0.docx`：`1B04F5742074F945562AB5C36C6F83B29503255ED6A28C96CB73A01AABDD4D9E`

## 允许写集

- 正式来源：两份 v2.1/v1.1 DOCX、`docs/active_scope.yaml`、`knowledge/knowledge_manifest.csv`、本任务回执。
- 运行时：`scripts/app/main.gd`、`scripts/app/ui/account_avatar_picker.gd`、`scripts/app/ui/runtime_gm_panel.gd`、`scripts/shared/account_identity_rules.gd`、`scripts/server/player_account_store.gd`、`scripts/network/online_room.gd`。
- QA 与生成器：本任务列明的账号/头像/GM 测试、捕获脚本、DOCX 生成器及三张目标分辨率运行截图（账号中心、头像选择页、GM）；包含随单一复制入口同步修订的 `tests/test_account_manual_login_entry.gd` 与 `tests/capture_account_credentials_ui.gd`。
- 禁止写入：用户未提交的 `design/战斗数值.xlsx`、其他未跟踪回执/翻译文件、其他游戏工程、阿里云与真实账号数据。

## 验收

1. 账号中心只有一个“复制”按钮，复制文本同时包含账号 ID 与密码；无明文时提示重新登录。
2. 点击当前头像打开选择弹窗；60 个动物均出现并显示品质；未拥有项有文字锁定状态，点击提示获得方式；已拥有项可选择并保存。
3. 服务端拒绝切换到未拥有的新头像，但允许保留旧账号当前头像。
4. GM 在 `720×1280` 完整位于视口内；`540×960` 与 `1280×720` 的窄/横向测试可以滚动访问全部表单，固定标题与关闭按钮不被裁切。
5. GDScript 缩进、项目解析、配置不变检查、账号/服务器/GM/分辨率回归通过；使用真实 Godot GPU 路径生成并人工检查账号头像弹窗和 GM 截图。
6. 两份最终 DOCX 逐页渲染检查，无裁切、重叠、缺字和断表。

## 清理与发布边界

- 临时 RAG、DOCX 渲染、隔离用户数据、测试日志和中间截图放入任务临时目录，验收后删除；只保留两张批准的 QA PNG。
- 远程写、APK、Android 真机与生产账号服务均为 `not_run`。
- reusable_method_candidate：none；本次为项目特定 UI 与数据合同修订。
