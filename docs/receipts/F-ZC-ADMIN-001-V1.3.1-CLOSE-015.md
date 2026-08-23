# F-ZC-ADMIN-001 v1.3.1 完成回执

- Request ID: `REQ-20260823-ADMIN-DASHBOARD-V1.3.1-GRANT-CTA-PLAYER-NAME`
- Feature ID: `F-ZC-ADMIN-001`
- Version: `v1.3.1-aliyun-staging-rc1`
- Date: `2026-08-23`
- Producer: `user-producer`
- Accountable owner: `codex-primary`
- Target: Alibaba Cloud staging `OpenClaw-ejrr`, JungleLaw admin Node overlay only
- Public endpoint: `https://106.15.61.103/`
- Result: `COMPLETE WITH DECLARED PLAYER-NAME AND LIVE-GRANT LIMITS`

## 结论

资源发放按钮不可见的问题已经修复并部署。桌面端把玩家表与发放操作卡并列，操作卡保持在右侧；移动端把操作卡放到玩家表之前，并将资源类型与数量并排压缩。按钮始终存在：未选玩家时显示“请先选择玩家”并禁用，选中两个玩家后显示“向已选 2 人发放资源”。本次没有提交任何真实资源指令。

玩家选择表现在直接显示玩家名称、完整玩家 ID、段位/Elo、抽卡券和阵容卡数；角色页也使用“玩家名称 / ID”。前端搜索支持玩家名称、完整 ID 和脱敏账号。Node 仅白名单接收 `username`，不暴露登录账号字段。

## 根因与修复

1. 旧页面先渲染带内部滚动的完整玩家表，再渲染资源表单，导致主按钮落在截图首屏以下。v1.3.1 将操作卡提升到首屏布局，并保留清晰的选择状态和主按钮禁用/启用状态。
2. 线上 30 条账号投影和权威账号记录均没有 `username` / `display_name`，且脱敏账号统一为 `device-account`，因此无法靠既有数据区分玩家。v1.3.1 优先显示未来投影提供的用户名；当前旧账号使用基于完整 user_id 后四位生成的稳定 `新玩家XXXX`，并明确标记“系统临时名称”。
3. 本地游戏投影合同虽允许 `username`，但旧 Node 清洗器与前端没有贯通该字段。v1.3.1 已补齐只读白名单、展示和搜索链路；没有迁移或写回线上账号权威。

## 自动化与浏览器证据

- `node --check tools/admin_dashboard/public/app.js`: PASS。
- `node --test tests/admin_dashboard/dashboard.test.mjs`: `25/25 PASS`；覆盖用户名白名单与凭据不泄露、名称搜索、玩家明细、多选一次提交、按钮结构和响应式布局。
- 桌面 Chrome `2048x1100`: 选中两名玩家后按钮启用并完整可见；操作卡位于玩家表右侧；无横向溢出。截图：`output/qa/F-ZC-ADMIN-001/v1.3.1-grant-cta-player-name/grant-page-desktop.png`，SHA-256 `81940D8748258999ECFAA7ED9EC267360D0BCC912A647C24836A5C8945926CEB`。
- 移动 Chrome `390x844`: 操作卡在玩家表之前；按钮完整可见；无横向溢出。截图：`output/qa/F-ZC-ADMIN-001/v1.3.1-grant-cta-player-name/grant-page-mobile.png`，SHA-256 `3C8BFF5F0B9D264F2E07F2A2DDFB36761CDD02A75CAE884BA39E383A0EDE20D5`。
- 浏览器验收使用隔离夹具与合成账号，只检查选择和按钮状态，`submission_performed=false`。

## 正式文档

- `docs/ADMIN_ANALYTICS_DASHBOARD_DESIGN.md` 与可编辑 Word `docs/ADMIN_ANALYTICS_DASHBOARD_DESIGN.docx` 已同步到 v1.3.1。
- DOCX 结构检查：401,965 bytes、184 个段落、23 个表格、3 个内联图形、1 个分节；包含 v1.3.1、玩家名称与首屏合同；未包含后台密码。
- 可访问性审计：High `0`、Medium `0`、Low `0`。
- 当前工作站没有 LibreOffice/soffice，无法完成 DOCX 页 PNG 渲染目检；因此不宣称 Word 视觉渲染门禁通过。DOCX SHA-256 为 `4264F2528E3C14446537E5B11C5F372F313640C2507B11C2F5A3977502E85CAF`。

## 阿里云 staging 部署证据

- Artifact: `JungleLaw-admin-dashboard-v1.3.1-aliyun-staging-rc1.zip`
- Artifact SHA-256: `5168f3ee52ec19ce1f1e9905898d56f79e810c0295acb328b412e8f273ca977b`
- Manifest: schema 1，21 个白名单条目，远端逐文件大小和 SHA-256 复核通过。
- Deployed release: `/opt/junglelaw-admin/releases/JungleLaw-admin-dashboard-v1.3.1-aliyun-staging-rc1`
- Current pointer: `/opt/junglelaw-admin/current` 已原子切换到该 release。
- Backup: `/var/backups/junglelaw-admin-dashboard/admin-dashboard-predeploy-JungleLaw-admin-dashboard-v1.3.1-aliyun-staging-rc1-20260823T102538Z`；`payload.tar.sha256` 和 `receipt.sha256` 均通过。
- 只重启 `junglelaw-admin-dashboard.service`；其状态为 active/enabled、`NRestarts=0`、`ExecMainStatus=0`。
- `junglelaw-server.service`、`fisher-server.service` 与 `nginx.service` 的 MainPID、启动单调时间、NRestarts 与 ExecMainStatus 在事务前后完全一致。
- 公网受信 TLS：根页面 HTTP 200；`/api/health` HTTP 200 且 `ok=true`、`live=true`；带正确 Origin 的错误密码登录 HTTP 401；部署后的 `/app.js` 含玩家名称、完整 ID、多选按钮和移动端紧凑布局标记。
- 后台错误级别日志为空。`/api/health.ready=false` 的既有原因仍是执行器心跳不可观察，并非本次页面修复失败。
- 权威账号 SHA-256 在事务前后保持 `c1fc9cbe4813d2aeb0d264f9e07c2cede959bf66beec4fe13870f75c8af63594`；账号投影 SHA-256 保持 `c57b4eacd3ad952bd1d0e2382adc3012484111edee33de4b099f7c072064a380`。
- 事务验收时 admin state 与 audit 哈希保持不变；随后仅使用虚假账号执行一次受保护的错误密码拒绝测试，未重新输入用户密码。
- `pending=0`、`processed=0`、`failed=0`；没有执行真实资源发放。
- Rollback: `READY_NOT_EXECUTED`，可恢复到 v1.3.0 RC2 及根权限备份。

## 遗留限制

1. 当前线上 30 个旧账号没有真实用户名，页面显示稳定的系统临时名称。要显示玩家自行设置的真实名称，需要另行批准并部署账号身份/游戏服投影升级；本任务没有获得该权限。
2. 为避免改变真实玩家资产，本次没有做真实到账测试；资源执行器心跳可观测性仍是独立后续工作。
3. Production 未获授权，本次仅完成 Alibaba Cloud staging。
4. v1.3.1 的最终 Figma/FigJam 可编辑 UI 源仍未补齐；代码、Word、桌面/移动浏览器证据已完成。

## 锁与状态

- Task status: `COMPLETE`
- Remote write status: `COMPLETE_STAGING_NODE_ONLY`
- Shared lock: `RELEASED`
- RAG: 关闭同步后重新构建并验证；最终签名记录在 task receipt。
