# Project Agent Notes
## Current Adaptive Game Workflow

This is the current common game-workflow rule and takes precedence over later generic workflow wording in this file. Preserve every project-specific rule, approved design, engine constraint, and data pipeline as the project adapter.

Use `game-studio-orchestrator` from the personal `game-studio-agent-workflow` plugin as the primary workflow. Load `game-project-control-plane` for intake, state synchronization, task deduplication, write-lock checks, evidence tracking, and adaptive routing. Keep exactly one accountable producer; the control plane is the producer-facing coordination surface, not a second producer.

Classify requests as discussion, producer decision, execution request, status query, or reusable-method candidate. Use the smallest safe level: L0 inline discussion/status, L1 direct low-risk single-domain execution with reproducible checks, L2 bounded work with separate review, L3 only the needed design/engineering/art owner for cross-domain, shared, high-risk, milestone, or concurrent work, and L4 for unresolved material or irreversible choices. If profile, priority, active-scope, ownership, or write-lock sources are absent, return NOT READY instead of inventing state.

Before any production write, confirm the formal source, owner, primary Skill, task fingerprint, non-conflicting write set, baseline, acceptance, evidence, and cleanup conditions; record a read-only receipt. Use the priority matrix when it exists: higher priority, then ascending feature ID, with skip reasons recorded. Close only with behavior or asset evidence, scoped regression, cleanup, and returned shared locks.

The explicit-user-request rule for agent creation remains absolute: L2/L3 describe the required review or ownership level, but never create, spawn, fork, delegate to, or start an agent, sub-agent, Codex task/thread, worktree task, or execution task unless the user explicitly requests it. Otherwise continue with the current agent or ask for authorization when a separate actor is genuinely required.

`codex-game-studio-default` is supplementary only for engine, art, UI, Sprite Forge, procedural motion, CSV data, and QA conventions; it must not replace this workflow's orchestration order.

## Feature Design Document Standard Default

For every formal game feature, system, activity, UI/UE, or gameplay-subsystem specification, load the globally installed personal Skill `game-feature-design-docs` and use `C:\Users\76398\Documents\Codex\standards\game-design\feature-design-document-standard.md`.

Use `game-feature-design-docs/assets/general-feature-design-template.docx` for general features and `game-feature-design-docs/assets/simple-feature-design-template.docx` for simple features. The same templates are available globally as `artifact-template-game-feature-design-general` and `artifact-template-game-feature-design-simple`.

Treat `B-庇护所.docx` as the general-document reference and `Z-在线奖励.docx` as the simple-document reference. Choose by system complexity, not page count; default to the general template when the feature is new, cross-system, multi-screen, multi-state, configuration-heavy, or interruption-sensitive. The simple template must still contain versioning, TOC, objectives, overview, editable UE flow, exact configuration sources, core logic, boundaries, UI behavior, art/audio/telemetry requirements, related systems, and QA acceptance. If a simple feature grows beyond those limits, migrate it to the general template before implementation continues.

Create final system, UE, swimlane, state, and page-spec diagrams in editable Figma/FigJam with clear PNG/PDF exports linked from the DOCX. Mermaid, ASCII, text arrows, and Visio-only diagrams are drafts, not final planning artifacts. The producer-reviewed Word, Figma/FigJam, and configuration files are the source of truth.

## AnySearch Primary Search Default

For all external information retrieval and research discovery, use the installed `anysearch` Skill and `https://www.anysearch.com/home` as the primary search method. Project files, supplied documents, approved decisions, and other local formal sources still come first when they already answer the question.

- Begin external discovery with AnySearch `search` or `batch_search`.
- For a supported vertical domain, call `get_sub_domains` first and include every required parameter. When domain overlap is uncertain, use a hybrid batch with one general query and the relevant vertical queries.
- Treat AnySearch results and snippets as discovery evidence, not final authority. Follow decision-critical results to the original source and prefer official documentation, official repositories, release notes, standards, research papers, and first-party statements.
- Use GitHub CLI, Jina Reader, Exa, authenticated platform tools, RSS, video tools, or a supported browser as targeted follow-up sources, exact-platform evidence routes, or fallbacks. An AnySearch result that links to a platform does not count as an independent platform check.
- If AnySearch is unavailable, retry the AnySearch route directly, then through the approved local `7890` proxy, then through the supported browser flow. After those attempts, use the existing authorized specialist fallback and record `DEGRADED: AnySearch unavailable`; never claim that AnySearch succeeded.
- Do not send passwords, tokens, private keys, personal data, or project secrets in AnySearch queries. Keep raw search packets under `~/.agent-reach/research/<project>/` or the operating-system temp directory, not in the project.
- Record the query families, AnySearch access state, result URLs, original sources, dates/versions, conflicts, evidence level, remaining unknowns, and the effect on the decision.

