# F-ZC-ADMIN-001 阿里云公网数据后台关闭回执

- 状态：`COMPLETE / STAGING PUBLIC DEPLOYMENT ACCEPTED`
- 环境：阿里云上海轻量应用服务器 `OpenClaw-ejrr`，仅 JungleLaw staging
- 公网入口：`https://106.15.61.103/`
- 完成日期：2026-08-22（Asia/Hong_Kong）
- Owner：`tian`（`owner`、`active`）

## 部署版本

- Node 后台：`JungleLaw-admin-dashboard-v1.1.3-aliyun-public-rc11`
- Node ZIP SHA-256：`CFF8D8AE8599746D857CD361E7C4AA4CC0054B910DA4254721FDFB9CEF7442D7`
- Node manifest SHA-256：`1E5F1579F85B6D0AC888ED830C0DE0F827EA201B80157430DC05D63DB089BB96`
- Linux 游戏服：`v1.1.3-local-linux-rc1`
- Linux tar.gz SHA-256：`88C3B339FB1933A8B648E1C73B938B86A87B1AC5058A44F7B7138BE039ED3B0D`
- 游戏服 ELF SHA-256：`6D8768B5953EBCEFB5A5B5BFFA6A398CAAD056F1C506F80E9F01D2EF6948C14B`
- 当前链接：`/opt/junglelaw-admin/current -> /opt/junglelaw-admin/releases/JungleLaw-admin-dashboard-v1.1.3-aliyun-public-rc11`

## 安全与可用性验收

- 外部客户端不使用 `-k` 成功访问首页（HTTP 200）与 `/api/health`；返回 `ok=true`、`live=true`，数据快照、账号投影、命令目录、Owner 与审计 outbox 均可用。
- 后台由非 root `junglelaw-admin` 运行；443 仅授予 `CAP_NET_BIND_SERVICE`。实际环境端口与证书健康端口均为 443。
- 正式 Let's Encrypt IP 证书 SAN 精确包含 `106.15.61.103`；发行者 `YE2`；有效期 2026-08-21 13:37:39Z 至 2026-08-28 05:37:38Z；SHA-256 指纹 `C5:46:95:BD:29:2A:4F:14:22:3C:9C:BC:A3:67:17:37:D5:E7:D9:D0:CD:E2:2C:22:12:0C:D2:19:20:B8:B8:2A`。
- `junglelaw-admin-dashboard.service` 为 `active/running/enabled`、`NRestarts=0`；证书续期 timer 为 `active/enabled`，下一次检查为 2026-08-22 08:29:45 CST。
- Owner `tian` 的新强密码通过 SSH TTY 隐藏输入完成轮换，撤销旧会话并写入审计；密码未写入命令行、聊天、日志、环境变量、仓库或磁盘，只交付到用户本机剪贴板。已公开的旧短密码未使用。
- 公网错误密码返回 401；新密码登录返回 `tian / owner`。后台与游戏服各重启一次后，公网登录再次通过。

## 数据与功能验收

- 后台实际读取的 `dashboard_snapshot.json` 为 version 2：60 个动物；动物平均名次、置信区间与平衡提示字段已部署。
- 当前权威比赛数据仍为 0 场、0 个名次样本，因此页面必须显示“样本不足”，不能生成虚假的削弱/增强结论；后续真实对局会自动累计。
- `admin_accounts_snapshot.json` 为 version 1：29 个脱敏账号，26 个账号有非空当前阵容；全部投影账号均可在阵容页查看。
- 指定账号资源发放的服务端签名预览命中 1 个目标；全账号预览命中 29 个目标。验收没有提交真实资源命令，因此 `pending/processed/failed` 均保持 0；这是避免在未确认账号性质时影响玩家的安全边界。提交、二次认证、确认文本、幂等与终态竞态由同一 RC11 源码的 23/23 Node 集成测试覆盖。
- `/api/readiness` 仍因执行器未提供独立 heartbeat 而报告 `executor=not_observed`；`/api/health` 与实际登录可用。不得把这一项误写成“资源执行器已被线上心跳观测”。

## 持久化、备份与回滚

- 后台与游戏服各完成一次受控重启；游戏 UDP 24567、后台 TCP 443、Owner、TLS、快照与账号权威数据均保持可用。
- 账号权威文件在游戏服重启前后 SHA-256 不变；Fisher PID `9513` 与 nginx PID `48406` 均未变化。
- RC11 备份回执：`/var/backups/junglelaw-admin-dashboard/admin-dashboard-predeploy-JungleLaw-admin-dashboard-v1.1.3-aliyun-public-rc11-20260821T165506Z`，`root:root 0700`，约 191,872,369 bytes。
- `payload.tar.sha256` 与 `receipt.sha256` 全部校验通过；完整 canonical server 状态、ACL/xattr、游戏服与后台组件、TLS、队列、启停基线和共享主机指纹均在回执内。prepare 已完成隔离恢复演练。
- 成功部署后未执行真实回滚；旧 release 与精确回执保留。若后续触发回滚，必须使用 exact backup ID 与 `--authorize-state-directory-quarantine`，把当前状态移动到 root-only quarantine，绝不删除。

## 本地发布证据

- Node 自动测试：23/23 PASS。
- JavaScript/Node 语法、CLI `--help`、21/21 manifest 文件、确定性重复打包：PASS。
- Linux/systemd 239 静态检查、备份/恢复、失败恢复、端口切换与故障矩阵：PASS。
- 最终 RAG 与控制面在部署前均为 READY；关闭后需再以本回执、profile 和 COMPLETE scope 刷新最终索引。
