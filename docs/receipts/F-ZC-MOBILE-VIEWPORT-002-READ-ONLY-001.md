# F-ZC-MOBILE-VIEWPORT-002 Read-Only Receipt

## Control result

- Status: `READY_WITH_CONCERNS`.
- Request: `REQ-20260811-MOBILE-GRAY-BARS-FIX`.
- Feature: `F-ZC-MOBILE-VIEWPORT-002`.
- Execution level: `L1 direct_execute`.
- Accountable producer: `producer_user`, established by the direct instruction to remove the phone-package top and bottom gray areas.
- Implementation owner for this bounded write window: `codex_primary`.
- RAG gate: `tmp/rag/receipts/rag-gate.json`, status `READY`, 8/8 golden queries passed, mean recall `1.0`.
- RAG task receipt: `tmp/rag/receipts/tasks/REQ-20260811-MOBILE-GRAY-BARS-FIX.json`, citation count `8`.
- Concern: the project-wide role fields remain unassigned in `docs/active_scope.yaml`; this receipt therefore authorizes only the explicit narrow display fix and does not assign a persistent project role.

## Formal source and observed root cause

- Producer decision source: the current user request plus `docs/receipts/F-ZC-MOBILE-ORIENTATION-001-DECISION-001.md` and its accepted closure receipt.
- Preserved rule: Android remains fixed portrait through `display/window/handheld/orientation=1`.
- `project.godot` uses a `1080 x 1920` viewport, `canvas_items`, and `expand`.
- `scripts/app/main.gd` keeps the `720 x 1280` design canvas uniformly scaled and centered with the smaller axis ratio.
- The same script paints its screen background only inside that fixed design rectangle.
- On a taller phone viewport, the centered design rectangle leaves extra canvas above and below. No project clear color is declared, so those untouched pixels use Godot's default gray clear color.

## Scope, baseline, and ownership

- Starting `project.godot` SHA-256: `272D05F7C4DEBF0B19438B322A1D187D1B22650B179BDBECF5E5AF31CD9101AD`.
- Starting `export_presets.cfg` SHA-256: `EA73D33526A8E644488FBE21B2F1E5E06B13FE68EEDA074A5CCDA6D10CB3C07F`.
- Shared locks declared in `docs/active_scope.yaml`: none.
- Existing unrelated dirty files, especially `scripts/app/main.gd`, are outside this write set and must be preserved.
- Baseline changed during intake: the separate speed-feedback task completed at commit `ef2cd65e98d2e1ca9dba6df5d095ee6824637177`, after which `scripts/app/main.gd` became clean and its final starting SHA-256 was `1374EB1236BB27B8BBE0B02EC0436B74525E5DAFDD2DAB9FDDA25065C9728BAA`.
- Allowed tracked writes after that verified handoff: `project.godot`, a narrow full-viewport background patch in `scripts/app/main.gd`, new focused viewport QA files, and this task's receipts. `export_presets.cfg` remains conditional on local proof that an Android system-bar setting is required.
- Forbidden writes: gameplay/configuration tables, runtime JSON, scenes, art, UI geometry, camera behavior, networking, and unrelated dirty or untracked files.
- Task fingerprint: `F-ZC-MOBILE-VIEWPORT-002+v1+repair+engineering+docs/receipts|export_presets.cfg|project.godot|tests/mobile_viewport`.

## Acceptance

1. Tall portrait viewports no longer expose gray pixels above or below the centered design canvas.
2. The 720 x 1280 UI canvas stays uniformly scaled and centered; no non-uniform stretch, crop, control movement, or touch-coordinate change is introduced.
3. Android stays fixed portrait and no sensor/landscape override is introduced.
4. Focused captures cover at least `1080 x 1920`, `1080 x 2340`, `1080 x 2400`, and `1440 x 3200`, or proportional deterministic equivalents supported by the headless renderer.
5. Project parsing, configuration validation/export, normal smoke, and relevant UI/gameplay regressions remain clean.
6. Any rebuilt APK must be verified from its packaged manifest and archive; a build exit code alone is insufficient.

## Cleanup and close conditions

- Keep only the focused test source and final evidence needed for regression; remove temporary inspection scripts, isolated projects, logs, user data, and rejected captures.
- Do not stage or commit unrelated pre-existing modifications.
- Close with before/after viewport evidence, final hashes, changed-file scope, regression results, Android package status, and `reusable_method_candidate` review.