## Alibaba Cloud Server Deployment Default

All persistent server-side components for every game project must be deployed to the producer-owned Alibaba Cloud environment. The local workstation is never a server deployment target.

- This includes dedicated/game servers, account/auth services, gateways, matchmaking/ranking services, live-ops/admin APIs, databases, caches, queues, reverse proxies, TLS endpoints, storage/backup workers, and scheduled server jobs.
- Local work is limited to source editing, client development, versioned builds, static checks, unit tests, pure mocks/stubs, and short-lived isolated test doubles. Do not install or leave persistent server daemons, production-like databases, reverse proxies, persistent server containers, certificates, exposed service ports, scheduled jobs, or authoritative server data on the workstation.
- Production-like integration, smoke, persistence, restart/reboot, and release acceptance must target an authorized Alibaba Cloud staging/test or production endpoint. Local mocks, probes, and passing exit codes are not server deployment evidence.
- Release/runtime client configuration must never point to `localhost`, `127.0.0.1`, a LAN address, or a workstation path. Use the approved Alibaba Cloud DNS/domain and ports.
- Before any remote write, load `production/deployment/aliyun-profile.yaml` or its formally declared project equivalent. It must identify the environment, SSH alias, host role/region/OS, domains/ports, runtime/service paths, dependencies, TLS/reverse proxy, health checks, backup, rollback, monitoring, and ownership.
- Keep passwords, tokens, private keys, and secret values out of repositories, documents, logs, and chat. Use SSH agent/config or an approved secret store.
- If the profile, target environment, authorization, backup, or rollback facts are absent, return `NOT READY: Aliyun deployment profile`; do not guess IPs, domains, ports, paths, accounts, or credentials.
- Adding this default does not itself authorize a live deployment. Remote deployment requires an explicitly scoped target, environment, and change authorization.
- Deploy in order: read-only remote preflight and baseline; versioned build artifact; backup and migration plan; upload to Alibaba Cloud staging/test; remote start/restart; health/TLS/port/log/version checks; real external client/package validation; persistence and restart/reboot validation; rollback proof; then production promotion after acceptance.
- Completion evidence must name the Alibaba Cloud environment and deployed version, remote service state, endpoint, health result, relevant logs, persistent-data result, external client/package result, and rollback status.
- Use another server location only when the producer explicitly approves the exception in the project's formal deployment source.

## Mandatory Default Game Workflow

For every game-design, development, UI, art, QA, balance, planning, implementation, monitoring, or release request, use `game-studio-orchestrator` from the personal `game-studio-agent-workflow` plugin as the primary workflow. This applies even when the user asks to use the default workflow, start or continue a game, or take over a project.

Follow its producer-led intake, read-only receipt, explicit write-ownership, feature-priority, preview, acceptance, and completion-evidence flow. Retain this project's specialized rules and artifacts as the project adapter. `codex-game-studio-default` remains supplementary for engine, art, UI, data, motion, and QA conventions; it must not replace the primary workflow.

Never create, spawn, fork, delegate to, or start an agent, sub-agent, Codex task/thread, worktree task, or execution task merely because the workflow mentions a role or a role is unavailable. Do so only when the user explicitly asks to create a new agent or task.

This repository is a game project foundation for `zhanchengdashi`.

## Default Workflow

