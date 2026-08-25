# REQ-20260825-BATTLE-INCOME-RETALIATION-BONUS-MINE 关闭回执

- 日期：2026-08-25
- 功能：F-ZC-BATTLE-ECONOMY-AI-MAP-004 v1.0.0
- 制作人：user-producer
- 执行与写入负责人：codex-primary
- 状态：`COMPLETE / LOCAL_IMPLEMENTATION_VALIDATED`
- 任务指纹：`CCD8BCE397EBD798AD190941C7368701B7018C85779C11BCE4678C1823520B32`
- 分支：`codex/animal-art-integration-20260811`
- 起始 HEAD / 上游：`139083a43f4d83db1fd4cfc6cc6cc3a3b4b6262b`

## 完成结果

1. 基地与金矿沿用统一 3 秒收入计时，在建筑下方显示与动物营地/大厅相同规格的紧凑进度条；进度由空到满，发放后重新开始。
2. 收入改为按实际建筑逐座结算并调用既有 `gold_gain` 世界反馈：基地保持每轮 +12，金矿保持每轮 +10，每座建筑上方分别显示金币图标和上浮淡出数字；经典与多人总收入规则不变，淘汰队伍仍不结算。
3. 没有有效攻击目标的移动动物受到敌方单位、基地或防御塔实际伤害后，锁定实际攻击来源；范围外来源会被追击至第一次反击。受击时已有有效攻击目标则保持不变；第一次反击后恢复“目标死亡、失效或离开射程才换目标”的普通锁定规则。刺猬反伤使用非递归路径，不会反向制造新的反击锁。
4. 每名玩家仍固定 1 个基地相邻起始金矿和 1 个非相邻额外金矿。额外金矿现在先选择全部合法对称候选中的最小六边格中心距离圈，同圈再按布局种子稳定打散；1V1/2V2 镜像和 3V3/自由战六重旋转规则保持不变。

## 玩家可见证据

两张证据均由 Godot 4.6.2 正式运行场景、Vulkan Forward+、NVIDIA GeForce RTX 4060 Laptop GPU 生成；均为 720×1280 PNG，并已人工逐张检查。

| 证据 | SHA-256 | 验收结论 |
|---|---|---|
| `output/qa/F-ZC-BATTLE-ECONOMY-AI-MAP-004/income_progress.png` | `AAB8F58F9930E6A63A5DCC37A4D5DEDD98E570635D8D1D4794B1D27EDF996DD9` | 基地与相邻金矿均显示约 50% 的黄色生产进度，位置不遮挡建筑主体 |
| `output/qa/F-ZC-BATTLE-ECONOMY-AI-MAP-004/income_payout_effect.png` | `1E928A619412B3E24FB489B6A2DC09D558FA39AD7019DBDB19FCACA875A50B38` | 结算后顶部金币从 60 变为 82；基地与金矿分别显示金币图标、+12 与 +10 上浮动效 |

## 正式文档

- `docs/CURRENT_GAME_DESIGN.docx`：73,685 bytes；SHA-256 `49D264CAA9325C8B2C5DEF8D462A6D3D3F6D9B1FE4CF15018517FD8F9A355D49`。
- 使用 Microsoft Word COM 16 导出临时渲染源，再用 Poppler 生成 34 页 PNG；逐页检查无裁切、重叠、缺字、断表或本次新增内容溢出。
- 临时 PDF 位于系统 Temp、未进入项目或交付物；删除命令被执行环境策略拒绝，因此不把其清理状态冒充为完成。

## 自动化与工程门禁

- `tools/check_gd_indentation.py`：PASS，tab indentation 2。
- Godot 4.6.2 headless editor parse：PASS。
- `test_battle_income_retaliation`：PASS；覆盖收入进度 0%/50%/100%、逐建筑金额/位置、移动受击追击、首次反击恢复普通锁定、已有攻击目标不变、建筑伤害来源锁定。
- `test_multiplayer_rules`：PASS；15 张 1V1/2V2/3V3 房间地图和自由战地图通过，跨种子保持每队 2 矿、对称性及最小有效中心距离圈。
- `test_battle_performance`：PASS；72 单位、400 采样步，mean 1042.11 us、median 995 us、p95 1307 us，低于 4000 us 门限。
- `test_target_loss_no_retreat`、`test_classic_battle_regression`、`test_rendering_clarity`：全部 PASS；经典战斗覆盖 5 个随机地图变体，渲染清晰度 15 项通过。
- `git diff --check`：PASS（仅提示 `docs/active_scope.yaml` 后续由 Git 规范化 CRLF，无 whitespace error）。
- `git diff --exit-code -- config/tables runtime/config`：PASS；配置源和运行时导出均未修改，未触发 CSV 导出链。
- 部分短生命周期测试在退出时仍输出 Godot `ObjectDB/resources still in use` 清理警告，但所有目标测试退出码均为 0；不将其描述为“无警告退出”。

## 关键工件哈希

- `scripts/app/main.gd`：`FA2576F102A9212DD6813A07D2B0F4FF1E0967A9C3CF1765036B0771AFA2FF9C`
- `scripts/app/systems/multiplayer_rules.gd`：`99FAA96EEAC88CD51614AEB8F172D49C6BB50D5A6192611DD7FFBE5422D9DAF4`
- `tests/test_battle_income_retaliation.gd`：`C286A1652A1843CD694C001761652CD191ACD569E19E4115E01E7D508C67047C`
- `tests/test_multiplayer_rules.gd`：`9BC29559DBB35C32268F813331C41A5608DA461CA7AAFD47DAEA1F3AE7CADB89`
- `docs/CURRENT_GAME_DESIGN.md`：`98169D024BE16558D90F950FA7102DA81B5C77EDA19CEB8411FA4F1FA7F6C1DB`

## 边界与未执行项

- 未修改用户已有的 `design/战斗数值.xlsx` 和其他无关未跟踪文件。
- 未修改 `config/tables/*.csv` 或 `runtime/config/*.json`，未改变基地/金矿原有收入数值。
- Android 真机：`not_run`。
- APK：`not_requested / not_run`。
- 阿里云、生产账号数据、远程服务：`not_authorized / not_run`。

## 关闭条件

- 本任务共享写锁在正式 DOCX、运行时行为、地图规则、性能回归、两张 GPU 截图、配置不变检查和本关闭回执完成后释放。
- 最终 RAG `prepare + pack` 与控制面检查在本关闭回执、knowledge manifest 和 active scope 入库后重新执行；Git 提交由包含本回执的同一提交承载。
