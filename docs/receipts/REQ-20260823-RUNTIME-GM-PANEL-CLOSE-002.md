# REQ-20260823-RUNTIME-GM-PANEL 关闭回执

- 功能：`F-ZC-GM-001` 运行时 GM 资源面板
- 版本：`v1.0.0-runtime-gm-panel`
- 日期：2026-08-23
- 负责人：`codex-primary`
- 任务指纹：`5FF3116079430C419B34229719B0750A3CE73FFC35DD85A042B19D353BD6BE25`
- 本地实施状态：COMPLETE
- 发布状态：LOCAL_DEBUG_IMPLEMENTATION_VALIDATED；未制作 Android 包、未部署或修改服务器

## 完成交付

1. Godot 调试构建运行时按 F2 打开或关闭唯一的模态 GM 弹窗；Escape 和关闭按钮也可关闭。
2. 面板提供资源、卡牌、操作和整数数值控件，支持增加、减少、设为三种操作。
3. 支持本地单人战斗金币、游客会话抽卡券、卡牌数量和卡牌等级；执行后立即刷新当前值并显示成功或失败原因。
4. 单人战斗打开面板时临时暂停，关闭后恢复打开前的暂停状态；弹窗可阻断棋盘点击、触控和未处理键盘输入。
5. 互联网对战期间无法打开，若对战在弹窗开启后启动则自动关闭。非调试构建不可创建或执行 GM 面板。
6. 已登录账号的抽卡券、卡牌数量和等级受服务器保护；本功能不调用后台发放、在线保存或账号写入接口。
7. 数值仅接受非负整数；越界、空值、小数、未知资源/操作或缺少卡牌选择均不修改数据。

## 验收结果

| 验收项 | 结果 | 证据 |
|---|---|---|
| GDScript 缩进 | PASS | `tools/check_gd_indentation.py`：tab 缩进门禁通过 |
| 项目解析与启动 | PASS | Godot 4.6.3，`--headless --path . --quit-after 3`，退出码 0，无解析错误 |
| 资源规则 | PASS | `test_gm_resource_rules.tscn`：增加/减少/设为、整数、上下界、卡牌选择、登录态、联网态和发布态门禁通过 |
| F2 与面板交互 | PASS | `test_runtime_gm_panel.tscn`：F2/Escape、单实例、暂停恢复、输入消费、真实信号发放、保护资源拒绝通过 |
| 账号输入回归 | PASS | `test_account_manual_login_entry.tscn` |
| 联网主适配回归 | PASS | `test_online_main_adapter.tscn` |
| 经典战斗回归 | PASS | `test_classic_battle_regression.tscn`：5 种随机地图通过 |
| 运行画面 | PASS | OpenGL Compatibility / NVIDIA RTX 4060 Laptop GPU；1080×1920 PNG 已人工检查，无重叠、裁切或模糊 |
| DOCX 结构 | PASS | 95 段、18 表、6570 字符；无模板占位符 |
| DOCX 分页 | PASS | Word COM 临时渲染后经 Poppler 输出 8 页 PNG；8 页均已人工检查；未生成 PDF 交付物 |
| 项目 RAG | PASS | 最终索引 81 个来源、1132 个分块；16/16 黄金查询通过；本请求上下文含 8 条可核验引用 |

Godot 测试退出时仍会报告项目既有的 ObjectDB/资源残留警告；本任务及回归测试退出码均为 0，未把警告隐藏或误报为无警告。

## 玩家可见证据

- 路径：`temp/qa/F-ZC-GM-001/runtime-gm-panel-20260823/runtime-gm-panel.png`
- 分辨率：1080×1920
- SHA-256：`00679E6D2726502AC0584A8FC6BDD883198E8F7D837BD0C6D8E235E04571EB23`

## 关键产物

- `scripts/app/main.gd`
  - SHA-256：`4A5245C58597383D7096582ABB34CD4B2D212606D2EA1C3AE26E0F0653EA7C58`
- `scripts/app/systems/gm_resource_rules.gd`
  - SHA-256：`4451609F002A6AB9D8395D4565F57275DF37D7730B095489511754F002F65F8D`
- `scripts/app/ui/runtime_gm_panel.gd`
  - SHA-256：`1A9111914DCF0E44F8EA1807F72BB3B1FA90B611BB2AA82DD6F95C8A71FE079E`
- `docs/RUNTIME_GM_PANEL_DESIGN_v1.0.docx`
  - SHA-256：`1B04F5742074F945562AB5C36C6F83B29503255ED6A28C96CB73A01AABDD4D9E`

## 边界与关闭结论

- 这是开发调试工具，不是面向玩家的发布功能；发布构建中 F2 不启用。
- 游客账户资源和单人战斗金币只保留在当前运行会话，关闭游戏后不自动保存。
- 本次没有修改 `config/tables/` 或 `runtime/config/`，因此不触发配置导出。
- Android 包、服务器部署和真实云账号资源发放不在本请求授权范围内。

本地行为、输入、安全、回归、文档和玩家可见画面门均已通过，共享写锁可以释放。
