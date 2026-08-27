# REQ-20260826 防御塔方案 A 代表切片与整套运行时回执

- 时间：2026-08-27（Asia/Hong_Kong）
- 项目：`D:/AI/zhanchengdashi`
- 分支：`codex/animal-art-integration-20260811`
- 基线提交：`9f29df99058784a73517e4361b49930d49da732e`
- 功能：`F-ZC-DEFENSE-TOWER-005`
- 任务：`REQ-20260826-DEFENSE-TOWER-REDESIGN-V1`
- 版本：`v1.2.0`
- 方向：方案 A；与现有动物图一致的粗轮廓、大色块、低细节建筑化表达
- 结果：`PASS`

## 美术生产结果

- 已生成并发布 10 张唯一的 `480×480 RGBA PNG`，稳定路径为 `res://assets/art/buildings/defense_towers/<tower_id>.png`。
- 每张图均以建筑为第一识别主体；动物元素只进入屋脊、檐口、扶壁、甲片、条纹、旗帜、弩、炮或鼓体，没有完整动物站在塔上，也没有眼鼻嘴组成的动物脸。
- 全套复核结果为 `PASS / P0=0 / P1=0`。10 张图的 Alpha 极值均为 `(0,255)`，24px 四角透明，视觉中心 `239.5～240`，统一基线 `438`；在 `48/56/64/96px` 小图及浅色、深色底上均可区分。
- 正式生产整板：`output/visual_concepts/defense_towers_v3/defense_towers_production_board_a.png`，SHA-256 `FD82FE002BA144C7DDE14F803DBC2DC7B5D910C2D863046F03E21CA2290E7D60`。
- 评审整板：`output/visual_concepts/defense_towers_v3/defense_towers_production_board_a_review.png`，SHA-256 `75FE34EC7841DBA25CC266DE59F14ECDFBC67A8A69C95F48137B17F11E93BCF4`。
- 运行时资产清单：`assets/art/buildings/defense_towers/manifest.json`，SHA-256 `196A11E245B10C7EBE100186C8089EC63DA4340956BA5598B967222552A21F83`。

## Godot 代表切片

- 代表塔：`defense_twinshot_tower`（鹦鹉双弩塔）。
- 运行环境：Godot `4.6.2`、Vulkan Forward+、`NVIDIA GeForce RTX 4060 Laptop GPU`、画布 `720×1280`。
- 卡牌详情：真实塔图按方形 contained 规则绘制，无拉伸；最终属性和完整技能描述继续显示。
- 战场建成态：通过 `tile.site_card -> card.art_path` 显示正式塔图；塔底与血条仍邻接，未出现新图向上漂移。
- 未解锁塔继续显示通用黑灰建筑；空 `site_card`、缺图和旧存档回退通用塔，不会误用兔子或任意动物图。
- 纹理在进入战斗前预热并缓存；战场逐帧绘制路径不执行图片解码、像素扫描或 Alpha 检测。

## 十塔玩家可见证据

| 证据 | 结果 | SHA-256 |
| --- | --- | --- |
| `output/qa/F-ZC-DEFENSE-TOWER-005/runtime-art-a/defense_towers_runtime_card_catalog_720x1280.png` | 10 座塔卡牌与属性/技能实机目录 | `984B624C8F7431136DBB91940DBA22E4781EFCEC91F61FDFF5308468C351D3B4` |
| `output/qa/F-ZC-DEFENSE-TOWER-005/runtime-art-a/defense_towers_runtime_battle_catalog_720x1280.png` | 10 座塔战场建成态、血条和详情实机目录 | `22F5E73A725305C6E1A15A1CE908D5E2DEC0744AA0BADAD9D7C3D45CFBB921BB` |

原始 20 张 `720×1280` GPU 截图保留在 `temp/qa/F-ZC-DEFENSE-TOWER-005/runtime-art-a/catalog/`，不作为提交资产。

## 范围边界

- Android 真机：`not_run`。
- APK：`not_requested`，本次不打包。
- 服务器部署与远程写入：`not_requested`。
