# F-ZC-ADMIN-001 数据后台 v1.2 关闭回执

- 状态：`COMPLETE / ALIYUN STAGING PUBLIC DEPLOYMENT ACCEPTED`
- 请求：`REQ-20260822-ADMIN-DASHBOARD-V1.2-METRICS-GRANTS`
- 环境：阿里云上海轻量应用服务器 `OpenClaw-ejrr`，仅 JungleLaw staging
- 公网入口：`https://106.15.61.103/`
- 完成日期：2026-08-22（Asia/Hong_Kong）

## 部署版本

- Node 后台：`JungleLaw-admin-dashboard-v1.2.0-aliyun-staging-rc2`
- Node ZIP SHA-256：`E99CAEEC5B928FDB15AEB18AE975060ECF06919D2410BEA82D8DE1627008268B`
- Node manifest SHA-256：`08EF352A7D5B1CF26C84984D8C7F31B4291ED971E2569BAC6C8B4BEF78BC83AD`
- Linux 游戏服：`v1.2.0-local-linux-rc1`
- Linux tar.gz SHA-256：`CB94723498D7E7A175304686F5CA72B0CF66745482A5DC89D9CB1D15D5F20267`
- 游戏服 ELF SHA-256：`7F11BC743A3573C8F9EAB7ECF6AADD65C74E7C8720DE80F7FA03ACC8BF1F2B94`
- 当前链接：`/opt/junglelaw-admin/current -> /opt/junglelaw-admin/releases/JungleLaw-admin-dashboard-v1.2.0-aliyun-staging-rc2`

RC1 在任何服务停机、备份或部署写入前即因残留的 Node `1.1.3` manifest 常量安全拒绝，未改变运行环境；修正、重测并重新打包为 RC2 后才执行正式事务。

## 完成内容

1. 所有已完成、已认证且能到达权威服务器的战斗统一进入统计，使用受控 `battle_type` 与 `authority` 字段；经典排位 AI、1v1、2v2、3v3、6 人乱斗及旧数据均有明确类型。
2. 动物统计支持全局/战斗类型筛选，显示平均名次、样本量、置信与平衡审阅信号；当前权威数据为 0 场，页面必须显示样本不足，不生成虚假增强或削弱结论。
3. 角色页显示全部 29 个脱敏账号，可直接进入指定账号资源发放；指定账号使用已登录 Owner 会话和一次性签名预览，一次提交，不再要求密码或 `SEND` 二次输入。
4. 全账号发放仍要求 Owner 密码复验和精确 `SEND TO ALL`，避免一次误点影响全部真实玩家。
5. 阵容库使用紧凑列表；当前 26 个非空已保存阵容，65 个中文卡牌名映射；按存储段位、星级、ELO 和 User ID 稳定排序。
6. 发放任务按命令 ID 合并 `pending/processed/failed`，终态优先；页面只保留最近 30 条简洁结果，不把 `pending` 显示为成功，也不重复展示同一命令。
7. 游戏服每秒轮询命令目录，校验目标、资源、金额、卡牌白名单与幂等键，成功后原子保存账号和回执；重复命令不会重复到账。

## 本地验收

- Node 集成测试：`23/23 PASS`；源包与解压包 JavaScript/Node 语法：`8/8 PASS`；21 个发布白名单文件逐项哈希一致，秘密文件扫描为 0。
- Godot 独立源码树导入通过；目标场景 `7/7 PASS`；GDScript 缩进检查通过。
- Linux x86-64 导出退出 0，硬错误 0；WSL 真实候选验证完成 3 次优雅停服/重启、同一权威数据持久化、错误 token/PID 拒绝、异常锁 fail-closed 和最终清理。
- 部署器 Bash、真实游戏 tar 验签、备份/回滚模型、systemd 239 合同与故障矩阵通过。
- DOCX 结构检查通过：399100 bytes，必需 OpenXML 入口齐全，23 个表格、3 个图形、5 个超链接和 1 个 TOC 域。当前环境没有 LibreOffice，且未再次使用曾挂起的 Word COM，因此本轮没有新增逐页 PNG 视觉渲染证据。

## 阿里云验收

- 事务备份：`/var/backups/junglelaw-admin-dashboard/admin-dashboard-predeploy-JungleLaw-admin-dashboard-v1.2.0-aliyun-staging-rc2-20260822T153210Z`，191889041 bytes；`payload.tar.sha256`、`receipt.sha256` 与隔离恢复演练全部通过。
- `junglelaw-server.service` 与 `junglelaw-admin-dashboard.service` 均为 active/running/enabled，`NRestarts=0`；受控重启后账号权威与 Owner 状态 SHA-256 均不变。
- 公网、不使用 `-k`：首页 HTTP 200；`/api/health` HTTP 200、`ok=true`、`live=true`；错误密码登录为 HTTP 401。
- 正式证书 SAN 精确为 `106.15.61.103`，到期时间 `2026-08-28T05:37:38Z`；续期 timer active/enabled，下一次检查为 `2026-08-23 08:36:01 CST`。
- 部署后错误级 journal 无条目。Fisher PID `9513` 与 nginx PID `48406`、启动时间、unit 和监听指纹均未变化。
- v1.2 脱敏快照：analytics version 3，来源 `all_completed_authenticated_battles_by_type`，60 个动物；account snapshot version 2，29 个账号、26 个非空阵容、65 个中文卡名。
- 旧版未消费的“全部 29 个账号各 99 张抽卡券”指令没有执行，已带 SHA-256 原样保存在 `/var/backups/junglelaw-admin-dashboard/manual-pending-quarantine-20260822T144330Z`。
- 无玩家影响执行器烟测：不存在账号的 1 张券指令在约 1 秒内进入 `failed: invalid_target`；账号权威 SHA-256 保持 `0fbae9b15a51e6aaec523602991333add815cac0d4acde85423c6fc6fe9e2d02`，烟测回执保存在 `/var/backups/junglelaw-admin-dashboard/executor-smoke-v1.2.0-20260822T154500Z`，线上三个队列恢复为 0。

## 安全边界与已声明限制

- 本轮没有向真实账号执行指定账号或全账号资源发放；没有被明确标识的 staging 测试玩家。成功路径由 Godot/Node 自动测试覆盖，线上执行器由无玩家影响烟测覆盖。
- 自动化没有读取、重复输入或改写用户秘密。Owner `tian` 保持 active，认证状态文件在部署和重启前后哈希一致；旧的已公开短密码未使用。用户应继续使用此前已交付的强密码登录。
- `/api/readiness` 仍因健康协议没有独立 executor heartbeat 返回 503；本轮已通过实际队列消费观察执行器行为，但接口字段仍诚实显示 `executor=not_observed`。
- 当前 0 场统计只能证明采集与展示合同已部署，不能据此做数值平衡调整；完成真实对局后才可根据各战斗类型样本给出调整建议。

## 回滚

成功验收后未执行真实回滚。v1.1.3 旧 release、新旧精确备份回执与上传包均保留；触发回滚时必须使用 v1.2 RC2 exact backup ID 和 `--authorize-state-directory-quarantine`，当前完整状态只可移动到 root-only quarantine，不得删除。
