# F-ZC-001 Speed Feedback Close Receipt 004

- Request ID: `REQ-20260811-HIDE-SPEED-FLOATING-FEEDBACK`
- Feature: `F-ZC-001`
- Date: `2026-08-11`
- Owner: `codex_primary`
- Branch: `codex/animal-art-integration-20260811`
- Baseline commit: `9d3520f05d464436fb873dbf1b5de107f59dcd30`
- Status: `COMPLETE`
- Scoped visual gate: `RUNTIME_SLICE_APPROVED` at `720 x 1280`
- Release/package gate: not requested and not claimed in this task

## Result

The yellow double-chevron speed values no longer appear above battle animals or buildings. Movement speed, percentage and flat speed auras, haste, and slow remain active gameplay calculations.

The apparent `+3050` / `+7490` growth was a presentation bug: aura speed was reset from base values and reapplied each update, while the feedback merge window repeatedly added each displayed delta. It did not mean a unit gained thousands of speed every frame.

## Implementation

- Corrected `docs/CURRENT_GAME_DESIGN.md`: positive movement-speed changes are internal battle state and never create overhead feedback.
- Removed all positive-speed feedback calls from spawn haste and aura refresh paths.
- Added a shared enqueue guard so no local path can add `unit_value/speed` feedback.
- Added a shared draw guard so stale or authority-snapshot `unit_value/speed` effects remain invisible on online clients.
- Preserved attack, maximum-health, healing, shield, slow, stun, summon, and gold feedback.
- Added focused behavior regression and a repeatable target-resolution capture scene.

## Player-visible evidence

- `output/qa/F-ZC-001-speed-feedback/speed_feedback_hidden_720x1280.png`
- Resolution: `720 x 1280`; SHA-256 `35071421AE38095E120BD7E563E1525770DF685ACE4045468B5904D9D259D807`.
- The capture applies percentage and flat speed auras, injects an online-style hidden `speed +7490` effect, and adds a normal attack `+1` effect as a positive control. The rendered frame shows the orange attack feedback but no yellow speed chevrons or value.

## Verification

- `tools/check_gd_indentation.py`: passed (`tab 2`).
- Godot 4.6.3 headless editor parse/startup: passed.
- `tests/test_unit_procedural_motion.tscn`: passed, including local enqueue rejection, online draw classification, percentage-speed behavior, flat-speed behavior, and preserved stat/gold feedback.
- `tests/test_classic_battle_regression.tscn`: passed for five random-map variants.
- `tests/test_battle_unit_inspection.tscn`: passed.
- `tests/test_animal_gold_economy.tscn`: passed.
- `tests/capture_speed_feedback_fix.tscn`: exited successfully and produced the inspected `720 x 1280` PNG.
- `git diff --check`: passed.

Passing Godot scenes continue to report their existing resource-at-exit warnings. Three broader adjacent scenes also surfaced pre-existing assertions outside this write set: hedgehog thorns in `test_animal_skill_audit`, legacy `rank_mirrors` in `test_online_main_adapter`, and the twelve-unit cap in `test_multiplayer_integration`. This task does not claim a project-wide green suite and did not alter those code paths.

## Integrity

- `docs/CURRENT_GAME_DESIGN.md`: `D33DFCEEA22BA02988BCE2C80019A47314A9BF8F7A29ED226654DC6DBC4F6A90`
- `scripts/app/main.gd`: `1374EB1236BB27B8BBE0B02EC0436B74525E5DAFDD2DAB9FDDA25065C9728BAA`
- `tests/test_unit_procedural_motion.gd`: `9AC411E0448CD88633DD6F1F66E6F16B03F480ED64B405FAC06DB75A4CEA81FD`
- `tests/capture_speed_feedback_fix.gd`: `57FD0E6C37EA8F957A18F533C3C42ACAF820B8F19E665C8AF56B319793628FF6`
- `tests/capture_speed_feedback_fix.tscn`: `C5A03F679DA20C9F2739D6CE653AE235BF52191F4CD38ECF0D232F6B7F0A869E`
- Reusable-method review: `none`; this is a project-local presentation correction.
