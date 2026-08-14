# REQ-20260814-RENDER-CLARITY-BATTLE-PERF close receipt

- Feature: `F-ZC-001`
- Date: `2026-08-14`
- Owner: `codex-primary`
- Local implementation: `COMPLETE`
- Windows GPU validation: `PASS`
- Android target-device acceptance: `PENDING`
- Visual gate: `RUNTIME_SLICE_APPROVED` on Windows at 540 x 960 and 1080 x 1920; `RELEASE_VISUAL_APPROVED` remains pending on a representative Android device

## Delivered behavior

1. The formal portrait viewport remains 1080 x 1920 and the logical UI layout remains 720 x 1280. No page layout, click target, control position, state meaning, battle camera composition or gameplay rule was changed.
2. Text rectangles are mapped to the active physical viewport and glyphs are rasterized at the resulting native pixel size. This prevents 720 x 1280 glyph bitmaps from being enlarged into soft text at 1080 x 1920.
3. Godot 2D transform and vertex pixel snapping are enabled so thin UI borders and icon edges align more consistently to physical pixels.
4. Battle simulation maintains one validated unit-ID-to-array-index cache per update and rebuilds combat-building navigation keys once per update rather than again inside each unit's target-acquisition path.
5. The cache validates the stored unit ID before use and falls back to a safe scan after array compaction, preserving target behavior.

## Resolution and clarity evidence

- Supplied screenshot: 540 x 960, SHA-256 `E55A66D589B329EBB09D66B9A3A0C0862F2159C12143D90FB09E9EFC1E81F0F4`.
- Raising a fixed off-screen render target above 1080 x 1920 was rejected because it would increase GPU cost and then downsample again on a 540 x 960 screen. The delivered improvement raises effective UI raster resolution instead.
- Before 540 x 960: `temp/qa/F-ZC-001/render-clarity-battle-perf/before_540x960.png`, SHA-256 `B8533F155C773300EB177C50911B7998972DE9CE6231ED39FB5F92D523F3C86E`.
- After 540 x 960: `temp/qa/F-ZC-001/render-clarity-battle-perf/after_540x960.png`, SHA-256 `0CA1E80C5BA105B6C34D3A60F1095866AEA505927BCA498569A31E312A71C954`.
- Before 1080 x 1920: `temp/qa/F-ZC-001/render-clarity-battle-perf/before_1080x1920.png`, SHA-256 `CBEED100187AB5F250C6108856467DF4C6BFCA5D89C52FE6076409B155C8A692`.
- After 1080 x 1920: `temp/qa/F-ZC-001/render-clarity-battle-perf/after_1080x1920.png`, SHA-256 `5044D00994ACEF050248401C9895B7275922D8879945C80990803C53662B5B0D`.
- After battle 1080 x 1920: `temp/qa/F-ZC-001/render-clarity-battle-perf/after_battle_1080x1920.png`, SHA-256 `218283EEEED8BFF7323CDD95ECD335250FFFC92CBA13350337C2C5F0EDB94A22`.
- Laplacian-variance sharpness change at 540 x 960: title +36.9%, resources +6.0%, rank +23.8%, buttons +8.3%, navigation +14.0%.
- Laplacian-variance sharpness change at 1080 x 1920: title +323.5%, resources +21.3%, rank +90.3%, buttons +21.3%, navigation +46.9%.

## Battle-performance evidence

- Runtime: Godot 4.6.3 stable, Windows OpenGL compatibility renderer.
- Workload: deterministic 72-unit locked-target battle update, 80 warm-up steps and 400 measured steps per run. Pure HEAD and exact staged source were alternated for six paired runs using the same benchmark script and executable.
- Pure HEAD six-run average: mean 1460.97 us, median 1368.83 us, p95 2060.67 us.
- Exact staged-source six-run average: mean 1096.16 us, median 1021.67 us, p95 1538.00 us.
- Attributable improvement: mean -25.0%, median -25.4%, p95 -25.4%.
- The exact staged-tree formal budget test also passed with p95 2398 us against the 4000 us limit; the paired aggregate is used for before/after comparison because it controls workstation timing noise.
- This benchmark measures the simulation hot path. It does not replace Android frame pacing, thermal or device GPU acceptance.

## Automated and runtime validation

- `tests/test_rendering_clarity.tscn`: `PASS`, 13 checks covering portrait settings, pixel snap, native font sizes, minimum font size, physical text rectangle mapping and canvas scale.
- `tests/test_battle_performance.tscn`: `PASS`, including cache correctness after compaction and new IDs.
- `tests/test_mobile_full_bleed_background.tscn`: `PASS` at 1080 x 2400.
- `tests/test_classic_battle_regression.tscn`: `PASS`, five map variants.
- `tests/test_battle_unit_inspection.tscn`: `PASS`.
- `tests/test_dynamic_battle_animal_cap.tscn`: `PASS`.
- `tests/test_target_loss_no_retreat.tscn`: `PASS`.
- `tests/test_multiplayer_elimination_transfer.tscn`: `PASS`.
- `tests/test_3v3_team_scoreboard.tscn`: `PASS`.
- `tests/test_unit_procedural_motion.tscn`: `PASS`.
- `tests/test_account_manual_login_entry.tscn`: isolated retry `PASS`; the first suite run encountered a transient Windows clipboard-open failure.
- GDScript indentation validation: `PASS`.
- The historical ObjectDB exit warning was not treated as a parser, rendering or simulation success signal.

## Known pre-existing expectation mismatches

- `tests/test_animal_skill_audit.tscn` has a hedgehog-thorns assertion that expects zero remaining attacker HP but receives one. The same assertion fails on pure HEAD after a clean import, proving it predates this rendering/performance change; unrelated animal-skill code and tests were excluded from the commit.
- `tests/test_ground_navigation.tscn` has three assertions that still expect enemy animals to be navigation targets, while the current authoritative behavior already targets enemy buildings. This mismatch existed before the scoped change; gameplay was not changed to satisfy the stale expectation.
- `tests/test_multiplayer_integration.tscn` has two assertions that still expect a fixed 12-unit cap, while the current authoritative dynamic-cap rule yields 18 in that scenario. The dedicated dynamic-cap regression passes; gameplay was not reverted to satisfy the stale expectation.

## Formal source evidence

- Design source: `docs/RENDERING_CLARITY_AND_BATTLE_PERFORMANCE_DESIGN_v1.0.docx`.
- DOCX SHA-256: `7DA80F8D483F3816F9730882410DE3957FB3BC7FDE6E5BCCA0A3FE589BC75F5C`.
- Structural QA: valid OpenXML, 85 paragraphs, 12 tables, one section, 27 headings, no template placeholder paragraphs.
- Page-render QA remains `PENDING`: LibreOffice is unavailable and the Word COM render attempt timed out. No PDF was created or delivered.

## Release boundary and closure

- No server, account, network endpoint or Alibaba Cloud deployment was changed.
- No APK was requested or produced in this scope.
- Unrelated group-buff, configuration, document, import and editor-normalization worktree changes are excluded from this task's exact staged source.
- Android installation, representative-device text/UI review, frame pacing, thermal behavior and sustained battle performance remain open target-device gates.
- The scoped write lock is released. Local implementation and Windows GPU validation are complete.