- Treat tasks as game-development work unless the user says otherwise.
- Use the public workflow at `C:\Users\76398\Documents\Codex\2026-07-03\codex-game-studio-default\outputs\codex-game-studio-general-game-development-process.md` as the upstream game-development process when available.
- Use `docs/DEVELOPMENT_WORKFLOW.md` as this project's adaptation of the public workflow.
- Follow a document-first workflow for every future gameplay, balance, UI, system, or technical change: update the relevant design/workflow document first, then implement the matching game change.
- Deliver user-facing narrative documents as Word `.docx` by default. Markdown may remain as the source-controlled authoring format; PDF is generated only when explicitly requested for fixed-layout, print, signature, or archive use.
- Deliver user-facing table-heavy artifacts as Excel `.xlsx` by default. Small supporting tables may stay inside Word, while runtime CSV/JSON and other machine-readable files remain governed by the project's data pipeline.
- Keep project assets, configuration, scripts, and documents easy to move into Godot, Unity, or Unreal later.
- Prefer data-driven gameplay: design values belong in `config/tables/`, runtime exports belong in `runtime/config/`, and validation belongs in `tools/`.
- Follow the upstream professional art production flow from the public workflow v1.6+ for any visual-direction, concept-art, UI-art, sprite, map, VFX, or presentation-quality change.
- Follow the upstream UI/UE workflow from public workflow v1.9+: formal UI/UE sources must be editable Figma/FigJam links or `.fig` references; draw.io, Axure, XD, Markdown, Mermaid, and static screenshots are drafts or review exports, not final UI/UE sources.
- Before implementing an approved UI effect image or Figma page, require a source reference, design token map, component state matrix, Godot UI plan, responsive/safe-area rules, screenshot parity baseline, and UI QA checklist.
- This project is 2D-first. Art-facing work routes through: Producer -> Creative Director -> Art Director -> Visual Development Artist -> Concept Artist / Environment Artist / UI Artist -> 2D Animation Specialist -> Sprite Forge Specialist -> 2D Technical Artist -> Godot Specialist -> QA Lead.
- Treat Sprite Forge as an execution and handoff role after art direction is approved; it does not replace Art Director, Visual Development, Concept, Environment, or UI Artist judgment.
- For current game visual direction, create multi-version effect images first, save review outputs under `output/visual_concepts/`, document them in `docs/CURRENT_GAME_VISUAL_CONCEPT_OPTIONS.md`, and wait for user approval before implementing engine, UI, or asset changes based on them.
- For current UI effect-image work, route review through Producer -> Art Director -> UI Artist -> UI Programmer -> QA Lead, iterate until P0/P1 issues are cleared, and do not modify runtime UI, scenes, scripts, resource bindings, input logic, or click targets until the user explicitly says to implement.
- For page art upgrades, lock UE completely: page information, layout, click targets, control positions, state meanings, and click feedback timing must remain unchanged. Only 2D visual skin, palette, materials, borders, shadows, icons, and illustration polish may change.
- For skin-only page mockups, derive every preview from the current Godot page coordinates or the approved UI/UE wireframe. Any mockup that adds, removes, moves, renames, or reorders controls, resources, page sections, navigation, buttons, or feedback states is invalid.
- For 2D page art, prefer simple high-quality 2D: fewer shapes, colors, layers, and states; improve proportion, spacing, contrast, material restraint, reusable components, and readability instead of adding complexity.
- For procedural feedback and prototype motion, prefer engine-side tween/animation/shader/particle work before requesting new sequence-frame art.
- Do not copy proprietary names, logos, characters, currencies, layouts, or assets from commercial games.

## Godot / GDScript Indentation Safety

- Treat GDScript indentation as syntax-critical. Godot will fail to parse files that mix tabs and spaces, and a blind tab/space replacement can flatten block structure and create follow-up parser errors.
- Before editing any `.gd` file, check the project's `.editorconfig` `[*.gd]` rule and preserve that indentation style. For Godot projects, prefer Godot's default tab indentation unless the project has a fully enforced alternative.
- If a Godot project changes indentation policy, update `.editorconfig`, CI/check scripts, and all `.gd` files in one focused change. Never partially convert only touched lines.
- After any `.gd` edit, run the project's GDScript indentation check when available and launch/parse the Godot project to verify there are no parser errors before committing.
- When fixing indentation parser errors, restore or compare against the last known-good block structure first, then normalize indentation. Do not use mechanical tab-to-space or space-to-tab conversion without preserving nesting depth.

## Configuration Tables

- CSV source tables live in `config/tables/`.
- Excel `.xlsx` is the default human-facing review/edit format for table-heavy deliverables, but it does not silently replace the existing authoritative CSV source or runtime JSON pipeline. Any workbook-to-CSV synchronization must be explicit and validated.
- `config/schema/config_schema.json` defines fields, types, uniqueness, and cross-table references.
- After any user or Codex change to `config/tables/*.csv`, immediately run `python tools/validate_config.py` and `python tools/export_config.py` in the same task so the generated JSON under `runtime/config/` reflects the CSV before testing, committing, or pushing.
- Godot runtime reads `runtime/config/*.json`, not the CSV source tables directly; never leave CSV edits without the matching runtime export.
- Keep CSV source tables UTF-8 or UTF-8 BOM. If a user-edited CSV is saved as ANSI/GBK, convert it to UTF-8 while preserving the user's values before validating/exporting.

## Git Hygiene

- Keep commits focused and reviewable.
- After each completed modification task, commit the changes and push the current branch to GitHub unless the user explicitly says not to.
- Commit generated runtime config only when it is the expected engine-facing source.
- Do not commit local cache, build output, editor metadata, or engine-generated import caches.
