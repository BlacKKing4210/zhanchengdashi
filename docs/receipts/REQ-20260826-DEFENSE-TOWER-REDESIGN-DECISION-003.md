# REQ-20260826 防御塔方案 B 历史决策回执（已被取代）

> `SUPERSEDED_BEFORE_RUNTIME_BINDING`：制作人于 2026-08-27 随后改选方案 A，并要求严格对齐已有动物画风、使用大色块和更少细节。方案 B 未进入 `res://`、卡牌配置或战场绑定，不再是当前执行来源；当前正式决策见 `REQ-20260826-DEFENSE-TOWER-REDESIGN-DECISION-004.md`。

- 时间：2026-08-27（Asia/Hong_Kong）
- 项目：`D:/AI/zhanchengdashi`
- 分支：`codex/animal-art-integration-20260811`
- 基线提交：`9f29df99058784a73517e4361b49930d49da732e`
- 功能：`F-ZC-DEFENSE-TOWER-005`
- 任务：继续 `REQ-20260826-DEFENSE-TOWER-REDESIGN-V1`，不创建重复任务
- 版本／阶段：`v1.1.0`／`runtime_art_integration`
- 任务指纹：`BB979F86A43FB3D32BC43AFF6F78CEA3EF54A3C6750246882E4C8458AC6F2123`
- 负责人／唯一写入者：`user-producer`／`codex-primary`
- RAG：`READY`，10 条带来源引用；任务回执 `temp/rag/receipts/tasks/REQ-20260826-DEFENSE-TOWER-REDESIGN-V1.json`
- Control：`READY / L3 / continue_existing`，无冲突任务

## 制作人决策

| 字段 | 记录 |
| --- | --- |
| `decision_state` | `approved` |
| `approved_rule` | 采用方案 B：统一石质堡垒建筑主体，动物元素只作为屋脊、檐口、扶壁、甲片、纹样、机括、导管等建筑部件；十座塔重新生产透明正式图并接入卡牌与战场。 |
| `superseded_rule` | A/B 尚未选择、候选板仅供方向评审。 |
| `formal_source_target` | `docs/DEFENSE_TOWER_SYSTEM_DESIGN_v1.1.docx`、方案 B manifest、`docs/CURRENT_GAME_DESIGN.md`。 |
| `affected_domains` | 美术、配置、Godot 运行时、QA。 |
| `execution_readiness` | `READY`；方向已定，数值与技能机制维持 v1.0 已验收结果。 |
| `unresolved_producer_decisions` | `none` |
| `reusable_method_candidate` | `none` |

## 正式资产与运行切片合同

- 原 `defense_towers_v2` 方向板保持 `NOT_RUNTIME`；禁止直接裁切、放大或绑定其 RGB 白底像素。
- 正式单图恰好 10 张，稳定卡牌 ID 命名，`480×480 RGBA8 PNG`，直通 Alpha；视觉中心 `x=240±6px`，建筑基线 `y=438±4px`。
- 建筑主体至少占主轮廓 85%；禁止完整动物、独立巨大动物头、眼鼻嘴/喙组成的脸形结构；每塔只保留一个主技能道具，双弩塔允许同构双武器。
- 品质色只作为 15%～25% 的屋顶、旗帜、机械或护甲强调：品质 2 绿、品质 3 蓝、品质 4 紫、品质 5 金；主体保持中性石材与深墨轮廓。
- 代表塔为 `defense_twinshot_tower`（鹦鹉双弩塔）：先验证石塔+双弩读法，金色三角构件必须是无眼、无脸的雨棚/箭槽，不能读成鹦鹉头。
- 代表切片在真实 Godot 路径与 `720×1280` 下同时验证卡牌详情和战场建筑；无 BLOCKER/MATERIAL 后才扩展并绑定其余九塔。
- 已建成塔通过 `tile.site_card -> card.art_path` 显示正式图；未解锁塔继续用通用黑灰剪影；缺图或旧存档空 ID 安全回退通用塔，禁止回退为兔子图。
- 战场绘制只能使用纹理缓存；热路径禁止逐帧 `load()`、`get_image()`、像素扫描或 Alpha 检查。

## 基线哈希

- `docs/active_scope.yaml`：`6F58EB964750365F40E6CD9857E8AD354D7A858C0C3775473DDFE83C17590DAA`
- `scripts/app/main.gd`：`28BDC169598890868B86D8068E48839FD6B79B924E054AE2F89CF5C5373D1FCF`
- `config/tables/cards.csv`：`FC76C832B6BE3BE71859DF9CFF42E34EB49F8DB958860D38593F5B6D49FBD6BB`
- `runtime/config/cards.json`：`07B1615F5F58377E2BAB35F8AF525EA58D20806EFF9AB258F1695222EC2F90DB`
- `tools/build_defense_tower_system_docx.py`：`5F9C7AE1562FB0DDBFA2A84139481205A23CB8E8BA79657D1A9619737527B09A`
- 方案板 manifest：`DE188AD86FCF3766E37FA89F19CF1FBFCA9C8D81D5FD4E5F094676A8E4162013`
- `tests/capture_defense_tower_cards.gd`：`54DC4A85CEE1B4B77EBDBDA72629101B611A8F08DC171EF460BC7453F2D73114`
- `tests/test_defense_deck_integration.gd`：`8C2083E1F06CF2B97938E3D3A9427AD2B21F4A79FCC32093EB7FE028A0A2F6D3`

## 验收与清理

- 资产：尺寸、模式、Alpha 极值、透明角、bbox、安全边距、基线、占用率、SHA-256、浅/深底与 48/56/64/96px 小图检查全部通过。
- 配置：`validate -> export -> validate`；十个 `art_path` 唯一且均可加载。
- 代码：GDScript 缩进、Godot parse/start、防御塔技能、卡组、稀有度、经典、排位 AI、多人及 72 单位性能回归。
- 视觉：`720×1280` 代表塔卡牌详情、代表塔战场、十塔运行时目录/整套证据；建筑生命条位置不因新图漂移。
- 清理：候选图不得进入 `res://`；不提交 `.import`、编辑器缓存、临时生成源、DOCX 临时 PDF 或无关脏文件。

本次未请求 APK、服务器部署或远程写入，均不在范围内。
