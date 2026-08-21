# F-ZC-ADMIN-001 Web 数据后台扩展只读收据

- 请求编号：`REQ-20260814-ADMIN-ANALYTICS-RESOURCE-GRANTS`
- 功能编号：`F-ZC-ADMIN-001`
- 记录日期：`2026-08-14`
- 负责角色：`codex-primary`
- 执行等级：`L3`
- 任务指纹：`AD4D0726B9967A7118A7BACFACEEDE4489C0AF726B412C0F0F32A32813D3F6E2`
- 当前状态：`LOCAL IMPLEMENTATION READY / ALIYUN DEPLOYMENT NOT READY`

## 正式来源与基线

- 项目流程：`AGENTS.md`、`docs/WORKFLOW.md`、`docs/project_profile.yaml`
- 当前账号设计：`docs/PLAYER_ACCOUNT_AND_SERVER_PROFILE_DESIGN_v1.5.docx`
- 后台设计基线：`docs/ADMIN_ANALYTICS_DASHBOARD_DESIGN.docx`
- 账号权威存储：`scripts/server/player_account_store.gd`
- 对局统计投影：`scripts/server/match_analytics_store.gd`
- 后台服务：`tools/admin_dashboard/`
- 阿里云门禁：`production/deployment/aliyun-profile.yaml`
- RAG gate：`temp/rag/receipts/rag-gate.json`，状态 `READY`
- 请求上下文：`temp/rag/receipts/tasks/REQ-20260814-ADMIN-ANALYTICS-RESOURCE-GRANTS.json`，10 条引用

## 用户目标

1. Web 端账号密码登录。
2. 查看各动物平均排名，并提供基于样本量、排名与胜率置信区间的只读平衡建议。
3. 查看所有账号保存的阵容，而不是只看 Top 100。
4. Owner 可向指定账号或全部账号发送受支持资源，并获得幂等、审计和处理回执。
5. 最终部署到项目正式声明的阿里云环境。

## 安全与数据边界

- 不把管理员密码、口令哈希、会话令牌、SSH 凭据或私钥写入仓库、文档、日志或命令行。
- 用户给出的 7 位纯数字口令不满足当前最少 12 字符策略；本地实现保留安全策略，远端 Owner 初始化暂停，等待更安全口令或生产者正式接受限制网络例外。
- Web 后台不得读取或修改原始 `player_accounts.json`；仅消费脱敏账号投影，并通过受保护的命令目录向权威专用服提交资源指令。
- 资源指令必须限制资源类型与数量，具备命令 ID 幂等、原子持久化、Owner 权限、CSRF/Origin 校验、全服二次确认和审计回执。
- 平衡建议只提供复核信号，不自动改动 `config/tables/`；全局聚合不足以直接定案，需后续按模式、段位、版本和时间窗口分段验证。

## 获准写集

- `docs/ADMIN_ANALYTICS_DASHBOARD_DESIGN.md`
- `docs/ADMIN_ANALYTICS_DASHBOARD_DESIGN.docx`
- `docs/ADMIN_DASHBOARD_*_FIGMA_v1.1.png`
- `docs/receipts/F-ZC-ADMIN-001-*.md`
- `tools/build_admin_analytics_dashboard_docx.py`
- `tools/start_admin_dashboard.ps1`
- `tools/admin_dashboard/**`
- `scripts/server/player_account_store.gd`
- `scripts/server/match_analytics_store.gd`
- `scripts/network/online_room.gd`
- `tests/admin_dashboard/**`
- 本功能新增的后台、账号存储、统计与部署测试文件
- 本功能新增的 `deploy/linux/` 后台模板；不得填入真实秘密或未批准目标

## 明确排除与并发锁

当前 `REQ-20260814-RENDER-CLARITY-BATTLE-PERF` 持有 `docs/active_scope.yaml`、`knowledge/knowledge_manifest.csv`、`project.godot`、`scripts/app/main.gd` 等共享写锁。本任务不得修改、暂存或覆盖这些文件，也不得清理用户的其他未提交变更。

## 接受标准

- Node 单元/集成/安全测试覆盖登录、RBAC、CSRF、Origin、全部阵容、平均排名与平衡建议、指定/全服资源指令、幂等和审计。
- Godot 侧测试覆盖统计聚合、脱敏投影、命令校验、指定/全服发放、重复命令不重复到账、失败回执和持久化。
- `.gd` 保持项目 Tab 缩进并通过缩进检查和 Godot 解析/测试。
- DOCX 按 Word-only 规则生成、渲染为临时 PNG 并逐页检查。
- 阿里云部署只有在 profile、授权、备份、回滚、域名/TLS 和 SSH alias 齐备后才能执行；本地通过不等于上线完成。

## 当前阿里云门禁

`production/deployment/aliyun-profile.yaml` 的负责人、环境、SSH alias、域名/端口、服务与发布路径、TLS、健康检查、备份、回滚和监控均为空，且 staging/production remote writes 均为 `false`。因此记录：`NOT READY: Aliyun deployment profile`。未执行 SSH、上传、重启或远端写入。
