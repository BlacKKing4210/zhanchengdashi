# F-ZC-ADMIN-001 v1.1.3 本地组合候选只读收据

- Request ID：`REQ-20260815-ADMIN-V1.1.3-LOCAL-BUNDLE-RC1`
- Feature ID：`F-ZC-ADMIN-001`
- 日期：`2026-08-15`
- Owner：`codex-primary`
- 执行级别：`L2`（版本化本地候选、独立可复验）
- 来源分支：`codex/animal-art-integration-20260811`
- Git 基线：`8b52782ab862a6e901df96c4c1f2d9a5c7bed435`
- 当前结论：`READY FOR LOCAL CANDIDATE PRODUCTION / REMOTE WRITES FORBIDDEN`

## RAG 与来源门禁

- Project RAG：`READY`，63 个来源、862 个分块、16/16 golden queries 通过，mean recall / pass rate 均为 `1.0 / 1.0`。
- Index signature：`32b6fe6c6a1ef3c31be9b13b0d9ca88151026df6a898b06976c93d46218f93d4`。
- Gate receipt：`temp/rag/receipts/rag-gate.json`，SHA-256 `2EBD679083B44C9AD369B52F513A7BF68E18FD24869F9E165C031153BF2C5C52`。
- Task receipt：`temp/rag/receipts/tasks/REQ-20260815-ADMIN-V1.1.3-LOCAL-BUNDLE-RC1.json`，SHA-256 `2DFF5B18B35A24523FD68C68589DC53578F7C7010D3EA165A7D6DA04A3365DCE`，8 条可验证引用。
- Context pack：`temp/rag/context/REQ-20260815-ADMIN-V1.1.3-LOCAL-BUNDLE-RC1.md`，SHA-256 `D65247FB92BE8879C48078C00FA1DE4B82B74733332F96DFCCDC613FB7830A15`。
- 正式产品来源：`docs/ADMIN_ANALYTICS_DASHBOARD_DESIGN.docx` v1.1.2、`docs/AUTO_ACCOUNT_250_TILE_AND_UPGRADE_RULE_DESIGN_v1.0.docx`、`deploy/linux/ADMIN_DASHBOARD_DEPLOYMENT.md`、`production/deployment/aliyun-profile.yaml`、`docs/active_scope.yaml`。

## 锁与并发确认

- `REQ-20260814-AUTO-ACCOUNT-250-HEALTH-RULE` 已于 2026-08-15 关闭为 `LOCAL_IMPLEMENTATION_COMPLETE`。
- 共享锁 `auto_account_250_health_rule_20260814` 在 `docs/active_scope.yaml` 中为 `RELEASED`；当前未发现覆盖本候选新输出路径的 `HELD` 锁。
- 本任务只创建全新版本化路径，不覆盖或删除任何旧候选；另一个只读审计任务不拥有这些输出路径的写权。

## 已冻结输入

### Node 后台

- 组件版本保持 `1.1.2`；新候选名固定为 `JungleLaw-admin-dashboard-v1.1.2-local-runtime-only-rc2`。
- `tools/admin_dashboard/public/app.js`：60,511 字节，SHA-256 `B326876827A1AD407D9BB688A80917122EE2744E3507F627A1ABAAA8028A45AB`；玩家排行榜场次读取 sanitizer 输出字段 `games`。
- 其余 Node 运行时继续由 `tools/package_admin_dashboard.ps1` 的固定 16 文件白名单冻结；新包必须绑定当前 `ADMIN_DASHBOARD_DEPLOYMENT.md` 与 `admin_dashboard_preflight.sh`，消除旧 rc1 的 helper 漂移。
- 制作前必须保存完整 Node `13/13` 日志并记录：稳定点之前曾出现一次 owner-login fetch 瞬时失败，随后专项通过、完整单轮通过、连续三轮完整通过；新候选只能以本任务重新执行并保存的稳定轮作为封存证据，不得改写历史为“从未失败”。

### Linux 专用服

