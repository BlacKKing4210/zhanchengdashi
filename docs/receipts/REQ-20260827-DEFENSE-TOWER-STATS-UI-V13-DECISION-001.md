# REQ-20260827 防御塔最终属性与页面显示 V1.3 制作人决策回执

- 时间：2026-08-27（Asia/Hong_Kong）
- 项目：`D:/AI/zhanchengdashi`
- 分支：`codex/animal-art-integration-20260811`
- 基线提交：`bf6f83d63b258f084f7bb2fca4ba0c88f83a65de`
- 功能：`F-ZC-DEFENSE-TOWER-005`
- 新任务：`REQ-20260827-DEFENSE-TOWER-STATS-UI-V13`
- 版本／阶段：`v1.3.0`／`config_ui_revision`
- 任务指纹：`96E182CD014100DA0E653D51B19F3F2060F1CF899EC20A46005BA15BA8CE359F`
- 负责人／唯一写入者：`user-producer`／`codex-primary`
- RAG：`READY`；任务回执 `temp/rag/receipts/tasks/REQ-20260827-DEFENSE-TOWER-STATS-UI-V13.json`

## 制作人最新决策

| 字段 | 记录 |
| --- | --- |
| `decision_state` | `approved` |
| `approved_rule` | 十座防御塔的攻击、生命、距离、攻击间隔和玩家技能描述严格按制作人最新表；四项数值是考虑效果后的最终值，防御塔在所有卡牌等级都不再应用等级倍率。卡牌详情和战斗塔详情不得显示距离与攻击间隔，只显示攻击、生命和表内技能描述。 |
| `blank_skill_rule` | 普通兔子哨塔的技能描述格为空，因此页面不显示技能行；不得自行补写“基础防御塔，无特殊效果”或其他说明。 |
| `hidden_value_rule` | 距离与攻击间隔仅从玩家页面隐藏，内部战斗继续严格使用表内数值；不得删除字段、归零或改成统一值。 |
| `superseded_rule` | V1.2 的“仅 Lv.1 精确、后续沿用等级成长”“页面显示攻击、生命、距离、间隔”以及普通塔补写说明全部被本决策取代。 |
| `art_scope` | 方案 A 十塔图片与运行时绑定保持不变，本次不重做美术。 |
| `unresolved_product_decision` | `none`；防御塔升级入口暂保留等级记录，但不提供四项战斗属性成长，非属性升级收益另案处理。 |

## 验收口径

1. 十塔在 `Lv.1 / Lv.2 / Lv.3 / Lv.8 / Lv.10` 的攻击、生命、格数和间隔逐项等于制作人表。
2. 兔子哨塔技能文本为空；其余九塔玩家可见文本逐字等于制作人表，稳定技能机制不变。
3. 编组卡牌详情与战斗已建塔详情只显示攻击、生命和非空技能文本；任何塔均不显示 `X格` 或 `X.Xs`。
4. `720×1280` Godot GPU 证据覆盖 Lv.3 普通塔与长技能文本塔；自动测试同时证明隐藏的距离和间隔仍真实参与战斗。
5. 本次未请求 APK、服务器部署或美术重制，均不在范围内。
