# REQ-20260823-DESKTOP-WINDOW-FIT Read-Only Receipt

## Control result

- State: `READY`; the control-plane checker returned `L1 direct_execute`, no duplicate, no conflict, and final scoped task fingerprint `46B525D4B7D06D6C01289931A7376125A3F3B8330B4A384DAD8304575797000A` after this formal source was recorded.
- Request: `REQ-20260823-DESKTOP-WINDOW-FIT`.
- Feature/system: `F-ZC-MOBILE-VIEWPORT-002`, desktop debug-window follow-up `v1.1.0-desktop-window-fit`.
- Accountable producer: `user-producer`, from the direct request to make the project open fully without manual resizing.
- Implementation owner: `codex-primary`, the current engineering owner in `docs/active_scope.yaml`.
- Intended execution: `L1 direct_execute`; narrow, reversible, single-domain settings repair with reproducible GUI and project-setting checks.
- Task fingerprint: `46B525D4B7D06D6C01289931A7376125A3F3B8330B4A384DAD8304575797000A`.
- Project root: `D:\AI\zhanchengdashi`; branch `codex/animal-art-integration-20260811`; starting `HEAD` `bdde565e88de90bccf58a30f68d3736c2653a538`.

## Grounding and live state

- RAG gate: `temp/rag/receipts/rag-gate.json`, SHA-256 `AA6356E2EE227434BB90EED5213E337E00C7377572AB24B74D270C0063E31ADA`, evaluation pass rate `1.0`, mean recall `1.0`.
- RAG task receipt: `temp/rag/receipts/tasks/REQ-20260823-DESKTOP-WINDOW-FIT.json`, SHA-256 `6FE59B0F0D5E8C804F9FDA07483AFDD5B8E21D19E28AE1A87CCCCEBE9885B1C5`, citation count `8`.
- The feature workbook `PM/feature_progress.xlsx` has no matching `F-ZC-MOBILE-VIEWPORT-002` row. This task is a direct producer repair request, not automatic advancement of a workbook candidate.
- Active tasks hold `scripts/app/main.gd`, `docs/active_scope.yaml`, `knowledge/knowledge_manifest.csv`, and admin/GM-panel files. None holds `project.godot`, `docs/DEVELOPMENT_WORKFLOW.md`, or the new focused QA files.
- The running Godot process is the editor for this project. Do not close it or alter editor state; verify the `project.godot` baseline immediately before and after the write to detect external drift.

## Observed root cause

- User screenshot: `C:\Users\76398\AppData\Local\Temp\codex-clipboard-883e2561-82e4-4912-8697-c2d6d6c80579.png`, SHA-256 `E84E5A9A4561306AA8AE7CEDE62EDB5D092F6A0C44E904DCAE8FE4D1BCACA3B0`.
- `project.godot` defines a `1080 x 1920` portrait viewport but no `window_width_override` or `window_height_override`. On desktop, the initial game window therefore requests the full 1920-pixel height.
- Current Windows physical usable area is `2560 x 1528`.
- Isolated Godot `4.6.3.stable` GUI reproduction with the current settings produced `window=1080 x 1570`, `viewport=1320 x 1920`, and `fits_usable_area=false`; the OS/engine clamp still leaves the window taller than the usable area.
- An isolated settings-only candidate using desktop override `540 x 960` produced `window=540 x 960`, `viewport=1080 x 1920`, and `fits_usable_area=true`.
- The candidate changes only the initial desktop window size. It preserves the formal `1080 x 1920` viewport, `canvas_items`, `expand`, fixed portrait orientation, UI geometry, touch conversion, camera, gameplay, and mobile full-bleed repair.

## Baselines and write boundary

- Starting `project.godot` SHA-256: `9D891D5492E6E6D8A6442E4F57BC6563EEF93BD64399A223CD81BA474AC46430`.
- Starting `docs/DEVELOPMENT_WORKFLOW.md` SHA-256: `1873D34A9EBA5306E7FC68D29F7E8175913E0B4F44CEAE06CBD4E731899FDDBC`.
- Starting `docs/active_scope.yaml` SHA-256: `0B9279056053919D550CAD3B9C2068F2F7EBA473AA86D14793A338CEACDD9A86`; this file is locked and forbidden for this task.
- Allowed tracked writes: `docs/DEVELOPMENT_WORKFLOW.md`, `project.godot`, `tests/test_desktop_window_fit.gd`, `tests/test_desktop_window_fit.tscn`, `output/qa/F-ZC-MOBILE-VIEWPORT-002/desktop_window_fit_540x960.png`, and this task's read-only/completion receipts.
- Forbidden writes: `docs/active_scope.yaml`, `knowledge/knowledge_manifest.csv`, `scripts/app/main.gd`, scenes, UI layout, input/touch logic, camera, gameplay, configuration tables/runtime JSON, assets, networking, server/deployment files, build packages, and all unrelated dirty files.
- Temporary evidence root: `temp/qa/REQ-20260823-DESKTOP-WINDOW-FIT`; retain only the accepted real main-window PNG under `output/qa/F-ZC-MOBILE-VIEWPORT-002/`, then remove scripts, isolated user data, caches, junctions, logs, and rejected captures before close.

## Acceptance

1. A normal desktop launch opens at `540 x 960` client size and fits inside the current `2560 x 1528` usable desktop area without manual resizing.
2. The full main page is visible in a real Godot GUI capture; the top resource bar and bottom navigation are both present in the same frame.
3. The internal project viewport remains `1080 x 1920`; `canvas_items`, `expand`, `window/handheld/orientation=1`, and the mobile clear-color/full-bleed behavior remain unchanged.
4. A focused settings regression verifies both overrides, the 9:16 ratio, the unchanged viewport/stretch/orientation values, and the fact that the desktop override is smaller than the design viewport.
5. Godot import/parse, focused desktop-window QA, mobile full-bleed regression, and a normal main-scene smoke complete without parser/resource failures attributable to this change.
6. Only the allowed tracked files change, final hashes are recorded, temporary evidence is cleaned, and no APK/release claim is made because this is a desktop debug-window correction.