- 新候选名固定为 `v1.1.3-local-linux-rc1`；旧 `v1.1.2-local-linux-rc1`、`v1.1.2-local-linux-rc2` 及更早候选全部保留不变。
- 冻结方法：Git 基线归档 + 明确 SHA-256 overlay；禁止从整棵脏工作树直接导出。
- 管理后台、账号权威、资源指令、统计与同步停服组合源：
  - `scripts/server/player_account_store.gd`：`596060ABC9CFEDEC92BA94CA2464FD79920CEB303D90BFE8AD657615E583E36F`
  - `scripts/network/online_room.gd`：`FBB412DB5112997B7DB230F89CF739606636B2C548145B09CDCC0EDCC6BCB844`
  - `scripts/server/server_main.gd`：`7127D2FBEBF75C9168447FB0760A10A59B8231397966129528BD7BE72D2ADBB1`
  - `scripts/server/dedicated_shutdown_control.gd`：`EC21712DABE1CF85333790D33BCB38836CD837EAD4DB849109DE021FAAE788E3`
  - `scripts/server/player_account_lifecycle_lock.gd`：`BAB5A7AC728AFB557F9056211F8580A1641A719CF5324837167EA6E93D9455AE`
  - `scripts/server/match_analytics_store.gd`：`973B67FA7BB51A7C201FAD29BE6A8EE1B9B0F5BC5D18C9BBED14ADD071A7A97E`
- 已关闭 auto-account / 250 地块 / 固定生命成长组合源：
  - `scripts/shared/account_credential_rules.gd`：`0D7BB85804F20DC876884FCC4CBD06B5F9BBFF55E09B6F76C16A53A89BB50DB7`
  - `scripts/app/systems/card_rules.gd`：`E215F721FD7AB3388DE68280D5EA3C12382E6850FD067DF543620CBA52201941`
  - `scripts/app/systems/multiplayer_rules.gd`：`75EA71F4DBC213B1B4A9053A770B05DF3EA8931CE7AAB4B887B30604DE16CD63`
- `online_room.gd` 与 `player_account_store.gd` 使用当前组合哈希，因为它们是 admin 与已关闭 auto-account 两项正式实现的交集；不得回退到旧 RC2 哈希，也不得从旧失败候选恢复。

## 获准写集

- `build/admin-dashboard/JungleLaw-admin-dashboard-v1.1.2-local-runtime-only-rc2.zip`
- `build/admin-dashboard/JungleLaw-admin-dashboard-v1.1.2-local-runtime-only-rc2.manifest.json`
- `build/linux/candidates/v1.1.3-local-linux-rc1/**`
- `build/linux/JungleLawServer-v1.1.3-local-linux-rc1.tar.gz`
- `build/linux/JungleLawServer-v1.1.3-local-linux-rc1.tar.gz.sha256`
- `temp/release/REQ-20260815-ADMIN-V1.1.3-LOCAL-BUNDLE-RC1/**`
- 本收据与后续同请求关闭/发布准备收据。

## 验收与停止条件

1. Node：保存 `node --check`、`13/13` 完整测试、runtime ZIP 16/16 条目/哈希、`--help`、禁入扫描及确定性重复打包证据。
2. Godot：隔离源全工程解析、Tab 缩进、admin/authority/auto-account/map/health/shutdown 相关专项回归全部退出 0，无 SCRIPT/Parse/断言失败。
3. Linux：导出日志正常完成；ELF/header/loopback listener、三次同步 stop + 同数据 restart、raw signal fail-closed、损坏 authority、残留锁、错误 token/PID、端口/进程/临时根清理全部通过。
4. 候选目录必须包含 ELF、manifest、provenance、systemd unit、同步 stop helper、installer、admin drop-in、preflight、静态部署测试与本地 verifier；每项记录 SHA-256。
5. tar.gz 两次独立生成必须字节一致；旧候选不得变化。
6. 任一输入哈希、RAG、锁、测试或清理失败立即停止，不得创建或晋级伪候选。

## 远端边界

本任务不上传、不安装、不启动/重启服务、不改防火墙/域名/TLS、不创建账号、不迁移权威数据，也不提交或推送 Git。阿里云 profile、备份/回滚、域名/TLS、监控、共享主机批准及 `staging_remote_writes` 仍未完成；本地候选通过也只能保持 `LOCAL ARTIFACT VERIFIED / NOT DEPLOYED`。
