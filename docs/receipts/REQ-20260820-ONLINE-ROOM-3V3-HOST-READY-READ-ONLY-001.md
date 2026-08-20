# REQ-20260820-ONLINE-ROOM-3V3-HOST-READY-002 只读开工回执

- 状态：`READY_FOR_IMPLEMENTATION_AND_ANDROID_PACKAGE`
- 记录时间：2026-08-20（Asia/Hong_Kong）
- 责任人：`engineering_owner / codex-primary`
- 分支：`codex/animal-art-integration-20260811`
- 基线提交：`8b2161a6676a119899644928dffdf687e43dc343`
- 任务指纹：`33025EB05D63F9314AB99C87BB8B50BD71FD7C260E81ACB592A41505595570FA`
- 控制面：`READY / L3 / activate_role_owner`；按项目规则由当前责任人执行，不创建新代理或新任务。
- RAG：`READY`；64 个来源、887 个分块、8 条请求引用；索引签名 `8d7335c90fe33d90d538c464d10efb3b076c8ddf6db80f72fb462ad06e8fbcb6`；任务回执 `temp/rag/receipts/tasks/REQ-20260820-ONLINE-ROOM-3V3-HOST-READY-002.json`。
- 需求证据：制作人消息及截图 `codex-clipboard-f48a24e7-09a0-44fd-a5ec-4256e9e5ea2d.png`，截图 SHA-256 `9917C49DB07FE75174438B59BA73077F2F6F1B52E4DA6D1E248D41410FCB7044`。

## 只读诊断

1. 当前正式规格 `docs/INTERNET_ROOM_NETWORKING.md` v1.7 已规定：房主隐式准备，所有非房主真人准备后，房主点击“开始”进入游戏。
2. 基线源码 `scripts/network/room_registry.gd` 已将房主写为准备，并在开局门禁中排除房主；本次不修改服务端规则。
3. 用户截图仍显示已从当前客户端源码删除的独立“等待其他真人玩家准备”面板，证明截图至少来自旧客户端。
4. 当前目录中最新 Android APK 的构建时间为 2026-08-15 前，早于基线提交 `8b2161a`；不能把这些历史 APK 当作本次修复包。
5. 未获授权读取或修改公网服务端运行版本，因此不能把截图直接当作服务端版本证据。为兼容仍返回“房主未准备 / can_start=false”的旧服务端快照，新客户端将以房主身份和有效槽位为准计算开局条件，并在必要时通过 ENet 可靠有序通道 0 先发送 `set_ready(true)`、随后发送 `start_room()`。

## 非冲突写入范围

- `docs/INTERNET_ROOM_NETWORKING.md`
- `scripts/app/main.gd`
- `tests/test_online_main_adapter.gd`
- `output/qa/REQ-20260820-online-room-3v3-host-ready/host-ready-legacy-server.png`
- `build/android/JungleLaw-android-2026-08-20-3v3-host-ready-r1.apk`
- 本任务开工与关闭回执

并行任务 `REQ-20260820-ADMIN-DASHBOARD-ALIYUN-PUBLIC-007` 持有后台、部署、`docs/active_scope.yaml` 与 `knowledge/knowledge_manifest.csv` 写锁；本任务不写这些文件。工作树中其他既有修改全部视为用户或其他任务所有，不纳入本任务暂存、提交或清理。

## 基线 SHA-256

| 文件 | SHA-256 |
|---|---|
| `docs/INTERNET_ROOM_NETWORKING.md` | `27B89E178F25229B2331A7B60B2A4CD01D7D621FA76B96EF7DBF8348E703B970` |
| `scripts/app/main.gd` | `D70BDAB6FA4840F6DAC7AF37006966DCE04E91B04CBE3C3205CEDC77B8A73483` |
| `tests/test_online_main_adapter.gd` | `5D9F60ACFCB8614B453D49C401BC38C579883C2B91F099890DB1465797518C4D` |

## 验收条件

1. 3V3 房主槽位即使收到旧服务端的 `ready=false` 也按已准备视觉状态显示，不出现“未准备”语义。
2. 六个有效槽位已占用且五名非房主真人均准备时，即使旧快照仍为 `can_start=false`，“开始”也可点击。
3. 兼容路径按顺序只发送一次 `set_ready(true)` 和一次 `start_room()`；当前新服务端快照路径不额外发送房主准备请求。
4. 任一有效槽位为空或任一非房主真人未准备时，“开始”仍不可用。
5. GDScript 缩进、主流程适配、房间注册表、真实 ENet、六真人 3V3、房间码和战斗回环回归通过。
6. 导出新的唯一命名 Android APK，校验包结构、签名、版本/构建时间和 SHA-256；不得覆盖或交付历史 APK。
7. 保存 720×1280 图形运行截图并目视确认房主槽位与“开始”状态；Android 实机点击仍需制作人在手机安装后最终确认。

## 非目标

- 不部署、重启或修改阿里云公网服务端。
- 不修改账号、战斗、地图、队伍、补位和其他房间规则。
- 不触碰并行后台部署任务持有的文件与远程环境。
