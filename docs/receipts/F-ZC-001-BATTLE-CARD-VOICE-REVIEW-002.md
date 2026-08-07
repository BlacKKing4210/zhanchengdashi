# F-ZC-001 战斗卡牌信息与技能语音评审回执

- Request ID: `REQ-20260808-BATTLE-CARD-VOICE-007`
- Feature ID: `F-ZC-001`
- Date: `2026-08-08`
- Status: `REVIEW_READY`
- Runtime/UI status: implemented and regression-tested
- Full voice-production status: `Pending producer audio approval`

## 已实现行为

1. 玩家可见的攻击与生命属性统一为攻击爪印、心形图标和数值；不再显示“攻击力/攻击/攻”“生命值/生命/血”等属性标签。
2. 动物卡不单列近战、远程或超远程属性。远程分类只进入技能区；近战不显示分类。原始 `skill_text` 仍是唯一技能说明真源。
3. 战斗中点击 `barracks/hall` 动物营地时，底部显示其 `site_card` 对应动物卡并严格保留 `3.0s`。基地、防御塔和金矿不显示建筑详情，也不伪造动物卡。
4. 技能语音使用独立 `Voice` 总线和单一可中断播放器。新卡请求、离开战斗、重开、结算或关闭音效会停止旧语音；卡片到时隐藏后，已开始的语音可自然结束。
5. 营地被摧毁、换卡或易主时，缓存的卡片和语音立即失效。待审核、缺失资源或空 `skill_text` 安全静默，不阻止卡片显示与战斗。

## 配置与语音制作状态

- 动物制作表共 `60` 行，与 `cards.csv` 的 `60` 张动物一一对应。
- `9` 条代表语音为 `prototype_generated`：`mouse`、`tadpole`、`goat`、`parrot`、`wolf`、`dolphin`、`gorilla`、`eagle`、`elephant`。
- `42` 条有技能描述的语音保持 `pending_review`，尚未生成最终资产。
- `9` 张空 `skill_text` 动物为 `silent_no_player_skill`，不朗读远程分类或杜撰技能。
- 代表资产为离线 Windows OneCore 中文语音切片；只有制作人试听通过后，才允许批量生成剩余 `42` 条并将状态升级为 `approved`。

## 自动化验证

| 验证项 | 结果 |
| --- | --- |
| GDScript tab 缩进检查 | PASS |
| `tools/validate_config.py` | PASS：16 tables / 387 rows |
| `tools/export_config.py` | PASS：16 runtime tables + manifest |
| `tests/test_battle_unit_inspection.tscn` | PASS |
| `tests/test_audio_system.tscn` | PASS |
| `tests/test_classic_battle_regression.tscn` | PASS：5 random-map variants |
| `tests/test_online_startup_bootstrap.tscn` | PASS |
| Godot 4.6.3 OpenGL player-visible capture | PASS |
| Word v1.1 render inspection | PASS：8 pages，页面 1/7/8 抽查无裁切或溢出 |

Godot 部分测试在退出进程时仍报告既有的 `ObjectDB instances leaked` / `resources still in use` 清理警告，但测试脚本、解析和行为断言均以退出码 `0` 通过；本次功能链未出现运行时脚本错误。

## 玩家可见证据

| 证据 | SHA-256 | 验证内容 |
| --- | --- | --- |
| `output/qa/F-ZC-001-battle-card-voice/battle_camp_animal_card.png` | `da844081afe5042c9153d7f1f953bd8fb6f93f0944003d15fc7e835b9dbe25b3` | 营地卡、攻击/生命图标、超远程进入技能区 |
| `output/qa/F-ZC-001-battle-card-voice/battle_selected_animal_card.png` | `3306adae5eba848d2805c94e3aa5ce12f42b45b67b1d9f69ae87ca4ec1a67d91` | 点击动物后的底栏卡、当前/最大生命、无独立射程槽 |
| `output/qa/F-ZC-001-battle-card-voice/deck_animal_card_detail.png` | `be78c802102688a62bbd767e1721341e4d3d989d43324e03dbbdf7c59e607210` | 编组卡详情的统一图标与技能区 |
| `docs/GAME_AUDIO_DESIGN.docx` | `3990df4801197bd296cba794e3fd5ce1a7aa1d70f6c94b55bf70f10c45878e4b` | 可编辑 Word v1.1 评审件 |

## 未关闭门禁

- `RUNTIME_SLICE_APPROVED`：等待制作人试听 9 条代表语音并确认声线方向。
- `SCALE_OUT_APPROVED`：未批准；剩余 42 条不得批量生成或标记为最终完成。
- `RELEASE_VISUAL_APPROVED` / 正式包验收：本次未执行。
