# F-ZC-ADMIN-001 v1.3 多玩家批量发放关闭回执

- Request ID: `REQ-20260823-ADMIN-DASHBOARD-V1.3-MULTI-GRANT`
- Feature ID: `F-ZC-ADMIN-001`
- Version: `v1.3.0-aliyun-staging-rc2`
- Date: `2026-08-23`
- Producer: `user-producer`
- Accountable owner: `codex-primary`
- Target: Alibaba Cloud staging `OpenClaw-ejrr`, JungleLaw only
- State: `COMPLETE / STAGING_PUBLIC_DEPLOYED`
- Public endpoint: `https://106.15.61.103/`

## 已交付结果

1. 资源发放页直接列出当前脱敏账号投影中的全部玩家，并显示完整 `user_id`、脱敏账号、段位/星数/Elo、阵容、资源、卡牌副本、更新时间和 profile revision 等运营数据。
2. Owner 可搜索玩家、逐行勾选、全选当前筛选结果、清空选择，并用一次提交给多个选中玩家发放同一种资源。
3. 单账号继续使用 `target`；2 至 500 个非全量账号使用 `selected`；选择覆盖当前全量账号时自动升级为受强确认保护的 `all`。
4. `selected` 预览冻结排序去重后的精确目标集合；服务端校验目标存在性、预览新鲜度、签名、幂等键、数量边界与审计字段。
5. Godot 执行器把一个 selected 命令作为一次原子权威事务：全部目标验证通过后统一修改并一次落盘，任一失败均回滚内存且不留下部分到账；持久幂等回执阻止重启重放。
6. 页面只把 `processed` 显示为到账成功；pending 合并为单条处理中状态，failed 明确显示最终失败，避免重复 pending 噪音。

## 本地验收证据

- Node.js：`npm test`，25/25 通过，覆盖玩家表、多选冻结目标、1/selected/all 分流、签名预览、陈旧/篡改拒绝、幂等、审计、队列和安全边界。
- Godot 4.6.2：`tests/test_admin_backend_features.tscn` 输出 `ADMIN_BACKEND_FEATURES_TEST_PASS`，退出码 0；日志中的锁冲突、损坏 JSON、未来版本和写失败均为有意验证的 fail-closed 负路径。
- 部署叠层静态验证：`deploy/linux/test_junglelaw_admin_dashboard_deploy.sh` 输出 `Jungle Law admin deployment overlay static verification: PASS`。
- Linux 候选验证：`LOCAL_CANDIDATE_VALIDATION_PASS`；部署前候选经过启动、持久化和重启循环检查。
- DOCX 结构：401042 bytes、184 段、23 表、3 个内嵌图形；完整 User ID 规则存在，未包含用户登录密码明文。
- Node 发布包：`JungleLaw-admin-dashboard-v1.3.0-aliyun-staging-rc2.zip`，SHA-256 `ed1f68526ecb5b1cec9691863de161b47d30c46345d5cc53c5982676730c0b20`。
- Linux 游戏包：`JungleLawServer-v1.3.0-local-linux-rc1.tar.gz`，SHA-256 `626819f8ed906b8be9832b4240bb416dfacc02de0dc72efb977c84fc8cee0b87`。

## 阿里云 staging 验收证据

- 当前发布指针：`/opt/junglelaw-admin/releases/JungleLaw-admin-dashboard-v1.3.0-aliyun-staging-rc2`；部署包中的 `package.json` 版本为 `1.3.0`。
- 游戏 ELF SHA-256：`5318144037f2f81a962c22510ab2764557eca289534bc043b023789495e376f1`。
- `junglelaw-admin-dashboard.service` 与 `junglelaw-server.service` 均为 active/running/enabled，`NRestarts=0`、`ExecMainStatus=0`；证书续期 timer 为 active/enabled。
- 公网根页、`/api/health`、`/app.js` 均返回 HTTP 200；线上脚本包含玩家多选状态、全选当前结果和完整玩家 ID 标记。
- 当前投影：30 个脱敏账号、27 个账号有非空保存阵容、65 个中文卡名映射；动物行 60，当前没有已完成战斗、战斗类型、排行榜或热门阵容样本，因此平衡性结论仍是 `NOT_READY: no battle evidence`。
- 实际命令目录 `/var/lib/junglelaw/admin_commands/{pending,processed,failed}` 中三类 JSON 命令均为 0。
- 权威账号存档部署前后 SHA-256 均为 `c1fc9cbe4813d2aeb0d264f9e07c2cede959bf66beec4fe13870f75c8af63594`；本次验收没有向任何真实玩家发放资源。
- RC2 激活以来两个服务的 error 级别 journal 无记录。

## 备份、失败恢复与回滚

- RC2 部署前根权限备份：`/var/backups/junglelaw-admin-dashboard/admin-dashboard-predeploy-JungleLaw-admin-dashboard-v1.3.0-aliyun-staging-rc2-20260823T040922Z`。
- `payload.tar.sha256` 与 `receipt.sha256` 均通过，备份记录了权威状态、ACL/xattr、管理员状态/审计、TLS、队列、服务基线和共享宿主机指纹。
- RC1 因上传源目录权限导致入口不可读而安全失败；随后按精确备份回执恢复 v1.2，公网健康和权威存档哈希恢复一致。RC2 修正源文件模式，并为恢复健康检查加入有界重试后成功部署。
- 成功验收后未执行回滚；若需回滚，必须使用上述精确备份 ID 与状态目录隔离授权，不得删除权威状态。

## RAG、状态与锁清理

- 最终 RAG 以 `temp/rag/receipts/rag-gate.json` 和 `temp/rag/receipts/tasks/REQ-20260823-ADMIN-DASHBOARD-V1.3-MULTI-GRANT.json` 为机器权威；两者在本回执及最后正式来源写入后重新生成并由控制平面复核。
- `docs/active_scope.yaml` 已将本任务置为 `COMPLETE`，从 `active_batch_tasks` 移除，并把 `admin_dashboard_v1_3_multi_grant_20260823` 标记为 `RELEASED`。
- Reusable method candidate: `none`。

## 已声明遗留限制

1. `/api/health` 为 HTTP 200 且服务 live，但 `ready=false`，因为现有 schema 没有 executor heartbeat；命令存储、账号投影、Owner 和审计 outbox 均 ready。
2. 自动浏览器视觉验收因 Computer Use 无法可靠确认当前 URL 而停止；未继续输入凭据或执行页面操作。公网可访问性与部署脚本标记已验证，但不把它等同于完整桌面/窄屏视觉验收。
3. 当前机器没有 LibreOffice/soffice，DOCX 页级 PNG 渲染验收仍为 `PENDING`；结构检查通过。
4. 按验收边界未对真实账号执行资源发放；到账副作用仅由本地原子事务/持久化测试覆盖，线上保持三个队列为 0。
5. 本次只部署 Alibaba Cloud staging；production 未授权、未写入。
