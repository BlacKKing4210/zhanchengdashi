# REQ-20260820-ONLINE-ROOM-READY-NAMES-001 完成回执

- 状态：`LOCAL_IMPLEMENTATION_AND_LOOPBACK_VERIFIED`
- 完成时间：2026-08-20（Asia/Hong_Kong）
- 分支：`codex/animal-art-integration-20260811`
- 基线提交：`2b1d22083d0c11e197169a7a954401d6a8cba4de`
- 任务指纹：`86AF78BBEA7160ECB63D2F850E7A832EC87700636DA9EF5741ACE75327C0B866`
- 最终 RAG：`READY`，64 个来源、884 个分块、9 条请求引用，索引签名 `88192461d11ef60d501d4b410b9b20694157e011594744b059aef21a2e64f5cd`。

## 玩家可见结果

1. 非房主右侧主按钮显示“准备 / 取消准备”；点击后立即显示“同步中…”，禁止重复提交，成功结果与更高版本服务器快照到达后才结束等待，失败则恢复按钮并显示错误。
2. 房主不再需要单独准备，右侧只显示“开始”；开局条件为房间满足人数/电脑补位规则且所有非房主真人已准备。
3. “离开房间”固定在左侧；独立的第二个开始/等待按钮及其上方随机地图提示已删除。
4. 服务端用连接对应的已认证账号名生成真人 `display_name`，不再信任客户端角色占位名；确实缺少名称时统一显示“未命名玩家”，不生成“玩家X”。
5. 房主迁移、换位、规模切换或真人加入导致准备状态重置时，新房主保持隐式已准备，其他真人重新准备。

## 关键产物 SHA-256

| 产物 | SHA-256 |
|---|---|
| `docs/INTERNET_ROOM_NETWORKING.md` | `27B89E178F25229B2331A7B60B2A4CD01D7D621FA76B96EF7DBF8348E703B970` |
| `scripts/app/main.gd` | `D70BDAB6FA4840F6DAC7AF37006966DCE04E91B04CBE3C3205CEDC77B8A73483` |
| `scripts/network/online_room.gd` | `221D3CEDEDA46886FED1549BBE71C862CF253D7BFD0FB9D5AE60AC37F680486F` |
| `scripts/network/room_registry.gd` | `308D61A2CF8B535A02FF10431C5DCD6D816027213A4E36CD851F184A5BD44B86` |
| `tests/test_online_main_adapter.gd` | `5D9F60ACFCB8614B453D49C401BC38C579883C2B91F099890DB1465797518C4D` |
| `tests/test_online_room_registry.gd` | `6C9F342E5A1F1CFF943825985BA2888E289C3A71B6EB7369D77A260181AF74DC` |
| `tests/test_online_room_transport.gd` | `42D67CF10F0DB3922851DC61759757AE4E9059FFC088128D0A77A600B5102223` |
| `tests/test_online_room_six_client_loopback.gd` | `79CF5D9E673C31388E2D63B7235165F614B552FFF14AE72694531D80431FF47F` |
| `output/qa/REQ-20260820-online-room-ready-names/guest-ready.png` | `EEE19ADA0793405158D83D852F9907AE9850143D45CB4EDECE8B49B37D3C5F97` |
| `output/qa/REQ-20260820-online-room-ready-names/host-start.png` | `191C72F5B2CF62994561F97DFA914B2C8522E4C9AA3B4647E9B296A03C273F10` |

## 验收结果

| 门禁 | 结果 |
|---|---|
| GDScript 缩进检查 | PASS，tab 2 |
| `git diff --check` | PASS |
| 主流程适配与真实点击区域 | PASS；准备、取消准备、房主开始、左侧离开均从点击区域发出正确调用 |
| 房间注册表 | PASS；房主隐式准备、客人门禁、开局后锁定 |
| 真实 ENet 1V1 | PASS；账号名、准备/取消准备/再次准备、开局与快照同步 |
| 房间码输入回归 | PASS |
| 主流程战斗回环 | PASS |
| 六真人 3V3 回环 | PASS；五名客人准备即可开局，随机出生位后的命令身份正确 |
| 房主离开与 AI 接管 | PASS |
| 720×1280 图形运行截图 | PASS；访客右“准备”、房主右“开始”、左侧离开、实名槽位、无独立提示/开始控件 |

Godot 在隔离环境中仍打印 Windows 根证书读取失败与测试退出时 ObjectDB/资源清理警告；所有目标场景退出码均为 0，且这些警告未影响本地 ENet/界面行为。任务专用临时场景、用户目录、日志与缓存已删除；两张通过验收的运行截图保存在正式 QA 目录。

## 边界

- 未部署或重启阿里云服务器，未修改部署配置，也未触碰当前后台部署任务的写锁。
- 未导出 APK、未做 Android 真机或公网双网络验收；这些不是本次请求的一部分，因此本回执不宣称手机包或公网发布完成。
- `knowledge/knowledge_manifest.csv` 中并行后台任务的 v1.1.3 行属于其任务，本次提交只应暂存新增的 `ZC_INTERNET_ROOM_NETWORKING` 行，不能带入并行改动。
- 本次是项目专用房间修复，不形成新的通用 Skill 候选。
