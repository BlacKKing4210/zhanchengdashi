# REQ-20260906-DOT-CORNER — narrow UI adjustment

- READY, L1; producer user-producer requests the upgrade dot straddle the card's top-right corner. Baseline 6f706d3a35ffc652374f27ade9b5f8d8a83f9406; sole writer codex-primary. Relevant shared locks are released.
- RAG: temp/rag/context/REQ-20260906-DOT-CORNER.md, READY, 8 citations, signature d50f7c4b97c4aa682890a6f503f89890cc26de77946a30e80a62952ae41d7ba1. This instruction supersedes the preceding inside-corner dot position, not its eligibility or style.
- Source: producer screenshot codex-clipboard-87db5f08-9422-4075-822b-2a366136e2cf.png and current rounded B cards at 720 x 1280. Godot feature-slice and UI state/contrast guidance apply; no new layout or asset production.
- Write set: scripts/app/main.gd (dot anchors/clipping only), tests/test_ui_action_states.gd (matching pixel assertions and optional isolated capture), this receipt, docs/active_scope.yaml, output/runtime_ui_dot_corner_20260906. Exclude all values, upgrade rules, hit targets, other art, user workbook, network/APK and earlier screenshots.
- Acceptance: same 18 px badge; center on the 14 px rounded upper-right rim, 4 px left/down from the rectangular corner (9 px right/up from previous position). Badge extends 5 px beyond top/right. Both equipped and collection cards show it; scrolling clips within the collection panel's existing padding. Ready/insufficient/max-level and post-upgrade behavior unchanged.
- Verification: real Godot GPU pixel tests at the new center and outside the card, notification disappearance after real upgrade, clipped row and first-row visible badges, one retained runtime screenshot. Preserve tabs; parse and run indentation checks. Keep temporary logs outside release paths and remove after evidence capture. Commit/push current branch only.
- reusable_method_candidate: none.

## Completion

- COMPLETE: badge center shifted +9/-9 px onto the rounded rim; equipped and collection first-row badges render with a 5 px top/right overhang. Existing 14 px panel padding safely contains the collection notification; card/list hit rectangles and upgrade rules unchanged.
- Godot 4.6.3 OpenGL runtime pixel/interaction suite PASS, 323 checks (including corner capture); headless suite PASS, 306 checks. Indentation and whitespace checks pass. Runtime evidence: output/runtime_ui_dot_corner_20260906/deck_corner_badges.png, 720 x 1280. New pixel probes cover the overhanging red region, scrolling clip and its disappearance after a real upgrade tap.
- Final SHA256: main.gd B9037C57F7D41A5C9B13382D1B596B0A70E8F7054ACEEADF269621B9E8AFED17; test_ui_action_states.gd EFEB11719719AEB87F511EB88580838220F71001B6A4833C94893788D1CC313E. Baseline commit contains their before versions.
- No workbook, assets, config, server or input-path changes. Prior runtime screenshots remain byte-untouched. Task-only logs cleaned after recording results; regression driver and selected screenshot retained. No APK or new normal-mode override. Previous unrelated RPC concern is not modified or reaccepted in this adjustment.
- Shared-file coordination: retaliation task 019ff0ec-63ef-7f01-8d36-9be00ae2a670 confirmed it had not written main.gd and waits for this focused commit. Release notification includes the commit and main.gd hash; do not stage its later edits.
