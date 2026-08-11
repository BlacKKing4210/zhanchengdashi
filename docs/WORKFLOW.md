# 占城大师 Production Workflow

Version: WORKFLOW-3

## Authority

- One accountable producer owns priority, shared-file ordering, and final status.
- Design, engineering, and art owners are long-lived role entrances that may remain dormant until specialist judgment or concurrency is needed.
- Role owners define contracts, monitor their tasks, and accept results.
- Production uses the smallest safe level: direct execution for narrow low-risk work, short tasks for bounded production, and persistent role coordination for cross-domain, shared, high-risk, milestone, or high-concurrency work.
- The PM execution operator monitors and refreshes status in the background but cannot make producer decisions or block otherwise-ready work.

## Adaptive Execution

- L0: inline discussion, status, explanation, or no-write answer.
- L1: direct narrow low-risk execution with reproducible checks.
- L2: bounded short task with separate review.
- L3: activate the responsible persistent role owner.
- L4: ask the producer only for an unresolved material or irreversible choice.

The producer may talk directly with any specialist. Approved decisions return to the control plane as compact receipts; no one asks the producer to repeat the same decision through a relay.

## Mandatory Project RAG

- Load `game-project-rag` before every initialized project request. Only RAG bootstrap or repair may run before the gate.
- Register authoritative project sources in `knowledge/knowledge_manifest.csv`.
- Build the configured hybrid lexical/vector index, authority/feature-aware reranking, and bounded cited context.
- Require every query in `knowledge/golden_queries.csv` and the aggregate recall/pass-rate thresholds to pass.
- Require a fresh `tmp/rag/receipts/rag-gate.json` plus one task receipt whose request ID and feature/system ID match the control-plane intake.
- Let the control-plane checker recompute contract, source, gate, context, and citation hashes before it selects L0-L4.
- Return `NOT READY: game project RAG` for missing, unsupported, expired, conflicting, stale, failed, mismatched, or uncited grounding.
- Rebuild the project gate after active sources change, and rebuild the task receipt for every new request or feature scope.

RAG provides current cited evidence. It does not approve a choice, grant write authority, acquire a lock, or prove behavior. Never index secrets, credentials, personal data, or unauthorized content.

## Requirement Intake

Natural-language producer requests are valid intake after task-specific RAG grounding. File behavior-changing requests into a functional source and corresponding configuration source before implementation when required. Do not ask for redundant confirmation when the requested outcome and identity are clear from approved sources.

## AnySearch Primary Research

- Read formal project sources before external search.
- Use the installed `anysearch` Skill and `https://www.anysearch.com/home` as the primary external discovery method.
- Use general or batch search; call `get_sub_domains` before supported vertical searches and use hybrid general-plus-vertical queries when classification is uncertain.
- Follow decision-critical results to original first-party or authoritative sources. Search results and snippets are discovery evidence only.
- Use GitHub CLI, Jina Reader, Exa, authenticated platform tools, RSS, video tools, or a browser for targeted follow-up or fallback.
- After failed direct, approved proxy, and supported browser attempts, record `DEGRADED: AnySearch unavailable` and the coverage gap.
- Keep raw packets and credentials outside the project. Write only the validated synthesis, citations, dates/versions, conflicts, evidence levels, and unknowns into formal sources.

## Small Feature Planning

Before implementing a narrow single-loop feature, use `game-feature-design-docs` with the simple template. Record one player-facing memory point, three to five observable rules, editable player UE, a low-fidelity in-game UI/UE layout when UI exists, exact configuration sources, boundaries, QA, lead-design review, and producer document review.

Do not let implementation plumbing dominate the plan. Keep Figma, implementation, and QA statuses separate. If the feature grows beyond the simple-template limits, migrate to the general template before implementation continues.

## Work Order

Use `PM/feature_progress.xlsx` as the advancement queue. Higher priority goes first. Same priority uses ascending feature ID. Completed features are last. Skip only for dependencies, shared locks, or safety blockers and record the reason.

## Execution Task Gate

