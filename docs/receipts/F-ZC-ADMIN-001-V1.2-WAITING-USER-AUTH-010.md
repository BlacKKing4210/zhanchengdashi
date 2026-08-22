# F-ZC-ADMIN-001 v1.2 暂停与写锁释放回执

- Request ID: `REQ-20260822-ADMIN-DASHBOARD-V1.2-METRICS-GRANTS`
- Feature ID: `F-ZC-ADMIN-001`
- Target version: `v1.2.0-aliyun-staging`
- Date: `2026-08-22`
- Accountable owner: `codex-primary`
- State: `WAITING_USER_AUTH / PAUSED_NOT_DEPLOYED`
- Remote target: Alibaba Cloud staging `OpenClaw-ejrr`
- Remote write status for v1.2: `NOT_STARTED`

## 暂停边界

本轮只同步任务状态和共享写锁，不上传制品、不修改远端文件、不启停或重启服务、不修改证书、防火墙、端口或玩家数据。v1.2 等待制作人对 `OpenClaw-ejrr` staging 维护动作的明确授权后再恢复部署。

当前本地工作树包含未完成的 v1.2 改动，不能视为已验证、已打包或可部署版本。释放路径只表示本任务不再独占这些文件，不表示回退或批准现有差异；后续写入者必须先检查并保留工作树中的已有改动。

## 已释放的共享路径

- `scripts/app/main.gd`
- `docs/CURRENT_GAME_DESIGN.md`
- `tests/test_all_battle_analytics.gd`（本次暂停时尚未创建）
- `tests/test_all_battle_analytics.tscn`（本次暂停时尚未创建）
- `scripts/server/match_analytics_store.gd`
- `scripts/server/player_account_store.gd`
- `scripts/network/online_room.gd`
- `scripts/shared/battle_analytics_contract.gd`
- `scripts/shared/battle_analytics_contract.gd.uid`
- `tests/test_match_analytics_store.gd`
- `tests/test_online_room_analytics.gd`
- `tests/test_admin_backend_features.gd`
- `production/deployment/aliyun-profile.yaml`
- `build/linux/`
- `docs/active_scope.yaml`（本回执和状态同步完成后释放）
- `knowledge/knowledge_manifest.csv`（本回执登记完成后释放）
- `docs/receipts/F-ZC-ADMIN-001-V1.2-READ-ONLY-009.md`
- 本暂停回执本身

其中 `docs/CURRENT_GAME_DESIGN.md`、`scripts/server/match_analytics_store.gd`、`scripts/shared/battle_analytics_contract.gd` 和其 UID 在暂停时存在未提交差异；未作清理、覆盖或回退。

## 仍保留的 write_set

- `docs/ADMIN_ANALYTICS_DASHBOARD_DESIGN.docx`
- `docs/ADMIN_ANALYTICS_DASHBOARD_DESIGN.md`
- `tools/admin_dashboard/package.json`
- `tools/admin_dashboard/lib/account_snapshot.mjs`
- `tools/admin_dashboard/lib/resource_grants.mjs`
- `tools/admin_dashboard/lib/snapshot.mjs`
- `tools/admin_dashboard/lib/state_store.mjs`
- `tools/admin_dashboard/server.mjs`
- `tools/admin_dashboard/public/app.js`
- `tools/admin_dashboard/public/styles.css`
- `tests/admin_dashboard/dashboard.test.mjs`
- `tools/build_admin_analytics_dashboard_docx.py`
- `tools/package_admin_dashboard.ps1`
- `build/admin-dashboard/`

上述剩余锁只保护尚未收口的 Web 数据后台实现、设计合同、测试与 Node 候选包；共享游戏逻辑、客户端入口、Godot 测试、部署 profile 和 Linux 候选不再由本轮占用。

## 明确非范围

本轮没有修改或实现战斗信息卡、锁敌或与该需求相关的任何代码、配置、文档和测试。

Reusable method candidate at pause: `none`.
