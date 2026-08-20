# REQ-20260820-ONLINE-ROOM-READY-NAMES-001 只读开工回执

- 状态：`READY_FOR_IMPLEMENTATION`
- 记录时间：2026-08-20（Asia/Hong_Kong）
- 责任人：`engineering_owner / codex-primary`
- 分支：`codex/animal-art-integration-20260811`
- 基线提交：`2b1d22083d0c11e197169a7a954401d6a8cba4de`
- 任务指纹：`86AF78BBEA7160ECB63D2F850E7A832EC87700636DA9EF5741ACE75327C0B866`
- 控制面：`READY / L3 / activate_role_owner`；按项目规则由当前责任人执行，不创建新代理或新任务。
- RAG：`READY`；最终索引签名 `88192461d11ef60d501d4b410b9b20694157e011594744b059aef21a2e64f5cd`；任务回执 `temp/rag/receipts/tasks/REQ-20260820-ONLINE-ROOM-READY-NAMES-001.json`。
- 需求证据：制作人消息及截图 `codex-clipboard-930ae441-28fa-47aa-adb8-a13d0b3ce0cd.png`，截图 SHA-256 `4227AA25653C9BC537BC6F2C4C4BBAA508EA7F297EF51F1A1B04A0005EFEB378`。

## 正式规则

已先更新并登记 `docs/INTERNET_ROOM_NETWORKING.md` v1.7：房主隐式准备并在右侧显示“开始”；非房主在右侧显示“准备 / 取消准备”；“离开房间”固定在左侧；删除独立开始/等待控件及其上方随机地图提示；真人名称由服务器认证账号生成。

## 非冲突写入范围

- `docs/INTERNET_ROOM_NETWORKING.md`
- `knowledge/knowledge_manifest.csv`
- `scripts/app/main.gd`
- `scripts/network/online_room.gd`
- `scripts/network/room_registry.gd`
- `tests/test_online_main_adapter.gd`
- `tests/test_online_room_registry.gd`
- `tests/test_online_room_transport.gd`
- `tests/test_online_room_six_client_loopback.gd`
- `output/qa/REQ-20260820-online-room-ready-names/guest-ready.png`
- `output/qa/REQ-20260820-online-room-ready-names/host-start.png`
- 本任务开工与关闭回执

当前另有 `REQ-20260820-ADMIN-DASHBOARD-ALIYUN-PUBLIC-007` 持有后台、部署及 `docs/active_scope.yaml` 写锁；本任务不写这些文件，控制面检查未发现冲突。工作树中其他既有修改全部视为用户或其他任务所有，不纳入本任务暂存、提交或清理。

## 运行时代码基线 SHA-256

| 文件 | SHA-256 |
|---|---|
| `scripts/app/main.gd` | `0ADF712D25C7A87C30D992F6E4DB31B51D6F9F7877ACF55AC98FA908D146A88C` |
| `scripts/network/online_room.gd` | `FBB412DB5112997B7DB230F89CF739606636B2C548145B09CDCC0EDCC6BCB844` |
| `scripts/network/room_registry.gd` | `AA8E12C1AB22C4235CA8CFE1FDBEC1983F70A9DB765E3C78FC5EA0915FF13345` |
| `tests/test_online_main_adapter.gd` | `B06CE20168D69D424E19109900AE328BEE629CFB33E312F6A27067887AD0561E` |
| `tests/test_online_room_registry.gd` | `E6D2DCF6A94AC1ED40995B7C28EC1DE6433482D92786B1195853615A4728546F` |
| `tests/test_online_room_transport.gd` | `4CE35EFC7F0E9B149E5E9BE50F07CAA2F7BA71E3D0694A5C17583EBF6B0A8020` |
| `tests/test_online_room_six_client_loopback.gd` | `0B9E98258ED4A7E5EE9219E4C658161D8D5CA588C9382660F778F19388A90894` |

## 验收与清理条件

1. 非房主通过实际点击区域发出准备或取消准备 RPC；请求中显示同步反馈，服务器快照决定最终状态，失败后可重试。
2. 房主不再需要准备；只有非房主真人全部准备且房间满足人数/电脑补位规则时，右侧“开始”可用。
3. 操作行只有左侧“离开房间”和右侧角色上下文按钮；页面不再绘制独立开始/等待控件与随机地图提示。
4. 房间快照中的真人显示名取自已认证账号；缺失时显示“未命名玩家”，不生成“玩家X”。
5. GDScript 缩进检查、项目解析、注册表测试、主流程适配测试、真实 ENet 回环测试通过，并保存和目视检查房主/访客房间截图。
6. 删除任务专用临时场景、截图脚本、日志与缓存；不删除任何无关现有文件。

本任务不包含阿里云部署、生产重启、APK 导出或 Android 实机验收；不得用本机回环替代公网或手机包验收。
