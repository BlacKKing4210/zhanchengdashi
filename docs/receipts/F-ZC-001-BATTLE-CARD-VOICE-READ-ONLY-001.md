# F-ZC-001 战斗卡牌信息与技能语音只读回执

- Request ID: `REQ-20260808-BATTLE-CARD-VOICE-006`
- Feature ID: `F-ZC-001`
- Date: `2026-08-08`
- Producer authority: 当前制作人指令
- Task-scoped unique writer: `/root`
- Read-only reviewers: `/root/ui_interaction_audit`、`/root/voice_audio_audit`
- RAG gate: `READY`，index signature `bf3d0a40ff4036952ed362d12bdf459482fb12e98627a900c803d6cad1ed83cb`
- RAG task receipt: `tmp/rag/receipts/tasks/REQ-20260808-BATTLE-CARD-VOICE-006.json`
- Control-plane result: `READY / L3`
- Task fingerprint: `5B8D46ABD36AE622D2D57030191318DFFEA825110ECB8651819F621155D9CC9D`
- Shared-lock check: 当前 `active_scope.yaml` 无活动任务、无共享写锁；本回执建立本任务写入所有权。

## 已确认的正式规则

1. 玩家可见的攻击力与生命值不再使用“攻/攻击/血/生命”文字标签，统一使用现有攻击图标与心形图标配数字。
2. 动物卡牌不单列“近战/远程”属性。近战不显示范围文字；远程或超远程只在玩家可见技能区加入“远程”或“超远程”。原始 `skill_text` 不被改写，战斗逻辑仍以原始配置为准。
3. 战斗底部不再显示基地、防御塔、金矿等建筑详情。只有 `barracks/hall` 动物营地拥有合法的动物 `site_card` 映射；点击后显示对应动物卡 3 秒。
4. 3 秒只约束卡牌画面。技能语音独立播放到自然结束；新点击、离开战斗、重新开始或关闭音效会中断旧语音。
5. 语音文字以 `cards.csv::skill_text` 为真源。空描述不得从结构化字段杜撰技能；远程但无技能描述的动物可显示范围标签，但不朗读不存在的技能。

## 基线与风险

- 当前共有 60 只动物；51 只有非空 `skill_text`，9 只为空。
- 现有项目无技能语音资产、无 Voice 总线、无独占语音播放器。
- 本机只有可用性不稳定的系统中文 TTS；不能把本机批量合成文件直接宣称为最终风格质量。
- 玩家可见音频规模化仍需先通过代表语音切片试听。本任务先完成数据契约、专用语音播放链路、完整制作状态表和可运行代表切片；未通过试听的批量语音保持 `pending_review`，不得伪报最终完成。

## 写入范围

- 设计：当前游戏设计、音频设计及其 Word 评审件、设计/配置索引。
- 配置：技能语音制作表、配置 schema 与 runtime 导出。
- 运行时：`scripts/app/main.gd`、`scripts/app/systems/game_audio.gd`。
- 资源与工具：技能语音目录、确定性构建工具。
- QA：战斗选择与音频系统测试、关闭回执、最终 RAG 刷新。

## 验收边界

- 逻辑完成不等于语音美术最终通过。
- 只有 Godot 运行时截图/录音、资源可加载、3 秒行为、语音中断和音效开关回归全部通过，才可关闭工程实现；全量语音风格仍需制作人试听批准后进入规模化完成状态。