Every task has a passing project RAG gate, one request-specific cited context receipt, one objective, one accountable owner, one primary Skill, one isolated write scope, source baselines, acceptance evidence, cleanup, and close conditions.

The task first records a read-only receipt. L2/L3 receive separate owner review; L1 may combine intake, preflight, and authorization when source, owner, write set, baseline, and acceptance are already unambiguous. Contract READY is not task READY.

## Runtime And Asset Rules

- Final assets already available must be used completely.
- Missing assets may use explicit development placeholders.
- UI may use temporary visuals; non-UI art targets final quality from first production.
- Candidate and not-runtime assets cannot be read by release/runtime code.
- Mechanical art checks may hand directly to a development preview unless the producer requests art review.

## Style-Agnostic High-Quality Visual Production

- Load `game-visual-quality-pipeline` for every player-visible production surface that must look premium or release-ready.
- Preserve the approved project identity. A reference provides hierarchy, craft, feedback, and iteration lessons; it does not silently become the project's art style.
- Approve a visual quality contract and one representative editable style frame or coherent whole-set board before engine integration.
- Integrate one representative screen, scene, action, or feedback loop through the normal runtime path before broad production.
- Resolve every blocking and material issue in target-resolution runtime evidence before `SCALE_OUT_APPROVED`.
- Extract reusable components, tokens, import rules, motion timings, audio priorities, and runtime sampling rules, then review same-use families as whole sets.
- Require exported/player-visible target-build evidence, complete states, performance checks, and zero placeholder leakage for `RELEASE_VISUAL_APPROVED`.

Static designs, contact sheets, generated asset quantity, file existence, import success, and passing functional tests are not runtime visual acceptance.

## Alibaba Cloud Server Deployment

- Deploy all persistent server components only to the producer-owned Alibaba Cloud environment. The workstation is never a server deployment target.
- Local work is limited to source/client development, versioned builds, static checks, unit tests, pure mocks, and short-lived isolated test doubles; it is not deployment evidence.
- Require `production/deployment/aliyun-profile.yaml` before remote work. Return `NOT READY: Aliyun deployment profile` when the exact target, authorization, backup, rollback, or monitoring facts are missing.
- Keep credentials and secret values out of the repository, documents, logs, and chat.
- Prevent release/runtime clients from using localhost, loopback, LAN, or workstation endpoints.
- Use this order: read-only remote baseline, versioned artifact, backup and migration plan, Alibaba Cloud staging/test deployment, remote health/TLS/port/log/version checks, external client/package test, persistence and restart/reboot test, rollback proof, then authorized production promotion.

## Evidence

Real player-visible behavior is preferred. Exit code zero, parsing, file existence, or direct callback tests cannot replace a real behavior requirement.

## Monitoring

Monitor the current batch on a short interval. Refresh the workbook on a slower interval and at accepted milestones. Healthy checks remain quiet. Report exceptions, decisions, playable previews, and completion. When the producer asks for progress, show the feature table and its workbook address.

## Stuck Task Replacement

Inspect files, processes, outputs, and locks. Start a read-only replacement candidate, verify handoff, switch the unique task/role identity, then archive the old task. Never permit dual writers.

## Completion

Verify acceptance, regression, authorized files, placeholder/runtime boundaries, temporary cleanup, process exit, lock release, task archive, workbook update, RAG refresh for changed active sources, reusable-method review, and selection plus fresh context retrieval for the next feature.

After every accepted modification or optimization:

- If no credible common-workflow or Agent Skill method exists, record `reusable_method_candidate: none` and do not request producer-user confirmation.
- If a credible candidate exists, report its recurring problem, reusable method, evidence, proposed target, applicability, non-goals, risks, and expected changes under `通用流程 / Agent Skill 提炼候选`.
- Keep it `PENDING_PRODUCER_CONFIRMATION`; do not modify or install global workflow rules or Skills until the producer-user explicitly approves it.
- Treat approval as scoped to the confirmed candidate and target, then validate the editable source and installed result.
- Do not block closure of accepted project work while a promotion candidate awaits review.
