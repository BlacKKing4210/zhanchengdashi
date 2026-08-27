# REQ-20260827 防御塔最终属性与页面显示 V1.3 只读回执

- 时间：2026-08-27（Asia/Hong_Kong）
- 项目／分支：`D:/AI/zhanchengdashi`／`codex/animal-art-integration-20260811`
- 基线提交／上游：`bf6f83d63b258f084f7bb2fca4ba0c88f83a65de`／一致
- 任务：`REQ-20260827-DEFENSE-TOWER-STATS-UI-V13`
- 功能／版本：`F-ZC-DEFENSE-TOWER-005`／`v1.3.0`
- RAG：`READY`；索引 `24f4d07e05aea1d6b5c4e2de3b30f7bcdeed6992ff08d8516daa2f9c7f8dd724`；任务引用数 `10`
- 写锁：`defense_tower_stats_ui_v13_20260827`，owner=`codex-primary`

## 已验证基线

- `config/tables/cards.csv` 与 `runtime/config/cards.json` 的十塔四项 Lv.1 数据已经逐行等于制作人表；唯一玩家文案差异是普通塔额外补写了“基础防御塔，无特殊效果”。
- Lv.3 普通塔当前实际成为攻击 `1`、生命 `6`、距离 `2.4格`、攻击间隔 `1.2s`。根因是 `CardRules.card_stats()` 对防御塔套用了每级 `10.5%` 通用倍率，`main.gd` 又按等级重算了塔间隔。
- 该错误会真实改变建成塔生命、攻击范围和计时，不只是 UI 显示错误。
- 玩家页面有两个独立入口显示距离和间隔：编组卡牌详情与战斗已建塔详情；两处都必须修改。
- V1.2 Word 与 `docs/CURRENT_GAME_DESIGN.md` 明确认可高等级成长及四项可见属性，必须由 V1.3 正式源取代后才能改代码。

## 边界与保留

- 只对防御塔禁用等级倍率；动物与金矿等非防御塔卡继续原有升级规则。
- 不修改 `defenses.csv`、`skills.csv`、特殊塔机制、美术 PNG、卡图绑定、抽卡池、APK 或服务器。
- 保留用户既有工作树修改与历史未跟踪文件；提交时仅暂存本任务写集。
- 旧任务 `REQ-20260826-DEFENSE-TOWER-REDESIGN-V1` 已 `COMPLETE`，本次建立新修订任务，不复用终态任务。
