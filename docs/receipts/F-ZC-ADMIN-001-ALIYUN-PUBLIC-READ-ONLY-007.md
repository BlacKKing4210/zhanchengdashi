# F-ZC-ADMIN-001 阿里云公网部署只读回执 007

## 状态

- 请求：`REQ-20260820-ADMIN-DASHBOARD-ALIYUN-PUBLIC-007`
- 功能：`F-ZC-ADMIN-001`
- 状态：`READY FOR READ-ONLY REMOTE BASELINE`
- 执行级别：`L3`
- 唯一负责人：`codex-primary`
- 远程目标：阿里云上海轻量应用服务器 `OpenClaw-ejrr`
- 环境：仅 `staging`
- production 写入：禁止

## RAG 与控制门禁

- RAG：`READY`，64 个正式来源、890 个片段、16/16 golden queries，9 条本请求引用；已在制作人 2026-08-21 继续交付指令后刷新。
- index signature：`c65246e64017c4737c0d266e5e58d7156fe2b448be144b25a211adb585881087`
- task fingerprint：`3C3E15B4A74605768D06F5C697A73089BC81AC015C203FC7FB4380A07BE909AF`
- 冲突任务：无。
- 共享锁：`admin_dashboard_aliyun_public_20260820`，状态 `HELD`。

## 已批准目标与边界

- 目标是阿里云 staging 上常驻后台，通过公网受信任 HTTPS 访问。
- 允许部署并验证已封存的 Node 后台与 Linux 专用服候选；允许 JungleLaw 相关版本化目录、状态投影、命令队列、systemd unit、证书续期和必要端口变更。
- 允许在维护窗口内优雅重启 JungleLaw 与后台服务。
- 禁止修改 OpenClaw、Fisher 和 production；禁止删除现有云快照；禁止手工改权威账号 JSON；禁止在仓库、回执、日志或聊天中保存密码、私钥或令牌。

## 本地封存基线

- Node ZIP：`build/admin-dashboard/JungleLaw-admin-dashboard-v1.1.2-local-runtime-only-rc2.zip`
  - SHA-256：`3D793F6326E67A17D7239619086DD736A91C6A0020790E010A77D1FAA38BF727`
- Linux tar.gz：`build/linux/JungleLawServer-v1.1.3-local-linux-rc1.tar.gz`
  - SHA-256：`88C3B339FB1933A8B648E1C73B938B86A87B1AC5058A44F7B7138BE039ED3B0D`
- 本地发布准备：`LOCAL_RELEASE_PREPARATION_COMPLETE / NOT DEPLOYED`。

## 公网 HTTPS 决策

- 当前无自有域名，采用固定公网 IPv4 `106.15.61.103` 的受信任 IP 地址证书方案。
- Let’s Encrypt 已在 2026 年正式开放 IPv4/IPv6 地址证书；IP 证书为约 6 天短期证书，必须自动续期。
- Certbot 5.4+ 支持 `--ip-address`、`shortlived` profile 与 webroot；正式启用前必须在远端只读确认端口 80 的现有 Nginx webroot，避免中断或改写 OpenClaw 配置。
- 参考：`https://letsencrypt.org/2026/01/15/6day-and-ip-general-availability`、`https://letsencrypt.org/2026/03/11/shorter-certs-certbot`。

## 远程写入前必须取得的只读证据

- 实际 SSH/控制台执行身份、主机指纹、OS、systemd、Node、Python、Nginx、磁盘和端口状态。
- JungleLaw 现有 unit、可执行文件、状态目录、账号 authority、快照、命令目录的路径、所有者、权限、版本与哈希。
- Nginx 当前 server blocks 与 ACME webroot；确认不会覆盖或重启 OpenClaw。
- 备份目标空间足够；创建前记录现状，部署前生成同机版本化备份、SHA-256 清单和隔离恢复演练。
- 阿里云防火墙仅增加后台所需端口；SSH 和其他业务端口保持现状。

## 验收

1. 公网 HTTPS 证书受信任，外部网络可打开后台。
2. Owner 账号可以登录；弱口令不得部署，密码只经交互秘密通道初始化。
3. 动物页显示平均名次、样本/置信度与平衡复核信号；没有样本时诚实显示不足。
4. 阵容页展示全部投影账号的已保存阵容。
5. 定向与全服资源命令经过 Owner 二次认证、确认文本、CSRF 与幂等控制，且由游戏服消费并留下收据。
6. systemd 服务、证书续期、进程、端口、日志、健康检查和权限通过；一次优雅重启后数据与登录保持。
7. 回滚包可验证，回滚步骤不删除队列或权威数据。

## 可复用方法审查

`reusable_method_candidate: none`
