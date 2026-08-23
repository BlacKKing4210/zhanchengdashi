# REQ-20260823-ACCOUNT-IDENTITY-AVATAR-V2-001 关闭回执

- 功能：F-ZC-AUTH-001 玩家账号、用户名与头像系统 v2.0
- 日期：2026-08-23
- 负责人：codex-primary
- 本地实施状态：COMPLETE
- 发布状态：LOCAL_IMPLEMENTATION_VALIDATED；人物头像、FigJam 和生产安全门保持独立待验收
- 远程写状态：NOT AUTHORIZED；本任务未读取或修改阿里云真实玩家账号

## 本次完成

1. 账号身份拆分为不可变 `user_id`、唯一稳定登录 `account`、允许重名且可修改的 `username`、预设 `avatar_id`、并发 `identity_revision` 和首次设置 `identity_complete`。
2. 自动设备账号保留低摩擦进入；玩家只需确认用户名与头像即可完成首次身份设置。手动路径继续使用账号 ID + 密码直接注册或登录，用户名不能作为登录键。
3. 服务端新增身份更新、运行时头像白名单、revision 冲突保护和旧账号逐字段迁移；旧记录的 UserID、资料、密码派生值与安装绑定不被重置。
4. 账号中心显示头像、用户名、账号 ID、UserID 和身份编辑；提供“复制账号”“复制密码”“复制全部”三个入口。历史明文密码不会从服务器或磁盘恢复。
5. 首版运行时接入 12 个既有动物头像；账号中心、账号切换和房间显示统一优先使用服务器权威用户名。
6. 产出 4 个原创通用人物头像的 2×2 整套评审板。整板未切图、未去底、未进入运行时，也未加入服务器白名单。

## 验收结果

| 验收项 | 结果 | 证据 |
|---|---|---|
| GDScript 缩进 | PASS | `tools/check_gd_indentation.py`：tab 2 |
| Godot 项目解析 | PASS | Godot 4.6.2，`--headless --path . --quit-after 3`，退出码 0，无解析错误 |
| 新身份合同 | PASS | `tests/test_account_identity_v2.tscn`：默认身份、重复用户名、登录键分离、非法输入、头像白名单、revision 冲突、旧记录迁移 |
| 账号存储与登录回归 | PASS | `test_player_account_store`、`test_account_manual_login_entry`、`test_account_password_login_loop`、`test_saved_account_auto_login`、`test_device_account_credentials` |
| 联机与房间名字回归 | PASS | `test_online_main_adapter`、`test_online_room_gameplay_loopback`、`test_online_room_six_client_loopback` |
| 玩家可见画面 | PASS | `output/qa/F-ZC-AUTH-001/account_identity_v2.png`；用户名、12 个动物头像、账号 ID、UserID 和三个复制按钮均可见；SHA-256 `DADDFE133B26821EF04EAD711233102A1F9071522477FE18C15B3EEB4872886E` |
| 正式 DOCX | PASS | 9 页全部渲染检查；目录已更新、人物整板已嵌入、无多余空白页；SHA-256 `A9402FC37C49198C0E8D19C25EC8C6C243EC35A4901520A59C763F990D59A395` |
| 进度工作簿 | PASS | F-ZC-AUTH-001 已加入 Nine Dimensions；公式错误扫描 0 项，五个工作表全部渲染检查；SHA-256 `7B0FF29FFF7BDBEEE881C64D551A4C518E5FC0481FB14EA244B51B315D52ACFB` |
| 人物头像整板 | REVIEW ONLY | `output/visual_concepts/account-avatar-v2/ACCOUNT_AVATAR_HUMAN_OPTIONS_BOARD_v1.png`；SHA-256 `4C5828588574E2842A34A7F47C9A8B181F115C9F1D60656D8B8DDF1CF1DDBC45`；状态 `NOT_RUNTIME_PENDING_PRODUCER_APPROVAL` |

测试退出时仍可见既有 ObjectDB / resource 残留警告；所有本次列明测试退出码均为 0，项目解析无脚本解析错误，未把警告隐藏或误报为新失败。

## 独立待验收门

- 人物头像：制作人书面批准整板后，才能原样切图、做透明边缘与缩略图 QA、生成运行时 `avatar_id` 并加入服务端白名单。
- 可编辑 UE：Figma/FigJam 连接器不可用，本次 DOCX 中的 UI/UE 章节是实现合同，不冒充最终可编辑 FigJam 源。
- 生产安全：现有 12000 轮 SHA-256 只保留旧记录兼容；正式公网账号服务仍需版本化现代 KDF、TLS、账号/IP/设备限速、恢复与撤销、抓包和渗透验收。
- 阿里云：没有本次远程变更授权；未部署、未迁移、未重启服务，也未触碰真实玩家账号数据。

## 关键产物

- `docs/PLAYER_ACCOUNT_IDENTITY_AVATAR_DESIGN_v2.0.docx`
- `PM/feature_progress.xlsx`
- `scripts/shared/account_identity_rules.gd`
- `scripts/server/player_account_store.gd`
- `scripts/network/online_room.gd`
- `scripts/app/main.gd`
- `tests/test_account_identity_v2.gd`
- `output/qa/F-ZC-AUTH-001/account_identity_v2.png`
- `output/visual_concepts/account-avatar-v2/ACCOUNT_AVATAR_HUMAN_OPTIONS_BOARD_v1.png`

最终 RAG 与控制面门禁记录位于 `temp/rag/receipts/rag-gate.json`、`temp/rag/receipts/tasks/REQ-20260823-ACCOUNT-IDENTITY-AVATAR-V2-001.json` 和 `temp/control/REQ-20260823-ACCOUNT-IDENTITY-AVATAR-V2-001.json`。

## 关闭结论

用户名、动物头像、简单注册登录、账号切换显示和独立凭据复制的本地功能已实现并通过定向回归、项目解析、玩家可见截图、DOCX 和工作簿验收。共享写锁可以释放。人物头像整板和生产发布安全属于明确保留的下一阶段门禁，不影响本地 v2.0 功能关闭，但在通过前不得宣称公网生产完成。
