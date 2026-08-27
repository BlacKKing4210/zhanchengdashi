# REQ-20260826 防御塔方案 A 动物同风格低细节实装决策回执

- 时间：2026-08-27（Asia/Hong_Kong）
- 项目：`D:/AI/zhanchengdashi`
- 分支：`codex/animal-art-integration-20260811`
- 基线提交：`9f29df99058784a73517e4361b49930d49da732e`
- 功能：`F-ZC-DEFENSE-TOWER-005`
- 任务：继续 `REQ-20260826-DEFENSE-TOWER-REDESIGN-V1`，不创建重复任务
- 版本／阶段：`v1.2.0`／`runtime_art_integration`
- 任务指纹：`0E777AD6F930601837F574B05CE0E6BEE9083CDBD07A2FD7D3E6B324D8CF0BF9`
- 负责人／唯一写入者：`user-producer`／`codex-primary`
- RAG：`READY`；任务回执 `temp/rag/receipts/tasks/REQ-20260826-DEFENSE-TOWER-REDESIGN-V1.json`
- Control：`READY / L3 / continue_existing`，无冲突任务

## 制作人决策

| 字段 | 记录 |
| --- | --- |
| `decision_state` | `approved` |
| `approved_rule` | 采用方案 A；整体画风必须与现有动物图片一致，使用粗深色轮廓、大色块、少量平涂阴影和明显更少的细节；完成十座正式透明塔图并接入卡牌与战场。 |
| `superseded_rule` | 方案 B。B 仅完成生产准备与临时代表候选，未进入 `res://`、配置或运行时绑定。 |
| `formal_source_target` | `docs/DEFENSE_TOWER_SYSTEM_DESIGN_v1.2.docx`、本回执、方案 manifest、`docs/CURRENT_GAME_DESIGN.md`。 |
| `affected_domains` | 美术、配置、Godot 运行时、QA。 |
| `execution_readiness` | `READY`；数值与技能机制维持 v1.0 已验收结果，只重做正式视觉并实装。 |
| `unresolved_producer_decisions` | `none` |

## 方案 A 正式视觉合同

- 现有动物 PNG 是一级画风来源；原 `defense_towers_v2` 方案 A 板只提供轮廓和功能构图，继续标记 `NOT_RUNTIME`，禁止直接裁切、放大或绑定白底像素。
- 每座塔只保留 `3～5` 个主形状、`4～6` 个稳定色彩角色和 `2～4` 块大面积墙体分区；主体采用平涂或最多两档阴影。
- 禁止逐块砖缝、微小铆钉、密集木纹/羽毛线、金币纹理、碎旗、碎金属、场景背景、烘焙地面阴影与装饰噪点。
- 塔体至少占主体轮廓 `85%`，第一眼是建筑；动物元素只能作为屋脊、檐口、扶壁、甲片、纹样、机括或导管，禁止完整动物、独立巨大动物头和眼鼻嘴构成的脸形。
- 一塔一个主要技能道具；鹦鹉双弩塔允许左右一对同构弩。品质色使用大块屋顶、护甲或旗面表达，不用细小镶边堆砌。
- 正式单图恰好十张，稳定卡牌 ID 命名，`480×480 RGBA8 PNG`，直通 Alpha；视觉中心 `x=240±6px`，建筑基线 `y=438±4px`，四角至少 `24×24px` 全透明。

## 代表切片与运行时合同

- 代表塔仍为 `defense_twinshot_tower`（鹦鹉双弩塔），因为它同时验证双武器、紫色品质和最容易误读成动物头的高风险结构。
- 代表塔必须在 `56×56` 战场尺度仍读出“中央建筑＋左右双弩”，不得出现眼睛、喙脸或完整鹦鹉；通过白/黑/绿色/紫色背景与 `720×1280` Godot 运行切片后才扩量。
- 已建成塔通过 `tile.site_card -> card.art_path` 显示正式图；未解锁塔继续使用通用黑灰剪影；缺图、空 ID 或旧存档安全回退通用塔，禁止回退为兔子图。
- 战场热路径只读取预先缓存纹理，禁止逐帧 `load()`、`get_image()`、像素扫描或 Alpha 检查。

## 验收与清理

- 资产：整板恰好十塔；每张尺寸、模式、Alpha、透明角、bbox、基线、占用率与 SHA-256 记录完整；浅/深底和 `48/56/64/96px` 小图均通过。
- 配置：`validate -> export -> validate`；十个 `art_path` 唯一并可加载。
- 代码：GDScript 缩进、Godot parse/start、塔技能、卡组、稀有度、经典、排位 AI、多人及 72 单位性能回归。
- 视觉：`720×1280` 卡牌详情、战场建筑和十塔目录证据；塔体与生命条距离不因新图漂移。
- 清理：方案 B 临时生成源、方向板像素、候选图、DOCX 临时 PDF、`.import` 与编辑器缓存不进入提交。

本次未请求 APK、服务器部署或远程写入，均不在范围内。
