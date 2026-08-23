# REQ-20260823-DESKTOP-WINDOW-FIT Completion Receipt

## Result

- Status: `COMPLETE_LOCAL_DESKTOP_VALIDATED`.
- Feature/system: `F-ZC-MOBILE-VIEWPORT-002`, follow-up `v1.1.0-desktop-window-fit`.
- Player-facing outcome: starting the Godot project on Windows now opens the complete portrait main page without manual resizing; the top resource bar and bottom navigation are visible in the same frame.
- Root cause: the project had a formal `1080 x 1920` viewport but no desktop window override. The initial 1920-pixel request exceeded the current physical desktop usable height and was only partially clamped by the OS/engine.
- Repair: keep the formal viewport unchanged and add `display/window/size/window_width_override=540` plus `window_height_override=960` for a 50% desktop preview window.
- Preserved behavior: `canvas_items`, `expand`, `window/handheld/orientation=1`, mobile full-bleed background, UI geometry, font/layout scaling, input/touch conversion, camera, gameplay, networking, and server/release configuration are unchanged.

## Before/after runtime evidence

- Isolated current-settings reproduction before the repair: physical usable area `2560 x 1528`; actual client window `1080 x 1570`; internal visible viewport `1320 x 1920`; `fits_usable_area=false`.
- Isolated settings candidate: client window `540 x 960`; internal viewport `1080 x 1920`; `fits_usable_area=true`.
- Real project GUI acceptance through `scenes/bootstrap.tscn -> Main`:
  - client window `540 x 960`;
  - physical usable area `2560 x 1528`;
  - internal visible viewport `1080 x 1920`;
  - captured frame `540 x 960`;
  - `fits_usable_area=true`;
  - top resource bar, title, content area, action buttons, and bottom navigation are all visible in one frame.
- Accepted runtime PNG: `output/qa/F-ZC-MOBILE-VIEWPORT-002/desktop_window_fit_540x960.png`, SHA-256 `C00035A7400DE40C9385E87AFBA205642CDFB1E60FC886CA4E0511203BD68A4E`.

## Verification

- Engine: Godot `4.6.3.stable.official.7d41c59c4`.
- GDScript indentation: `GDScript indentation check passed: tab 2`.
- Focused settings regression: `DESKTOP_WINDOW_FIT_TEST_PASS checks=9 viewport=(1080, 1920) window=(540, 960)`.
- Rendering/layout regression: `RENDERING_CLARITY_TEST_PASS checks=13`.
- Mobile full-bleed GPU regression at `1080 x 2400`: `MOBILE_FULL_BLEED_PASS`, offset `(0, 240)`, uniform scale `1.5`; capture SHA-256 `3A28A196CF175EED19FD43A77A2BE573EAB63106618804972E7BCFF492D60506` before temporary-evidence cleanup.
- Real main-scene GUI capture: `DESKTOP_WINDOW_GUI_PASS window=(540, 960) usable=(2560, 1528) visible=(1080, 1920) capture=(540, 960) scene=Main`.
- Project import/scan exited `0`. It logged `Failed to bind socket. Error: 3` because the user's existing Godot editor already owned the editor/debug socket; no parser, script, or resource-load failure was found, and the focused/GPU/main-scene runs all exited `0`.
- `git diff --check` passed for the scoped text/config files.

## RAG and concurrency

- Final refreshed project RAG at validation time: `READY`, mean recall `1.0`, pass rate `1.0`, index signature `dc89fea93cbffab9e8943e44f24633ddfb2c6e1ada1729d9cd9b7d2ec7d72f6e`.
- Gate receipt SHA-256: `C4F5A8B7831241629905F2B719AC8AB72761DCB62AB7710BF3DE634C9552BD34`.
- Task receipt SHA-256: `C14F5E3D884AD0DED61FFF58E4CA859BCDAB6147EFB7880BF125396305F7A927` with eight citations.
- Final scoped control result: `READY`, `L1 direct_execute`, no duplicate or conflict, fingerprint `46B525D4B7D06D6C01289931A7376125A3F3B8330B4A384DAD8304575797000A`.
- Unrelated admin/dashboard and GM-panel tasks continued concurrently and advanced the branch parent from starting `bdde565e88de90bccf58a30f68d3736c2653a538` to pre-commit `ee26503b87e2a6a100eaa5b723d5af10ea5bc2d8`. Their files and locks were not staged or modified by this task.

## Final tracked source hashes before commit

| File | SHA-256 |
| --- | --- |
| `project.godot` | `4E5F434B9A51E9A9C9A5D592977881035395F64BC31B71435BCED6A6A3B74556` |
| `docs/DEVELOPMENT_WORKFLOW.md` | `FE02C67650187A99F57E23862C66C8C17E88B0414E5F4C50C782496286A13008` |
| `docs/receipts/REQ-20260823-DESKTOP-WINDOW-FIT-READ-ONLY-001.md` | `448F9D5575CBEA32DA993CC87CA4DFF700CBE576BB2A547980AC1E1670C27D79` |
| `tests/test_desktop_window_fit.gd` | `497EE68715CF28F3A2A5ECB070768BACA7E770004302E99F1BC56FBCFEFE2AA4` |
| `tests/test_desktop_window_fit.tscn` | `43A7496DCD192F1B9147B7DC57B31F8A0155409E825863D10B39024A3D485B9F` |
| `output/qa/F-ZC-MOBILE-VIEWPORT-002/desktop_window_fit_540x960.png` | `C00035A7400DE40C9385E87AFBA205642CDFB1E60FC886CA4E0511203BD68A4E` |

## Boundaries, package status, and cleanup

- No `scripts/app/main.gd`, UI scene/layout, touch/input, camera, gameplay, configuration table/runtime JSON, asset, networking, server, deployment, APK, or unrelated dirty file was changed by this task.
- No APK was rebuilt or claimed. This is a desktop development-window correction; the preserved mobile behavior is covered by the existing GPU full-bleed regression and unchanged portrait/stretch settings.
- Temporary QA drivers, isolated probe projects, spreadsheet-reader junction, logs, duplicate test process, isolated app/user data, RAG task context, and rejected captures are removed after this receipt is finalized. They contain no player data and are not recoverable after cleanup.
- Retained evidence: the focused regression sources, formal receipts, workflow rule, project setting, and accepted runtime PNG listed above.
- `reusable_method_candidate: none`.
