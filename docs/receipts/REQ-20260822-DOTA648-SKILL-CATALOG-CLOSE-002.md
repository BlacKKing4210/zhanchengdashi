# REQ-20260822-DOTA648-SKILL-CATALOG 收口收据

- 日期：2026-08-22
- 状态：COMPLETE
- 版本口径：`DotA Allstars v6.48b`
- 负责人：design_owner / codex-primary
- 任务指纹：`18FD76316D01F1B17047B810CFB6F30994107FC2B5EEDDF59DC7910757A89B97`
- RAG：READY，索引签名 `7897c0843ef753ef6011fac668bd62c3e7f4a78ac47c93adcb470379ef5aa0bf`

## 交付结果

- 工作簿：`outputs/019feef3-0034-7a90-b271-0ef2a651b042/dota_allstars_6_48b_skill_catalog_2026-08-22.xlsx`
- 工作簿大小：`160824` bytes
- 工作簿生成时间（UTC）：`2026-08-22T05:09:10.1441260Z`
- 工作簿 SHA-256：`30CF83352DF31C8EFE3A7BEC7C0856BDACD913FD52D4207CF5E758BB2EB6DC6F`
- 工作表：8 张；实际 Excel 数据表：5 张；ZIP 条目：30；损坏条目：0。

工作簿包含：口径与摘要、356 行英雄技能主表、89 行英雄覆盖、356 行对象字段明细、公式驱动分类统计与图表、通用技能、分类字典、来源与冲突。

## 覆盖结果

- 8 个非空英雄酒馆的 `Sellunits` 售卖名单去重后正好为 89 名可选英雄。
- 89 名英雄均有 4 个可学习专属技能，共 356 个英雄—技能关系；其中 `Shadow Strike (AEsh)` 被两名英雄共用，因此唯一技能对象为 355 个。
- 每名英雄恰有 1 个终极技能，共 89 个；普通技能 267 个。
- 通用 `Attribute Bonus` 以 `Aamk / A0NR` 合并记录一次，不在主表重复 89 次。
- 英雄中文常用名 89/89；技能英文名 356/356；空技能名、空结构化摘要、空等级数均为 0。

## 原始证据与检索状态

- AnySearch 主检索成功；查询族包括：`DotA Allstars 6.48b hero list abilities skills`、`DotA Allstars v6.48b changelog map archive`、`DotA 6.48b heroes skills database Warcraft 3`、`GitHub DotA 6.48b hero ability data`。
- `agent-reach doctor --json` 在本机不可用；没有把该失败伪报为已通过。AnySearch 可用，因此未进入 AnySearch 降级状态。
- 主证据：公开 GitHub 历史地图 `DotA Allstars v6.48b.w3x`；地图大小 `2479765` bytes；SHA-256 `F8F4948CED70D6AAD30D4A812C80CFFBDFEBE9B9532CDC9EDD4C7ECF080582C5`。
- 独立名单旁证：EpicWar 的 `DotA Allstars v6.48b AI+ 1.52` 页面，明确写有 89 名独特英雄。
- 提取链：W3X → 标准 MPQ → `UnitAbilities.slk`、`AbilityData.slk`、`*AbilityStrings.txt`、`war3map.w3a/w3u`、`Scripts/war3map.j`。
- 地图只在操作系统临时目录中只读解析；未嵌入工作簿、未进入版本库、未随交付件再分发。

## 数据与版权处理

- 工作簿保留技能英文名、Raw ID、阵营、酒馆、英雄属性、等级、是否终极、施放/目标类型、机制分类、魔耗、冷却、距离、范围、持续时间、DataA–I、UnitID、BuffID、EfctID 与来源证据。
- 长篇商业游戏 Tooltip 只用于内部事实解析，不在交付工作簿中逐条复刻；交付列为原创的结构化中文摘要、数值参数与数字索引。
- 物品技能、中立生物/召唤物独立技能、Roshan、地图机制、编辑器隐藏辅助技能和运行时中间态按钮不进入英雄技能主表，并已在工作簿标明。

## 冲突与处理

- `Static Field (A0N5)`：6.48b 运行脚本公式对应当前生命 `6%/8%/10%/12%`，残留 4 级对象 Tooltip 写 `11%`。工作簿同时保留双方证据并标记冲突，没有静默选择其一。

## 验证证据

- Artifact Tool 导出后重新导入：8 个工作表，范围分别覆盖 `A1:AG357` 主表、`A1:O90` 英雄覆盖与 `A1:T357` 对象字段明细。
- 公式错误扫描：`#REF! / #DIV/0! / #VALUE! / #NAME? / #N/A` 命中 0。
- 覆盖公式结果：89/89 英雄为“完整”；主表 356 行；89 行终极技能；356 行 A 级证据。
- 渲染目检：摘要、分类统计/图表、英雄覆盖、完整技能主表均已检查；标题、表头、冻结区、条件色、长字段换行和图表无明显截断或不可读问题。
- 工作树中既有游戏代码、平衡配置、管理后台、活动范围与部署文件均未修改或纳入本任务提交。

## 遗留边界

- 技能中文名称在现代版本存在译名漂移；主表以 6.48b 地图英文技能名为版本基准，不把现代中文译名伪装成旧版原始字段。
- “全部技能”的验收口径是 89 名可选英雄的可学习专属技能加一次通用属性技能，不是地图内全部隐藏辅助对象。
