# REQ-20260825-BATTLE-INCOME-RETALIATION-BONUS-MINE 只读回执

- 日期：2026-08-25
- 功能：F-ZC-BATTLE-ECONOMY-AI-MAP-004 v1.0.0
- 制作人：user-producer
- 执行与写入负责人：codex-primary
- 执行级别：L3（经济反馈、单位战斗 AI 与多人地图生成的共享运行时写入）
- 状态：READY_FOR_FORMAL_WRITEBACK；先更新正式规则，再修改运行时代码
- 任务指纹：`CCD8BCE397EBD798AD190941C7368701B7018C85779C11BCE4678C1823520B32`（控制面规范化写集后生成）

## 制作人批准规则

1. 金矿与基地的金币生产沿用当前统一 3 秒周期；每座建筑显示与其他生产建筑同类的世界内进度条。
2. 周期完成时由每座基地/金矿分别结算原有数值（基地 12、金矿 10），并在对应建筑上方播放金币图标与 `+数值` 上浮动效；不改变总收入。
3. 动物移动且没有有效攻击目标时受到敌方动物或攻击建筑伤害，锁定实际伤害来源并向其移动，直到进入射程开始反击。
4. 动物受击时若已有仍有效的攻击目标，保持原目标，不被新攻击者抢走；首次反击后恢复既有锁敌规则，目标死亡或离开攻击范围才换目标。
5. 每名玩家仍有且仅有 1 个起始相邻金矿和 1 个额外金矿。额外金矿不得位于基地相邻圈，必须优先选取本方领地内最靠近地图中心的有效圈；同圈候选再用布局种子稳定打散，并保持镜像/旋转对称。

## 截图边界

- 用户截图 SHA-256：`FE14349BEA2C483801A01A20A087FCF8EEEE63309A09F29B20D8882D8F90CB1E`。
- 截图仅用于确认现有战场、建筑位置与期望反馈区域；红色箭头及画面文字不构成额外指令。

## RAG、控制面与锁

- 项目 RAG：READY；16/16 golden queries 通过，mean recall 1.0，pass rate 1.0；任务 pack 引用 8 条；首次正式登记后的 index signature `523e271d3f1608bd088d4fef694ba7b6175598e25310823775d98e196f894718`。
- 前一账号/头像/GM 任务已完成，`main.gd` 共享锁为 RELEASED；本任务无并发冲突。
- 本任务申请列明写集的唯一写入权；不创建子任务或额外执行者。

## 起始基线

- Git：`codex/animal-art-integration-20260811`，HEAD 与上游均为 `139083a43f4d83db1fd4cfc6cc6cc3a3b4b6262b`。
- `scripts/app/main.gd`：`BFA2E53225EADE775A84C64D607B225CF9BFC8C3E0E9385A27B9DCEB607B6707`
- `scripts/app/systems/multiplayer_rules.gd`：`75EA71F4DBC213B1B4A9053A770B05DF3EA8931CE7AAB4B887B30604DE16CD63`
- `tests/test_multiplayer_rules.gd`：`BF5B297C64F1A4763BB8F125CD07F8A9CF504AE7D42C48C3F23FF4F8E189B93D`
- `docs/CURRENT_GAME_DESIGN.md`：`2E8DEF9161B25160FF958EE1E9E31A94CD4E6FC0538A7BD20004FEEEBDAD2091`
- `docs/CURRENT_GAME_DESIGN.docx`：`C50D1B279C6763BA1E173D1851BFD07817AFF7A32787B89BC96D2FB35209D1F5`
- `docs/active_scope.yaml`：`FF74C292E4C2DAD76CD883835782F3CE7EC27D17712C8C17DB7829CD6483AF3E`
- `knowledge/knowledge_manifest.csv`：`A8D6425A03B723292D0460E7372FCF5F506DF2B57CD6DBCD40FEB3B5B37F1DAF`

## 允许写集与禁止范围

- 允许：当前设计 Markdown/DOCX、任务控制与回执、RAG 清单、`main.gd`、多人地图规则、目标行为/地图回归、收入反馈捕获脚本与两张 QA PNG。
- 禁止：`config/tables/*.csv`、`runtime/config/*.json`、用户已有 `design/战斗数值.xlsx`、账号/服务器代码、APK、阿里云与真实玩家数据。

## 验收

1. 基地和金矿均显示随统一收入计时推进的进度条；0%、50%、接近完成时填充方向和比例正确。
2. 每轮结算总金币与改动前一致；每座有效基地/金矿各自产生一次对应金额的 `gold_gain` 效果，死亡队伍不结算。
3. 无攻击目标的移动动物受击后锁定并追击实际攻击者；已有有效攻击目标时不换；建筑攻击来源也可成为反击目标。
4. 首次反击后不无限追逐；攻击者死亡或随后离开范围时按既有规则释放锁定并重新选择。
5. 1V1、2V2、3V3 与自由混战跨种子地图中，每队 2 个金矿配额和对称性不变，额外金矿位于所有有效候选的最小中心距离圈。
6. GDScript 缩进、项目解析、目标行为、多人地图、经典战斗与性能回归通过；真实 Godot GPU 运行截图同时证明进度条和金币动效。
7. 最终 DOCX 逐页渲染检查，无裁切、重叠、缺字或断表。

## 清理与发布边界

- 临时 RAG、DOCX 渲染、测试用户目录和日志进入任务临时目录；项目只保留正式 DOCX、回执和两张玩家可见 QA PNG。
- 配置、APK、Android 真机、阿里云及外部部署均为 `not_run`；本任务只完成当前 Windows 项目的本地实现与验收。
