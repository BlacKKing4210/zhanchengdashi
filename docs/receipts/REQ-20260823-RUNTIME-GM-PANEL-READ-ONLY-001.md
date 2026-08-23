# REQ-20260823-RUNTIME-GM-PANEL Read-only Receipt

- Request: add an in-game Godot runtime GM popup opened with F2 for resource grant and modification operations.
- Classification: execution request; control-plane level L3 because the change crosses UI, resource rules, shared runtime input, and QA.
- Accountable owner: `codex-primary` in the current task. No separate agent or task is created because the producer did not authorize agent creation.
- Formal source: producer request dated 2026-08-23, recorded by this receipt and the feature contract before runtime implementation.
- Primary skills: `game-studio-orchestrator`, `game-project-control-plane`, `game-project-rag`, `godot-feature-slice-implementation`, and `game-feature-design-docs`; `codex-game-studio-default` supplies Godot/UI/QA conventions.
- Task fingerprint: `5FF3116079430C419B34229719B0750A3CE73FFC35DD85A042B19D353BD6BE25`.
- RAG state: READY, index `e88beb6742d0511cbe88d51093dbe6b6ac264dcb99cbcd3eef2fa7cb52f77cb8`, 16/16 golden queries passed, request context has 8 citations.
- Control-plane result: READY; no duplicate task; no conflicting write lock.

## Baseline

- Git branch: `codex/animal-art-integration-20260811`.
- HEAD before this task: `bdde565e88de90bccf58a30f68d3736c2653a538`.
- `scripts/app/main.gd`: SHA-256 `8d5f38c42b04bfaad3c8f76a3cebe0a51c25f3925e3064932235b0a794135b8e`.
- `docs/active_scope.yaml`: SHA-256 `fb71e6dcb94482d82074fa026504a494ae78c1b9e6d65638664e876a1650c88c`.
- `knowledge/knowledge_manifest.csv`: SHA-256 `9268214b72781b245a98c7cac012bfba06311d270062aa27c02892b56490190b`.
- New design, GM-rule, GM-panel, test, capture, and close-receipt paths were absent at baseline.
- Existing unrelated untracked files remain outside this task and must not be staged or modified.

## Locked write set

- `docs/RUNTIME_GM_PANEL_DESIGN_v1.0.docx`
- `docs/active_scope.yaml`
- `docs/receipts/REQ-20260823-RUNTIME-GM-PANEL-READ-ONLY-001.md`
- `docs/receipts/REQ-20260823-RUNTIME-GM-PANEL-CLOSE-002.md`
- `knowledge/knowledge_manifest.csv`
- `tools/build_runtime_gm_panel_docx.py`
- `scripts/app/main.gd`
- `scripts/app/systems/gm_resource_rules.gd` and generated UID
- `scripts/app/ui/runtime_gm_panel.gd` and generated UID
- `tests/test_gm_resource_rules.gd`, `tests/test_gm_resource_rules.tscn`
- `tests/test_runtime_gm_panel.gd`, `tests/test_runtime_gm_panel.tscn`
- `tests/capture_runtime_gm_panel.gd`, `tests/capture_runtime_gm_panel.tscn`

## Approved behavior and boundaries

1. F2 toggles one modal runtime GM panel in a Godot debug build; Escape and the close button close it.
2. The panel supports integer `add`, `subtract`, and `set` operations for local classic-battle gold, guest-session gacha tickets, guest-session card copies, and guest-session card levels.
3. Card levels are limited to 1-10, derived from the current nine upgrade-cost steps; all other supported resources are limited to non-negative bounded integers. An operation whose result crosses a bound is rejected without mutation.
4. An active online match blocks the panel. Logged-in cloud profiles cannot modify account-backed tickets, card copies, or card levels through this panel. The feature never calls the admin dashboard, account-grant API, online save API, or server profile write.
5. The panel is disabled when `OS.is_debug_build()` is false. It is an internal development tool and is not a release/mobile feature.
6. Invalid, empty, non-integer, or out-of-range input produces visible feedback and no mutation. The UI consumes pointer and keyboard input while modal.
7. Guest meta-resource edits and classic-battle gold edits are session-local; persistence and cloud synchronization are explicitly out of scope.

## Acceptance evidence

- Pure rule tests cover all operations, bounds, invalid input, debug/release, logged-in, local battle, and online-match gates.
- Runtime integration tests open with F2, mutate allowed resources, reject protected resources, refresh displayed values, and close with F2/Escape.
- Godot 4.6.3 parses and starts the project with zero parser errors.
- A 1080x1920 runtime capture shows the actual modal panel over the live game scene.
- Existing classic-battle, account profile, online-room, and GDScript indentation checks remain green.

## Cleanup and close conditions

- Do not modify or deploy server/admin/account-service code.
- Do not commit `.godot`, caches, temporary QA renders, or unrelated pre-existing files.
- Refresh project RAG after formal-source changes, write a completion receipt, mark this task complete, and release the shared lock only after all acceptance evidence passes.
