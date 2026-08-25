# REQ-20260825-ACCOUNT-AVATAR-GM-UX 关闭回执

- 日期：2026-08-25
- 功能：F-ZC-AUTH-001 v2.1；F-ZC-GM-001 v1.1
- 制作人：user-producer
- 执行与写入负责人：codex-primary
- 状态：`COMPLETE / LOCAL_IMPLEMENTATION_VALIDATED`
- 任务指纹：`F99B52E2D27687601CC40EC426CA850AFEF37DDE9520455CFEE0C7AEEAFC3518`
- 分支：`codex/animal-art-integration-20260811`
- 起始 HEAD / 上游：`8aeac3763de076410d154561a7c19a0ac5fc593e`

## 完成结果

1. 头像目录不再写死为 12 项；由 `runtime/config/cards.json` 生成全部 60 个动物头像，保持 common 10、rare 9、epic 21、legendary 20 的品质数据和原动物美术路径。
2. 当前头像和头像选择页均显示中文品质及对应边框。头像页明确区分已选、可用、锁定三态，不只靠颜色表达。
3. 未拥有对应动物卡的头像仍展示但锁定；点击锁定项时，弹窗底部固定显示“获得【动物名】动物卡后解锁，可通过抽卡获得”。
4. 点击账号中心当前头像位置打开独立、可滚动、鼠标/触摸可操作的头像选择页。720×1280 为 4 列，540×960 为 3 列，1280×720 为 6 列。
5. 客户端选择前检查 `card_counts[card_id] > 0`；服务器 `PlayerAccountStore.update_identity` 使用同一动物白名单和当前权威 profile 再次校验，未拥有返回 `avatar_locked`。旧账号当前已装备头像保持可保存，避免强制重置。
6. 删除“复制账号”“复制密码”“复制全部”三个方法、按钮和热区，只保留一个文案为“复制”的按钮；一次复制 `账号ID + 换行 + 密码`。没有当前前台密码时打开重新登录，不读取服务器或磁盘中的旧明文。
7. GM 面板移除超出 720 视口的固定 760 最小宽度；面板按实际 viewport 计算安全边距、宽高，标题/F2/关闭固定，正文进入 `ScrollContainer`。原 Debug、互联网对战禁用、登录账号保护和会话本地规则未改变。

## 玩家可见证据

三张证据均由 Godot 4.6.3 正式运行场景、Vulkan Forward+、NVIDIA GeForce RTX 4060 Laptop GPU 生成；均为 720×1280 PNG，并已人工逐张检查。

| 证据 | SHA-256 | 验收结论 |
|---|---|---|
| `output/qa/F-ZC-AUTH-001/account_center_v2_1.png` | `D95EF2A4CE6AE0D247810F434D15641CC9EB3C8135E7D8992F35D7245C54D482` | 当前头像显示“传说”品质；点击更换入口、用户名输入、单一“复制”、密码查看、保存和底部操作无重叠 |
| `output/qa/F-ZC-AUTH-001/account_avatar_picker_v2_1.png` | `F5924AEEF1E3BA3CC666BE9E136ACFB5424EC0D38B7356B2ADEF0B37262E0F66` | 显示 60/60、已解锁/锁定计数、品质、锁定遮罩、滚动条，以及点击锁定老鼠后的具体抽卡获得提示 |
| `output/qa/F-ZC-GM-001/runtime_gm_panel_720x1280_v1_1.png` | `4AC4DC2890AD3ECD23F2F006AD73FC5B1BD188952882BFCFA4A84B436A37E492` | 面板完整位于视口，标题和关闭固定，无水平裁切，资源表单及执行按钮可达 |

## 正式文档

- `docs/PLAYER_ACCOUNT_IDENTITY_AVATAR_DESIGN_v2.1.docx`：1,968,457 bytes；SHA-256 `DCAB6E3470DDB9684B923326D153FDE33AD149F51B4C25186913EACFF89C1256`；Word/Poppler 渲染 11 页，逐页无裁切、重叠、断表或模板残留。
- `docs/RUNTIME_GM_PANEL_DESIGN_v1.1.docx`：39,827 bytes；SHA-256 `B750CC97469B95AF99408A9E8C1FB6B62D55A3B5713966026AB2803B9B372F33`；Word/Poppler 渲染 8 页，逐页无裁切、重叠、断表或模板残留。
- 两份临时 PDF 仅用于本机 Word 渲染回退，位于系统 Temp、未进入项目和交付物；执行环境策略拒绝删除命令，因此不把其清理状态冒充为完成。

## 自动化与工程门禁

- `tools/check_gd_indentation.py`：PASS，tab indentation 2。
- `git diff --check`：PASS（仅有 `docs/active_scope.yaml` 的 CRLF 提示，无 whitespace error）。
- 独立 `--check-only`：共享头像规则、账号存储、OnlineRoom、头像弹窗、GM 面板 5/5 PASS；`main.gd` 由带 Autoload 的真实项目测试场景解析 PASS。
- 核心行为：`test_account_identity_v2`、`test_account_avatar_picker`、`test_account_manual_login_entry`、`test_runtime_gm_panel` 4/4 PASS。
- 组合回归：上述 4 项加 `test_account_password_login_loop`、`test_auto_generated_account_credentials`、`test_device_account_credentials`、`test_player_account_store`、`test_gm_resource_rules`、`test_desktop_window_fit`，10/10 PASS。
- GM 实际布局测试：720×1280、540×960、1280×720 面板均在 viewport 内；横屏正文滚动条实际溢出可滚动。
- 配置不变：`git diff --exit-code -- config/tables runtime/config` PASS；未触发 CSV 导出链。
- Godot 退出警告经 `--verbose` 定位为既有 `GameAudio` Autoload 的 `AudioStreamWAV/AudioStreamPlaybackWAV`，目标测试退出码均为 0；本任务未改音频生命周期。

## 边界与未执行项

- 未修改用户已有的 `design/战斗数值.xlsx` 和其他无关未跟踪文件。
- 未关闭、重启或覆盖用户正在运行的 Godot 编辑器/游戏进程。
- Android 真机：`not_run`。
- APK：`not_requested / not_run`。
- 阿里云、生产账号数据、远程服务：`not_authorized / not_run`。
- 生产认证安全门（现代 KDF、TLS、限速、恢复与撤销）仍沿用 F-ZC-AUTH-001 既有未完成门禁；本任务没有扩大其完成状态。

## 关闭条件

- 本任务共享写锁在代码、行为测试、分辨率测试、玩家可见截图、DOCX 全页检查和配置不变检查完成后释放。
- 最终 RAG `prepare + pack` 与控制面检查在本关闭回执和 active scope 入库后重新执行；Git 提交由包含本回执的同一提交承载。
