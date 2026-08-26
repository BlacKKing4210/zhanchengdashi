# REQ-20260826 防御塔重制只读回执

- 时间：2026-08-26（Asia/Hong_Kong）
- 项目：`D:/AI/zhanchengdashi`
- 分支：`codex/animal-art-integration-20260811`
- 基线提交：`106ade96038a442a7c5c588265d1761f7b7d1c2b`
- 功能：`F-ZC-DEFENSE-TOWER-005`
- 指令指纹：`5EF7737B31EB5E815E5EFC316C6B9E53C48E55C55F76E38B4642B1A00FF5E0B6`
- 负责人／写入者：`user-producer`／`codex-primary`
- RAG：`READY`，任务回执 `temp/rag/receipts/tasks/REQ-20260826-DEFENSE-TOWER-REDESIGN-V1.json`，上下文 `temp/rag/context/REQ-20260826-DEFENSE-TOWER-REDESIGN-V1.md`

## 制作人正式来源

本回执记录本次对话中的最新防御塔表为唯一数值来源：共 10 座塔，品质 2/3/4/5；攻击、生命、距离、攻击间隔均是已经考虑包装效果后的最终基础面板，禁止再因“攻击+1”“生命+200%”“攻击速度+200%”“距离+1”等文案二次加成。特殊行为由稳定技能 ID 驱动，中文描述只负责显示。

## 基线核验

- `config/tables/cards.csv`：`93D09D8CA28C58358A6E8E3D80858CB3B83C095195087694942BBD7F75C9E510`
- `config/tables/defenses.csv`：`A2962F5AF167627AD47C70B40B8D307BE05D39A175F5B349E0440FC9F5FEB354`
- `config/tables/skills.csv`：`1CE36C3C65BD11B7BAB0618E147BF9065DCD194EC4939C81BD5C2C8D1401EB28`
- `config/tables/card_random_pools.csv`：`31C785D0D519115F0AEFCD45640A7336D98EFA1FFE8EB04A13D81FB08FDDA7E8`
- `config/schema/config_schema.json`：`17DCD69F7B304346F84C789EBE60F21E01606613C009459A9784C4BF2167D9A0`
- `scripts/app/main.gd`：`FA2576F102A9212DD6813A07D2B0F4FF1E0967A9C3CF1765036B0771AFA2FF9C`
- `scripts/app/systems/card_rules.gd`：`E215F721FD7AB3388DE68280D5EA3C12382E6850FD067DF543620CBA52201941`

## 已确认的问题

1. 当前真实战斗读取 `cards.csv → runtime/config/cards.json`，旧 `defenses.csv` 与实际战斗数值冲突。
2. 现有代码给所有塔额外增加半格距离并强制 1 秒间隔，会破坏制作人最终属性。
3. 塔技能目前没有运行时结算；玩家可见描述只读 `cards.skill_text`。
4. 卡牌可读 `art_path`，但战场建成塔仍为通用程序图标。
5. 既有 4 个塔 ID 被初始卡组、AI 与玩家档案引用，必须保留稳定 ID，再新增 6 个 ID。

## 本次实现边界与解释

- Lv.1 精确等于制作人表；既有卡牌升级成长继续生效，但包装文字不重复计算。
- “攻击时，掠夺1金币”：成功直接攻击后从目标阵营转移最多 1 金币；目标为 0 时不凭空产币。
- “额外攻击1个敌人”：额外命中一个不同的范围内敌方动物，使用完整面板攻击，不重复主目标。
- “击杀时，获得10金币”：仅该塔实际击杀动物时触发，摧毁建筑不触发。
- “我方领地”：目标当前位置地块的可视归属与塔阵营同盟；仅动物合法，离开领地立即失效。
- “所有动物”：每 5 秒替代普通单体攻击，对触发瞬间所有存活动物（含己方、友方、敌方）各造成 1 点伤害，不伤建筑。
- 远程优先只影响新目标获取，保留已锁定合法目标，避免频繁换靶和性能回退。

## 美术门禁

本次先提供 10 塔完整两版审核板，状态为 `NOT_RUNTIME`。项目已批准的美术流程要求整套审核后才切分、标准化、绑定正式单图；因此在制作人批准审核板之前，不把候选图写入 `res://assets/art/buildings/defense_towers/`，也不替换战场运行资源。机制、数据和描述可独立完成与验证。

## 保留项

工作树已有的 `design/战斗数值.xlsx` 修改、`.codex/`、导入缓存、历史回执、translation 文件、PDF 与临时 import 均为用户既有内容，本任务不覆盖、不暂存、不清理。
