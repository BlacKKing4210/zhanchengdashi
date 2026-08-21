# F-ZC-ADMIN-001 阿里云 staging 只读发现回执

- Request ID：`REQ-20260814-ADMIN-ANALYTICS-ALIYUN-STAGING`
- Feature ID：`F-ZC-ADMIN-001`
- 版本：`v1.1.2-aliyun-readonly-data-baseline`
- 日期：`2026-08-14`
- Owner：`codex-primary`
- 执行级别：`L1`
- 任务指纹：`87E5110D62022D7EE8608DF053193A4CBEFD84799A9D4DD36D8DDC306316C673`
- 当前状态：`READ_ONLY BASELINE CAPTURED / NOT READY FOR REMOTE WRITES`

## 已登记写集

- `production/deployment/aliyun-profile.yaml`
- `docs/receipts/F-ZC-ADMIN-001-ALIYUN-STAGING-READ-ONLY-004.md`

## RAG 与控制面

- RAG gate：`READY`，13/13 golden queries，mean recall@k `1.0`
- 请求上下文：`8` 条可验证引用
- Control plane：`READY`，无重复任务、无写集冲突

## 控制台只读发现

- 账号内没有 ECS 实例；有一台运行中的轻量应用服务器。
- 地域：`cn-shanghai`（华东 2 上海）。
- 实例：`5753aa004b904138a06cc5437df6a468`，名称 `OpenClaw-ejrr`。
- 公网地址：`106.15.61.103`；私网地址：`172.24.58.230`。
- 规格：通用型，`2 vCPU / 2 GiB / 40 GiB ESSD`；控制台观察到约 `0.43 GiB` 内存和 `18.47 GiB` 系统盘已使用。
- 镜像：`OpenClaw 2026.3.3`；现有 OpenClaw 服务必须视为受保护共机业务。
- 绑定密钥对：`junglelaw-deploy-20260722`；本机存在匹配的私钥文件，但尚未读取或输出私钥内容。
- 命令助手已安装，云监控插件运行中。
- 实例未绑定域名；账号域名控制台未返回可用域名记录。
- 防火墙当前包括对全网开放的 TCP `22/80/443/16472` 和 ICMP；后台不得直接复用全网开放规则。
- 快照配额已使用 `3/3`：JungleLaw、Fisher、Xuanxiao 的历史部署前快照。创建新快照会先涉及删除历史快照，属于未授权的破坏性动作。

## 已确认的 staging 主机基线

- 云产品：Alibaba Cloud 轻量应用服务器（SWAS），地域 `cn-shanghai`。
- 实例 ID：`5753aa004b904138a06cc5437df6a468`；实例名称：`OpenClaw-ejrr`；主机名：`iZuf6h2p4ec532poqdbp8kZ`。
- 公网地址：`106.15.61.103`；私网地址：`172.24.58.230`。
- 操作系统：`Alibaba Cloud Linux 3.2104 U12.3 x86_64`。
- 运行环境：Node.js `24.14.0`、npm `11.9.0`、systemd `239`。
- 已观察服务与端口：SSH TCP `22`；nginx active，当前仅监听 TCP `80`；JungleLaw UDP `24567`；Fisher UDP `24568`。
- 已存在目录：`/opt/junglelaw`、`/var/lib/junglelaw`；管理后台服务路径与发布根目录尚不存在。
- 域名与 TLS：未配置域名，未配置 TLS。
- 主机健康：systemd 处于 `degraded`，已知原因为 `kdump` failed。
- 备份能力：快照配额 `3/3`，当前没有可用于本次发布前备份的新快照槽位。
- 共享边界：这是承载多个项目的共机，不能把已有 JungleLaw、Fisher 或 OpenClaw 工作负载当作可覆盖资源。

## 仍未通过的部署门禁

- `producer` 与 `deployment_owner` 尚未指派。
- staging `ssh_alias` 仍为 `pending`；本次未猜测别名，也未修改用户或全局 SSH config。
- 管理后台 service path、release root、健康检查地址、监控与告警负责人尚未定义。
- 无域名、无 TLS，nginx 当前只有 TCP `80`；不满足账号密码后台的生产式安全入口要求。
- systemd 为 `degraded`，必须先确认 `kdump` 失败是否可接受或完成修复决策。
- 快照配额已满；没有经批准的发布前备份和可验证回滚方案。
- 该主机是共享多项目主机，是否批准复用为 staging 尚待 producer 决定。
- `staging_remote_writes` 与 `production_remote_writes` 均保持 `false`；production 环境仍未配置。

## 当前边界

本阶段只登记已确认的非秘密 staging 事实。禁止上传、安装、创建/删除快照、修改防火墙、绑定域名、重启服务、创建账号、写入数据或执行任何生产变更。必须把“复用这台共机服务器”与“购买/指定独立 staging 主机”的风险和成本交给 producer 决定；在上述门禁完成且远程写入被明确授权前，结论保持 `NOT READY`。

## 只读数据质量基线

- 只读聚合检查仅在服务器本地解析三个权威 JSON，输出文件元数据、数量、覆盖率和时间戳；未输出登录名、用户 ID、密码哈希、盐、安装标识、资源余额或阵容内容。
- `player_accounts.json`：权威格式为 `version 2`，共 `24` 个账号/资料记录；`21` 个资料有非空已保存阵容，阵容长度分布为 `0:3、2:1、3:1、8:19`；最近账号更新时间为 `2026-08-14T03:30:35Z`。旧格式没有 `admin_command_receipts`，必须先通过已补回归的 version 3 原子迁移才能启用资源发放。
- `dashboard_snapshot.json`：`version 1`，生成于 `2026-07-23T06:18:28Z`；有 `60` 个动物行，但比赛数、平均名次样本、排行榜、最近比赛和头部阵容均为 `0`。
- `match_analytics.json`：`version 1`，`placement_aggregation_version 0`；有 `60` 个动物记录，但玩家记录和名次样本均为 `0`。
- 数据适用性结论：现有账号权威数据足以证明“全部已保存阵容”存在可迁移来源；现有分析快照不适合做动物平均排名或平衡性判断。必须部署新版游戏服采集链路、完成真实比赛写入，并在达到最小样本阈值后，后台才允许给出增益/削弱建议。
