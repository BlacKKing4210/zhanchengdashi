# REQ-20260822-BATTLE-INFO-TARGET-LOCK-001 关闭回执

- 功能：F-ZC-001 战斗动物信息去重与持续锁敌
- 版本：v1.1.0-battle-info-target-lock
- 日期：2026-08-22
- 负责人：codex-primary
- 指纹：`5738625083D3D6259BB4D60005F9ABF11DEDA3C86FF87B22FD8F2229654DE8FA`
- 本地实施状态：COMPLETE
- 发布状态：LOCAL_IMPLEMENTATION_VALIDATED；未制作 Android 包、未部署服务器

## 交付范围

1. 战斗选中动物与动物营地预览：左侧缩略卡不再重复绘制动物名；右侧摘要仅保留一次动物名与等级；摘要不再显示品质文字。
2. 动物攻击：稳定保存当前单位 ID 或建筑地块键；目标仍存活、敌对且在射程内时直接复用。
3. 防御塔攻击：按防御塔地块保存稳定目标；仅在目标死亡、摧毁、失效或离开射程时重新扫描。
4. 保留原有首次选敌的距离与偏好规则；新出现的更近目标不能抢走有效锁定。
5. 未修改 `config/tables/` 或 `runtime/config/`，不触发配置导出。

## 验收结果

| 验收项 | 结果 | 证据 |
|---|---|---|
| GDScript 缩进 | PASS | `tools/check_gd_indentation.py`：4 个触及脚本均为 tab 2 |
| 项目解析 | PASS | Godot 4.6.2 `--headless --quit`，退出码 0 |
| 信息标题规则 | PASS | `test_battle_unit_inspection.tscn`：动物名恰好一次、品质文字不存在 |
| 动物持续锁敌 | PASS | 更近目标出现不切换；目标出圈后重选；目标死亡后重选 |
| 防御塔持续锁敌 | PASS | 更近目标出现不切换；目标出圈后重选；目标死亡后重选 |
| 72 单位性能 | PASS | 400 样本：median 1317 μs，mean 1388.23 μs，p95 2105 μs；门槛 4000 μs |
| 目标丢失回归 | PASS | `test_target_loss_no_retreat.tscn` |
| 经典战斗回归 | PASS | 5 种随机地图全部通过 |
| 动态动物上限回归 | PASS | `test_dynamic_battle_animal_cap.tscn` |
| 运行画面 | PASS | Vulkan / RTX 4060 Laptop GPU；营地与选中动物各一张 1080×1920 截图，已人工检查无重名、无品质文字 |
| DOCX 结构 | PASS | 93 段、12 表、28 标题；必需章节与验收条目存在，ZIP 结构可读 |
| DOCX 分页渲染 | NOT RUN | 本机缺少 LibreOffice/`soffice`，标准 DOCX→PNG 渲染器无法启动；未生成 PDF 交付物 |

Godot 日志仍出现 Windows 系统根证书读取失败和退出时资源残留警告；所有本任务测试退出码为 0，未把这些环境/既有警告误报为通过证据。

## 运行时证据

- 日志根目录：`temp/qa/F-ZC-001/battle-info-target-lock-20260822/logs/`
- 营地预览：`temp/qa/F-ZC-001/battle-info-target-lock-20260822/runtime/battle_camp_animal_info_v11.png`
  - SHA-256：`D5562AD377B917302E99AEEFBC78F2DD7877B7D000045B1060950B96F04FAC1F`
- 选中动物：`temp/qa/F-ZC-001/battle-info-target-lock-20260822/runtime/battle_selected_animal_info_v11.png`
  - SHA-256：`B7C65374023A0EDDB03661DB44DE464C9ACF9AE4B72D7F245F370164B9CACC57`

## 关键产物

- `scripts/app/main.gd`
  - SHA-256：`D5079FF95F843503DE636D6389397562521869A87E3A6B0D3178A193CBA33FEE`
- `docs/RENDERING_CLARITY_AND_BATTLE_PERFORMANCE_DESIGN_v1.1.docx`
  - SHA-256：`C5CD87B00CA19279CB443C8C769E6C946EC4ED3A5DAE4EC8ED21E56481C21F26`
- `tests/test_battle_unit_inspection.gd`
  - SHA-256：`08D4BF691C14B53E514783B8794FAC102FC05E059EF14E95D04C26274B91A25D`
- `tests/test_battle_performance.gd`
  - SHA-256：`3BBF9CDC2A26C7D900954F98C43C1C786D00982203C1E14272789CE67E5F2376`

## 关闭结论

本地行为、性能、回归与玩家可见画面门均已通过。共享写锁可释放。Android 真机帧时间和新安装包不在本请求授权范围内，因此不作为本关闭回执的完成证据。
