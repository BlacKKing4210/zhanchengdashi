# REQ-20260825-RESOLUTION-STANDARD-720P Completion Receipt

## Result

- Status: `COMPLETE_LOCAL_RUNTIME_VALIDATED`.
- Feature/system: `TECH-RESOLUTION-STANDARD`, revision `v1.0.0-720p-defaults`.
- Current project: fixed portrait viewport and default desktop client window are now both `720 x 1280`.
- Cross-project default: new or unset portrait games use `720 x 1280`; new or unset landscape games use `1280 x 720`. Existing games with approved project-specific targets are not bulk-overwritten.
- Superseded current-project values: `1080 x 1920` viewport and `540 x 960` desktop override. Historical receipts, screenshots, compatibility tests, and the original `loading_portrait_1080x1920.png` source asset remain unchanged.
- Preserved behavior: `canvas_items`, `expand`, fixed portrait orientation, the `720 x 1280` layout/input coordinate system, touch conversion, UI geometry, camera, gameplay, networking, and server/package settings.
- User-level persistence: `C:\Users\76398\.codex\AGENTS.md` now records the orientation defaults and the project-exception rule; existing other game repositories were not modified.

## Player-visible and engine evidence

- Real standalone launch path: `project.godot -> scenes/bootstrap.tscn -> scenes/main.tscn`.
- Real window title: `丛林法则 (DEBUG)`.
- Actual client area: `720 x 1280`; current desktop usable area: `2560 x 1528`.
- Accepted PNG: `output/qa/TECH-RESOLUTION-STANDARD/portrait_default_720x1280.png`, exact dimensions `720 x 1280`, SHA-256 `B4C6D5D2086875A89810299F674ECABE5D9F677BC10EF8AE71DD0C2A4F2FCA35`.
- Visual inspection: the top resource bar, title, main preview, rank panel, both battle buttons, and complete bottom navigation are visible in one frame; text and UI borders are crisp and no edge is clipped.
- GPU full-bleed default check: `MOBILE_FULL_BLEED_PASS viewport=(720, 1280) image=(720, 1280) offset=(0, 0) scale=1.0`; temporary capture SHA-256 `09A6BB072BA21C8971F54FF8322D6AB3B4E74F3A7233E7990C549DD523C59745`.
- Tall-phone compatibility check: `MOBILE_FULL_BLEED_PASS viewport=(1080, 2400) image=(1080, 2400) offset=(0, 240) scale=1.5`; temporary capture SHA-256 `D5CBC3BBBC6BBDCE0CA050240C86CFCF815FCDD1FDD799FD7A1723CA8C5AEAB6`.

## Focused and milestone-review verification

- Godot: `4.6.3.stable.official.7d41c59c4`.
- GDScript indentation: `PASS`, tab indentation preserved.
- Resolution contract: `RESOLUTION_STANDARD_TEST_PASS checks=9 portrait=(720, 1280) landscape=(1280, 720) window=(720, 1280)`.
- Rendering/layout contract: `RENDERING_CLARITY_TEST_PASS checks=15`, including native `720 x 1280` scale `1.0` plus `540 x 960` and `1080 x 1920` compatibility boundaries.
- Main-scene headless smoke: exit `0`, with no parser, missing-resource, or startup error.
- Isolated clean editor import: exit `0`; the first run imported the tracked runtime assets and registered all scripts without parser/resource errors.
- Isolated second editor import: exit `0`; no asset reimport phase occurred, confirming a stable no-change scan.
- Existing project editor PID `13260` remained running and was not closed or restarted.
- The focused tests emit the pre-existing `ObjectDB instances leaked at exit` shutdown warning but exit `0`; no persistent test process remains and no failure is attributed to this resolution change.
- `git diff --check`: `PASS` for all scoped text/config/test files.
- L3 milestone review: completed as a separate no-write phase after implementation; focused contracts, final RAG, cold/no-change imports, real-window evidence, and document renders were rechecked before closure.

## Formal document verification

