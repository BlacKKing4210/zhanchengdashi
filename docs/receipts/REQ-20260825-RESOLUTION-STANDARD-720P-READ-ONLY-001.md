# REQ-20260825-RESOLUTION-STANDARD-720P Read-Only Receipt

## Producer decision and routing

- Request: `REQ-20260825-RESOLUTION-STANDARD-720P`.
- Feature/system: `TECH-RESOLUTION-STANDARD`, revision `v1.0.0-720p-defaults`.
- Accountable producer: `user-producer`, from the direct instruction on 2026-08-25.
- Approved rule: portrait games default to `720 x 1280`; landscape games default to `1280 x 720`. Existing projects with a separately approved resolution are not bulk-overwritten and must be migrated with project-specific runtime acceptance.
- Current-project application: this Godot project remains fixed portrait and changes its viewport and default desktop window to `720 x 1280`.
- Superseded current-project rule: `1080 x 1920` viewport plus `540 x 960` desktop override. Earlier rendering and desktop-fit receipts remain historical evidence only.
- Primary workflow: `game-studio-orchestrator`, `game-project-control-plane`, `game-project-rag`, and `godot-feature-slice-implementation`; `codex-game-studio-default` supplies Godot and QA conventions.
- Owner: `codex-primary`, the current engineering owner. No agent, task, thread, or worktree is created.
- Control-plane result: `READY / L3`, no duplicate or conflicting task IDs; task fingerprint `C5CAA021CD14C84CE3F23F85259C5932D40CEFBFC29B72A3DAA44D33E1B8085D`.
- L3 handling: the same accountable owner performs the bounded implementation, then a separate no-write milestone review reruns the resolution contract, rendering, import, and real-window evidence before closure.

## Fresh grounding and live state

- Project root: `D:\AI\zhanchengdashi`; branch `codex/animal-art-integration-20260811`; starting `HEAD` `4a1bb92e94b689b7a2f4183226b499c0bef795bb`.
- RAG gate: `temp/rag/receipts/rag-gate.json`, SHA-256 `A98A5CE5D7CEDBE31F989B47CF125D5B19072D2012CAB752D16C2200DA08A6A4`, status `READY`, mean recall `1.0`, pass rate `1.0`.
- RAG task receipt: `temp/rag/receipts/tasks/REQ-20260825-RESOLUTION-STANDARD-720P.json`, SHA-256 `8C440DD271C418D089500C683B5E26069EAEB5BC02BB182835676DD55A6FB9DC`, citation count `9`.
- `scripts/app/main.gd` already uses `DESIGN_SIZE = Vector2(720.0, 1280.0)`, so the requested portrait default aligns the engine viewport with the existing UI/layout/input coordinate contract.
- `project.godot` currently requests a `1080 x 1920` viewport and a `540 x 960` desktop override. The override is the direct reason the visible default window is substantially below the requested resolution.
- `window/stretch/mode="canvas_items"`, `window/stretch/aspect="expand"`, and fixed portrait orientation are already correct and will be preserved.
- All declared shared locks in `docs/active_scope.yaml` that touch the intended project files are `RELEASED`. The running Godot editor process is user-owned and must not be closed or restarted.

## Baselines and write boundary

- `C:\Users\76398\.codex\AGENTS.md`: `1A8771FBD1C4EE87E957FCC6DA2DE89C33BC4A07E3386861DC392C0CC840A583`.
- `docs/CURRENT_GAME_DESIGN.md`: `55B6132A7EE0559EEB0FD6C6BB1B233DF66128FDB856100E0408636C9A62C728`.
- `docs/CURRENT_GAME_DESIGN.docx`: `68962675FE0653BECB29E853A004910D42C11A597924A1BBB232BD1C29B1F277`.
- `docs/DEVELOPMENT_WORKFLOW.md`: `1B0DE7E3EC235F8FB39EAA84514CD348CCA5AD38F83F0F19C5B118D46265F167`.
- `knowledge/knowledge_manifest.csv`: `73DBE82347DB9367A51EB64A7162DB18119C8612353CE97032BB2B004FA70BA2`.
- `project.godot`: `4E5F434B9A51E9A9C9A5D592977881035395F64BC31B71435BCED6A6A3B74556`.
- `tests/test_desktop_window_fit.gd`: `497EE68715CF28F3A2A5ECB070768BACA7E770004302E99F1BC56FBCFEFE2AA4`.
- `tests/test_rendering_clarity.gd`: `984F4E80B34481170921E38E8D40A603D8804D65A7628F06CA6D58E9CDDF16C7`.
- Allowed project writes: current design Markdown/Word, development workflow, RAG manifest metadata for the changed active sources, `project.godot`, the two focused resolution tests, a new 720 x 1280 runtime capture, and this task's receipts.
- Allowed user-level write: one concise default-resolution rule in `C:\Users\76398\.codex\AGENTS.md`; it is not part of the project Git commit.
- Forbidden writes: existing art/loading/icon pixels, UI layout, touch mapping, camera, gameplay, configuration tables/runtime JSON, networking, server/deployment files, Android package, existing projects outside this root, historical receipts/captures, and all unrelated dirty files.

## Acceptance

1. `project.godot` declares viewport `720 x 1280`, desktop override `720 x 1280`, fixed portrait, `canvas_items`, and `expand`.
2. The formal current-design source and project workflow declare portrait `720 x 1280` and landscape `1280 x 720`, and explicitly supersede only the old resolution values.
3. The user-level default records the same orientation standards while preserving project-approved exceptions.
4. Focused tests verify the portrait default, the transposed landscape standard, unchanged stretch/orientation, native 720p font/layout scale, and compatibility at lower/higher portrait sizes.
5. Godot indentation, import/parse/startup, focused settings/rendering regressions, mobile full-bleed regression, and a real 720 x 1280 main-window capture pass without new parser/resource errors.
6. The accepted runtime frame contains the top resource bar and bottom navigation simultaneously and is exactly `720 x 1280`.
7. RAG is refreshed after active-source changes; scoped diff, hashes, cleanup, focused commit, and push complete without staging unrelated work.

## Boundary status

- APK/package: `NOT_REQUESTED`.
- Android physical-device acceptance: `NOT_RUN`; engine orientation and rendering regressions do not replace device evidence.
- Existing other game projects: `UNCHANGED`; the global default applies to future/unset targets, while migrations remain project-specific.
