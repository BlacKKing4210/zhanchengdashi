# F-ZC-ADMIN-001 v1.3 多玩家批量发放只读回执

- Request ID: `REQ-20260823-ADMIN-DASHBOARD-V1.3-MULTI-GRANT`
- Feature ID: `F-ZC-ADMIN-001`
- Target version: `v1.3.0-aliyun-staging`
- Date: `2026-08-23`
- Producer: `user-producer`
- Accountable owner / current writer: `codex-primary`
- Document class: `IMPLEMENTATION_CONTRACT / MATERIAL amendment`
- State: `PRODUCER_DECISION_RECORDED / READ_ONLY_BASELINE`
- Target: Alibaba Cloud staging `OpenClaw-ejrr`, JungleLaw only; production, Fisher and nginx remain out of scope.

## 制作人已批准结果

资源发放页直接显示当前脱敏账号投影中的每个玩家、完整 `user_id` 和运营所需数据；Owner 可以搜索、逐行勾选并用一次提交给多个选中玩家发放同一种资源。该规则取代 v1.2 资源页的单账号下拉框，但保留角色页直达单账号发放。

## 实施规则

1. 玩家表至少显示：选择框、完整 User ID、脱敏账号、存储段位/星数/Elo、保存阵容数量、抽卡券、卡牌总副本数、更新时间与 profile revision。
2. 搜索只改变当前可见行，不清空已选择目标；“全选当前结果”只作用于当前过滤结果，并提供清空选择。
3. 选中 1 个账号继续使用兼容 `target`；选中 2 至 `N-1` 个账号使用 `selected`；选中集合覆盖当前全部 `N` 个账号时，前端自动使用 `all`。
4. `selected` 预览必须在签名载荷中冻结排序且去重后的精确 `target_user_ids`、目标数和摘要；同一个幂等键只创建一个命令。selected 单批上限为 500 个账号。
5. 服务端拒绝空选择、重复/不存在目标、selected 少于 2 个、selected 覆盖全部账号、超过上限、预览过期或目标缺失。覆盖全部账号必须走 `all`，要求当前 Owner 密码和精确 `SEND TO ALL`。
6. `target` 和 `selected` 使用已登录 Owner 会话、同源/CSRF、一次性签名预览、冻结目标、幂等和审计后一次提交，不额外要求密码或确认词；`all` 继续强确认。
7. Godot 执行器把一个 selected 命令作为一次原子权威事务：所有目标验证成功后统一更新并一次落盘；任一目标、资源或保存失败不得留下部分到账。持久幂等回执防止重启重放。
8. 页面只把 `processed` 显示为到账成功；短暂 pending 仅一条，failed 明确显示失败。任务列表用“多选账号（X 个）”而不是误写为单账号。

## UI/UE 基线

- Source reference: 用户提供的 v1.2 阿里云实时资源页截图 `C:/Users/76398/AppData/Local/Temp/codex-clipboard-d573e188-9225-4995-9193-f74f89f9e875.png`，原始尺寸 `2477 x 1239`。
- 延续已批准的深色暖金、顶栏导航、44px 交互高度、桌面密集表格与窄屏卡片化组件体系；不改变导航顺序、品牌、资源类型、原因、命令回执和全服安全语义。
- Primary decision: 先选择具体玩家，再核对影响人数并提交同一种资源。
- P0: 玩家 User ID/数据、复选框、已选人数、资源/数量/原因、提交和全服强确认。
- P1: 搜索、全选当前结果、清空选择、选择范围说明、loading/empty/error/processed/failed。
- P2: 行内完整阵容详情；继续在阵容库查看，不挤入本页主表。
- P3: 当前右侧大段安全说明；压缩为短护栏，不与玩家表争夺主要宽度。
- v1.3 可编辑 Figma/Penpot 同步：`PENDING`，owner `design_owner`；当前环境没有可调用的认证编辑器。本次是基于现有已批准组件体系和制作人明确实装指令的功能修订，不宣称可编辑设计门禁已完成。

## 本地基线

- Git: `bdde565e88de90bccf58a30f68d3736c2653a538` on `codex/animal-art-integration-20260811`; unrelated untracked files are preserved.
- RAG: `READY`, signature `e88beb6742d0511cbe88d51093dbe6b6ac264dcb99cbcd3eef2fa7cb52f77cb8`, 78 sources / 1107 chunks / 16 of 16 golden queries; this request has 8 citations.
- v1.2 design DOCX SHA-256: `F9C04216DDAF88077310403FB68947DE7D4621D782D046A137ABA0D50E4D6018`.
- `player_account_store.gd` SHA-256: `D5E635513625EBCDD47DDFDBFB71A3ACC4329A82F08B28B9524517058FED29E3`.
- `resource_grants.mjs` SHA-256: `A50A3EC84C7C3A9BCC33B4AB3EE12A619EE33D2C68DECEDA21B21B27358339C6`.
- `app.js` SHA-256: `01C83C8BCAFE9B22245EAF629F1504236621EC19CB03651011634CB78E91AED1`.
- `dashboard.test.mjs` SHA-256: `15702700FF08B49AE888DCED20F4235864A64C88293967DC904D6BF43B33DFDA`.
- All existing shared locks that include these files are explicitly `RELEASED`; `active_batch_tasks` is empty.

## 阿里云只读基线

- Public endpoint: `https://106.15.61.103/`; root and `/api/health` returned HTTP 200 with certificate validation.
- Current Node release: `/opt/junglelaw-admin/releases/JungleLaw-admin-dashboard-v1.2.0-aliyun-staging-rc2`.
- `junglelaw-admin-dashboard.service` and `junglelaw-server.service`: active/enabled, `NRestarts=0`, `ExecMainStatus=0`.
- Sanitized projection: version 2, 29 accounts, 26 non-empty decks, 65 card-name mappings; dashboard projection version 3, 60 animals and 0 completed matches.
- Command queue counts: pending 0 / processed 0 / failed 0.
- Account authority SHA-256: `0fbae9b15a51e6aaec523602991333add815cac0d4acde85423c6fc6fe9e2d02`.
- Service error journal since the v1.2 deployment: no entries.

## Write set and boundaries

Only the v1.3 design/receipt/state/manifest/profile files, resource-grant Node/UI/tests, `player_account_store.gd` with its focused test, versioned package/deployment files and new build candidates are writable. Analytics collection, `scripts/app/main.gd`, `scripts/network/online_room.gd`, game balance/config tables, production, Fisher, nginx, secrets and existing v1.2 releases are forbidden.

## Acceptance

1. Node tests prove exact selected-target signing, stale detection, backward-compatible target, all-scope escalation, idempotency, audit and queue semantics.
2. Godot tests prove selected 2+ succeeds atomically, duplicate command does not credit twice, selected-all and invalid targets fail with zero player mutation, and restart persistence holds.
3. Browser evidence at desktop and narrow widths shows every player row, full User ID, data columns, stable selection/search, selected count, all-scope escalation and state/error layouts without overflow.
4. Packaging, manifest hashes, secret scan, installer/deployment fault tests and isolated Linux export pass.
5. A new remote backup precedes deployment; exact staging versions, services, TLS, health, logs, persistent authority across restart, queues and rollback readiness pass.
6. No live resource command targets a real account during acceptance. If no explicitly identified staging test player exists, online validation stops at read-only projection plus nonexistent-target failure smoke; authority hash must remain unchanged.

Reusable method candidate at intake: `none`.