- `docs/CURRENT_GAME_DESIGN.docx` was minimally updated in place, preserving the existing structure and styles.
- The packaged `render_docx.py` route was attempted but the workstation has no LibreOffice `soffice` executable. Equivalent local verification used Microsoft Word 16 read-only fixed-format rendering and bundled Poppler PNG rasterization.
- Final render: `32` pages; every page was visually inspected. The resolution table repeats its header across the page break and has no clipping, overlap, broken borders, or missing text.
- The render-only PDF, page PNGs, contact sheets, capture scripts, isolated project/archive, and rejected screenshot were removed after inspection. The accepted runtime PNG is retained under `output/qa/`.

## Final RAG and control state

- RAG: `READY`; index signature `c1a52f4747d18635d5c47066a2d539eb201211c68e192c956eb77452719b292a`; mean recall `1.0`; pass rate `1.0`; task citation count `9`.
- RAG gate SHA-256: `9CA6C9F0177D7F74179659B13767AAB2C07F094A02CC1E06EE05DEFB189E2D11`.
- RAG task receipt SHA-256: `E90C58DAC949D9C50DA86445604C1B39AFCB1FCFD1A1E8BAD02B6CDF51C05C51`.
- Final control-plane check: `READY / L3`, no duplicate or conflicting task IDs, task fingerprint `C5CAA021CD14C84CE3F23F85259C5932D40CEFBFC29B72A3DAA44D33E1B8085D`.
- No shared lock was taken from another task; all intended paths were unowned or released when the task started.

## Final source hashes before commit

| File | SHA-256 |
| --- | --- |
| `docs/CURRENT_GAME_DESIGN.docx` | `C50D1B279C6763BA1E173D1851BFD07817AFF7A32787B89BC96D2FB35209D1F5` |
| `docs/CURRENT_GAME_DESIGN.md` | `2E8DEF9161B25160FF958EE1E9E31A94CD4E6FC0538A7BD20004FEEEBDAD2091` |
| `docs/DEVELOPMENT_WORKFLOW.md` | `7DD6BF3BDA19D996923865945381E555F78BA5F869A9161D27468A98D48711B1` |
| `knowledge/knowledge_manifest.csv` | `86A534E190C87D90C9C44EA2A5472E7ADA972A37EA021E8544C28E2E72CCBD75` |
| `project.godot` | `FD24D498C39CAAA19E80FB09DA93B230168D44F86558554CF066A8DDCF980DD5` |
| `tests/test_desktop_window_fit.gd` | `447CF510F15AF031C4C0D4A6151DC00A518480E7C5121D409FB8BF3B494108FA` |
| `tests/test_rendering_clarity.gd` | `10C49EAB7FF1CD6363FF5045FDB366793909F14019249B7788E7A791DCDC459E` |
| `docs/receipts/REQ-20260825-RESOLUTION-STANDARD-720P-READ-ONLY-001.md` | `23667F4C8F41911D8E496ED8948621EDEC69C20FD7275F69E549900272A4C8D8` |
| `output/qa/TECH-RESOLUTION-STANDARD/portrait_default_720x1280.png` | `B4C6D5D2086875A89810299F674ECABE5D9F677BC10EF8AE71DD0C2A4F2FCA35` |
| `C:\Users\76398\.codex\AGENTS.md` (user-level, outside Git) | `AF943E2E293CA04D2199D83180FA1E9DA13E29922D597F8206D1DD906B22D878` |

## Boundaries

- Android APK/package: `NOT_REQUESTED`, so no package was produced or claimed.
- Android physical-device validation: `NOT_RUN`; fixed portrait and GPU regressions are engine evidence, not a replacement for device acceptance.
- Existing projects outside `D:\AI\zhanchengdashi`: `UNCHANGED`.
- Configuration tables/runtime JSON: `UNCHANGED`; validation/export commands were not required.
- Unrelated dirty workbook, import metadata, historical receipts, translation helpers, PDF, and other untracked files were preserved and excluded from staging.
- Temporary QA/import/render files were generated only for this task and were deleted after validation; they are not recoverable and contain no user-authored data.
- Reusable method candidate: `none`.
