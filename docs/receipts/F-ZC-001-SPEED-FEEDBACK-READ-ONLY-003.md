# F-ZC-001 Speed Feedback Read-Only Receipt 003

- Request ID: `REQ-20260811-HIDE-SPEED-FLOATING-FEEDBACK`
- Feature: `F-ZC-001`
- Date: `2026-08-11`
- Owner: `codex_primary`
- Branch: `codex/animal-art-integration-20260811`
- Baseline commit: `9d3520f05d464436fb873dbf1b5de107f59dcd30`
- Status: `READY FOR NARROW IMPLEMENTATION`

## Producer-visible issue

The supplied portrait battle screenshot shows yellow double-chevron speed feedback such as `+3050`, `+3390`, and `+7490` repeatedly floating over animals and buildings. The producer decision is that this speed display must not exist.

## Read-only diagnosis

- `scripts/app/main.gd::_refresh_unit_aura_bonuses()` resets each living unit to `base_speed` every update and then reapplies active speed auras. The unit's stored speed therefore does not grow by the displayed thousands each frame.
- `_add_aura_speed()` and `_add_aura_speed_flat()` currently call `_show_unit_value_feedback(..., "speed", ...)` on every aura refresh.
- `_show_unit_value_feedback()` merges same-unit, same-stat events during the merge window by adding their amounts. The repeated per-frame aura refresh therefore turns ordinary speed deltas into misleading, ever-growing yellow totals.
- The same `effects` array is also copied from online authority snapshots, so a local enqueue-only fix would not guarantee that a stale or remote speed event stays invisible.
- `docs/CURRENT_GAME_DESIGN.md` currently authorizes speed as a visible overhead stat feedback and must be corrected before runtime code.

## Authorized write set

- `docs/CURRENT_GAME_DESIGN.md`
- `scripts/app/main.gd`
- `tests/test_unit_procedural_motion.gd`
- `tests/capture_speed_feedback_fix.gd`
- `tests/capture_speed_feedback_fix.tscn`
- `output/qa/F-ZC-001-speed-feedback/speed_feedback_hidden_720x1280.png`
- `docs/receipts/F-ZC-001-SPEED-FEEDBACK-READ-ONLY-003.md`
- `docs/receipts/F-ZC-001-SPEED-FEEDBACK-CLOSE-004.md`
- `docs/active_scope.yaml`

## Implementation contract

- Keep base movement speed, haste timers, slow timers, percentage speed auras, and flat speed auras behaviorally unchanged.
- Reject positive `speed` feedback at the shared enqueue path.
- Reject `speed` feedback at the shared draw path as a defense for online snapshots or stale effects.
- Keep attack, maximum-health, healing, shield, slow, stun, summon, and gold feedback unchanged.
- Do not move units, HP bars, world coordinates, collision, selection, camera, or card data.

## Acceptance

- A direct request to enqueue `speed` feedback produces no visible feedback entry.
- Percentage and flat speed auras still change the affected unit's battle speed but create no speed feedback.
- Existing attack, health, shield, slow, and gold feedback tests still pass.
- An injected online-style `unit_value/speed` effect is classified as hidden by the draw guard.
- GDScript indentation, Godot parse/startup, focused procedural-motion tests, and adjacent battle regressions pass.
- A `720 x 1280` runtime battle capture contains no yellow speed-chevron value display.
