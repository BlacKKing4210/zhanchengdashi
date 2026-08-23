# REQ-20260823-ACCOUNT-IDENTITY-AVATAR-V2 只读收据

- 请求：重构玩家账号系统，分离账号 ID 与用户名，增加动物及通用卡通人物头像，简化注册登录，并保留账号密码复制能力。
- 功能：`F-ZC-AUTH-001`
- 版本：`v2.0.0-account-identity-avatar`
- 日期：2026-08-23
- 负责人：`codex-primary`
- 任务指纹：`6B5C7A57CEA15A8E9E7E83000D0C17F2AFA5899EE0608783FEB8310F771B4B6D`
- 风险级别：高；跨客户端、服务器权威资料、UI、账号迁移与新视觉资产。
- RAG 状态：READY；控制面门禁时索引签名 `03e20d8bd6483b7085d5465b396af879cf66eaa2cf408f9f48491b3b0ff10880`；16/16 黄金查询通过。
- RAG 请求包：`temp/rag/receipts/tasks/REQ-20260823-ACCOUNT-IDENTITY-AVATAR-V2-001.json`

## 正式来源与基线

1. 制作人本次指令是产品范围来源。
2. `docs/PLAYER_ACCOUNT_AND_SERVER_PROFILE_DESIGN_v1.5.docx` 是现有账号行为与安全基线。
3. `docs/ACCOUNT_SWITCHING_DESIGN.docx`、`docs/INTERNET_ROOM_NETWORKING.md` 是账号切换、设备凭据与公网认证边界。
4. `scripts/server/player_account_store.gd` 是服务器权威账号存储；`scripts/network/online_room.gd` 是 RPC 和会话边界；`scripts/app/main.gd` 是当前玩家账号中心。
5. 阿里云 staging 当前有 30 个实时账号；本任务只准备兼容迁移代码，不读取、传输或改写线上账号数据。

## 外部研究结论

- 采用“设备无摩擦进入、投入后绑定可恢复凭据”的低门槛路径。
- 账号 ID 是稳定登录身份；用户名是玩家可见身份，可以修改且不承担登录唯一性。
- 头像采用有限预设而非自由上传或完整捏脸：复用已批准动物卡面，并先制作 4 个原创通用卡通人物候选整板。
- 复制凭据是本项目的便利功能，但服务器永不返回或保存明文旧密码；明文只存在于创建或重新验证后的客户端前台会话。
- 现有自定义 12000 轮 SHA-256 仅保留兼容性；生产发布仍需版本化的现代密码 KDF、加密传输、登录限速与恢复流程。

## 本版本核心决定

1. `user_id`：服务器生成、不可修改、内部权威主键。
2. `account`：可复制的登录账号 ID；不可作为房间内显示名。
3. `username`：2–16 个字符的玩家显示名，允许重名；服务器过滤控制字符和首尾空白。
4. `avatar_id`：服务器白名单预设 ID；运行时首先开放 12 个现有动物头像。
5. 首次设备账号自动生成登录账号与随机密码；玩家只需设置用户名与头像即可完成注册。
6. 既有账号以账号名或 UserID 生成迁移用户名，以猫头像作为默认值，不改变 UserID、进度、密码哈希或安装绑定。
7. 账号中心提供“复制账号”“复制密码”“复制全部”；密码复制只在本次创建、自动生成或重新登录验证后可用。

## 头像资产门

- 动物头像：直接引用现有 `assets/card_art/animals/` 已批准素材，不复制新像素。
- 人物头像：4 个原创通用卡通人物，参考《模拟人生》的“预设身份与可修改个性”方法，不复制其角色、UI、服装或素材。
- 首先只生成一张高分辨率整板，路径为 `output/visual_concepts/account-avatar-v2/ACCOUNT_AVATAR_HUMAN_OPTIONS_BOARD_v1.png`。
- 整板及其候选单元保持 `NOT_RUNTIME`，必须由制作人书面批准后，下一版本才能冻结哈希、切图、去底、做透明度 QA 并接入运行时。

## 写集

- `PM/feature_progress.xlsx`
- `docs/CURRENT_GAME_DESIGN.md`
- `docs/CURRENT_GAME_VISUAL_CONCEPT_OPTIONS.md`
- `docs/PLAYER_ACCOUNT_IDENTITY_AVATAR_DESIGN_v2.0.docx`
- `docs/active_scope.yaml`
- `docs/receipts/REQ-20260823-ACCOUNT-IDENTITY-AVATAR-V2-READ-ONLY-001.md`
- `docs/receipts/REQ-20260823-ACCOUNT-IDENTITY-AVATAR-V2-CLOSE-002.md`
- `knowledge/knowledge_manifest.csv`
- `output/visual_concepts/account-avatar-v2/ACCOUNT_AVATAR_HUMAN_OPTIONS_BOARD_v1.png`
- `scripts/app/main.gd`
- `scripts/network/online_room.gd`
- `scripts/server/player_account_store.gd`
- `scripts/shared/account_identity_rules.gd`
- `scripts/shared/account_identity_rules.gd.uid`
- `tests/capture_account_identity_v2.gd`
- `tests/capture_account_identity_v2.tscn`
- `tests/test_account_identity_v2.gd`
- `tests/test_account_identity_v2.tscn`
- `tests/test_account_manual_login_entry.gd`
- `tests/test_player_account_store.gd`
- `tools/build_account_identity_avatar_v2_docx.py`

## 验收与边界

- 必须证明旧记录迁移不改 UserID、进度、密码哈希和安装绑定。
- 必须证明登录仍只接受账号 ID 与密码，用户名不承担登录。
- 必须证明身份更新经过服务器会话校验、字段白名单与 revision 冲突控制。
- 必须证明房间和账号切换列表优先显示用户名，并保留必要 UserID 识别信息。
- 必须通过 GDScript tab 缩进、账号存储、RPC、账号 UI、项目解析与玩家可见截图验收。
- 不修改 `config/tables/`，因此本任务不触发配置表导出。
- 不进行阿里云远程写、线上账号迁移、Android 正式包或生产发布。
- FigJam 连接器当前不可调用；可编辑 UE 图门记为 `PENDING`，不得用静态草图冒充最终设计源。
