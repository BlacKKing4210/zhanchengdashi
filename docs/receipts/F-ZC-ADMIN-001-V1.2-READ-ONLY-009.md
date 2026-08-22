# F-ZC-ADMIN-001 v1.2 制作人决策与只读任务回执

- Request ID: `REQ-20260822-ADMIN-DASHBOARD-V1.2-METRICS-GRANTS`
- Feature ID: `F-ZC-ADMIN-001`
- Target version: `v1.2.0-aliyun-staging`
- Date: `2026-08-22`
- Producer: `user-producer`
- Accountable owner: `codex-primary`
- Document class: `IMPLEMENTATION_CONTRACT / MATERIAL`
- State: `PRODUCER_DECISION_RECORDED / READ_ONLY_BASELINE`
- Target: Alibaba Cloud staging `OpenClaw-ejrr`; production remains out of scope.

## 制作人已批准规则

1. 所有完成的战斗都进入统计，不再只统计单一入口或单一模式；每条战斗记录必须保存并展示明确的 `battle_type`。
2. 账号页显示账号权威投影中的全部账号；Owner 可从账号行直接进入该账号的资源发放。
3. 资源发放取消重复的密码重认证和手输确认词。仍保留 Owner RBAC、同源/CSRF、服务器签名预览、目标冻结、幂等键、审计和最终到账回执；页面只保留一次明确的“发送”动作。
4. 阵容库改为紧凑列表；卡牌显示项目配置中的中文名；按账号存储段位从高到低排序，并保留稳定的次级排序键。
5. `pending` 不是成功。必须定位并修复命令未消费的根因；界面默认只显示简洁终态摘要，排队状态只在仍未到账时出现，不堆叠大量重复状态。

## 统计与数据质量边界

- 统计粒度：一个已完成的 battle/match 为一条战斗事实，参与者名次与阵容为子记录。
- 所有统计需按 `battle_type` 可筛选/分组；总览为全类型合计，但不得把不同规则模式误当同质样本给出确定性平衡结论。
- 平衡建议必须继续显示样本量、置信度和观察/复核状态；低样本不自动改数值。
- 历史数据不伪造 `battle_type`。无法可靠推断的旧记录使用明确的 `legacy_unknown`，或保持在旧版本只读边界并声明覆盖起点。

## 安全与非目标

- 不降低登录密码策略，不把任何密码、会话、预览令牌或资源命令秘密写入仓库、日志或回执。
- 不给所有账号执行真实资源群发验收；群发只验证服务器冻结目标数、命令生成和幂等合同。真实到账验收仅使用可明确识别的 staging 测试账号；若没有测试账号则停在不改变玩家资源的验证边界。
- 不修改 Fisher、nginx 站点内容或 production。
- 不把 `queued/pending` 显示成“已到账”。

## 初始来源与基线

- RAG gate: `temp/rag/receipts/rag-gate.json`, signature `17136b2960492d8c7bb4e05320c70f284675db706099053969cd407890c6de26`, 66 sources / 902 chunks / 16 of 16 golden queries.
- Task receipt: `temp/rag/receipts/tasks/REQ-20260822-ADMIN-DASHBOARD-V1.2-METRICS-GRANTS.json`, 8 citations.
- Local baseline commit: `3dd4fe3` (`feat: deploy admin dashboard to aliyun staging`).
- Current deployed endpoint: `https://106.15.61.103/`.
- Previous accepted release: Node `JungleLaw-admin-dashboard-v1.1.3-aliyun-public-rc11`; game server `v1.1.3-local-linux-rc1`.
- Previous accepted data boundary: 60 animals with zero match/placement samples; 29 sanitized accounts; 26 non-empty saved decks.

## Planned write scope

- Formal sources and state: `docs/ADMIN_ANALYTICS_DASHBOARD_DESIGN.{md,docx}`, `docs/active_scope.yaml`, this/read-close receipts, `knowledge/knowledge_manifest.csv`, `production/deployment/aliyun-profile.yaml`.
- Game server: analytics collection/snapshot, account command consumption and their focused Godot tests.
- Admin server/UI: snapshot/account/grant libraries, routes, JavaScript/CSS, Node tests, package version/artifact.
- Release: new versioned Node and Linux candidates, evidence-only task roots, no overwrite of prior candidates.

## Acceptance and evidence

1. Focused and full local tests prove every supported completed battle type is recorded once with a valid type.
2. Account list count equals the sanitized authority projection count and account-to-grant navigation works.
3. Deck list uses Chinese card names and descending stored-rank order with deterministic ties.
4. One-click Owner submission keeps server preview/idempotency/audit protections and reaches `processed` for a staging test account without a duplicate grant.
5. Pending/processed/failed queues reconcile across service restart; readiness observes the executor instead of claiming success from queue creation alone.
6. New versioned artifacts, remote backup/restore drill, staging deploy, service/TLS/health/log checks, external browser login, restart persistence and rollback readiness all pass.

## Current gate

The producer decision is now formally recorded. No project runtime or remote state has been changed by this receipt. Next action is deterministic execution intake, task lock acquisition, and a fresh read-only local/remote baseline.

## 2026-08-22 read-only diagnosis

- The deployed Node release writes each pending command as owner-only mode `0600`. The game service runs as a different user and therefore cannot read the file even though both services share the command group. The executor silently skips the unreadable file, so the command remains `pending` indefinitely.
- The observed all-account command also lacks the executor-internal `all_confirmation` field. After the permission defect is fixed, that command would be rejected rather than applied unless the producer-approved one-click flow still emits this server-to-server contract field internally.
- The deployed game binary and Node release are the expected v1.1.3 artifacts; the queue root and environment paths match. The defect is in the cross-service file and command contracts, not a path mismatch or stopped service.
- Existing analytics only starts for an exactly full authenticated human online roster. AI-filled rooms and local classic/free-for-all completions are therefore absent. v1.2 expands the write scope to the client adapter and a shared analytics contract so every completed, authenticated online-reportable battle is recorded once and labeled by controlled `battle_type`; `analytics_authority` keeps server-authoritative and authenticated-client-reported samples distinguishable.

The read-only diagnosis did not read or print account credentials, authority records, passwords, tokens, or full player identifiers, and it did not mutate the server.

Reusable method candidate at intake: `none`.
