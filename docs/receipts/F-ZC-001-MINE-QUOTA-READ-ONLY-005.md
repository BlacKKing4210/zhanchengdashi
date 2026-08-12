# F-ZC-001 Mine Quota Read-Only Receipt 005

- Request ID: `REQ-20260812-EXACT-BONUS-MINE-QUOTA`
- Feature: `F-ZC-001`
- Date: `2026-08-12`
- Owner: `codex_primary`
- Branch: `codex/animal-art-integration-20260811`
- Baseline commit: `f6a500f4edb10339c2d5d9da3d87b7943569f40e`
- Status: `READY FOR BOUNDED IMPLEMENTATION`

## Producer decision

Every faction keeps exactly one starting mine adjacent to its base. Outside those initially unlockable base-adjacent cells, that faction's territory contains exactly one additional mine. Ordinary cells do not independently roll into mines.

## Balance brief

- Player experience: mines remain meaningful strategic objectives instead of common passive-income clutter.
- Memory point: each faction has one safe opening mine and one contested expansion mine.
- Target modes: all five 1V1, five 2V2, five 3V3 maps, and the six-player free-for-all map.
- Baseline: the generic cell pool currently assigns mines weight `5/100`. After the guaranteed starting mine, independent ordinary rolls can leave a faction with zero, one, or several additional mines; the variance grows on the 55-cell free-for-all sectors.
- Hypothesis: an exact one-extra-mine quota reduces gold-source variance and snowballing while preserving one mid-map economy objective per faction.
- Smallest reversible change: remove mines from the independent generic pool and add one seeded, symmetry-preserving quota placement per territory.
- Primary metric: `bonus_mine_count_per_faction = 1` on every generated map.
- Guardrails: `starting_mine_count_per_faction = 1`, `total_mine_count_per_faction = 2`, no neutral-territory mines, fixed-seed reproduction, exact mirror/rotation symmetry, and ordinary site rerolls remain active.
- Evidence limit: no live economy telemetry or controlled human playtest is available for this directive. Structural fairness is testable now; match gold velocity and match duration remain post-release observation metrics.
- Stop/rollback: if deterministic generation breaks symmetry, connectivity, or site variety, do not ship. Rollback restores the prior weight-5 generic mine row and removes the exact-quota pass.
- Recommendation: `ship` the producer-directed structural rule after deterministic regression.

## Read-only diagnosis

- `config/tables/board_cell_types.csv` currently gives `gold_mine` weight `5` and descriptive probability `5.0%`.
- `BoardRules.site_for_configured_roll()` treats that value as an unrestricted ordinary-cell weight.
- `MultiplayerRules` separately guarantees one starting mine next to every base, but has no cap or exact quota for mines elsewhere in the territory.
- Map construction already creates mirrored pairs for 1V1/2V2 and sixfold rotated groups for 3V3/FFA, so the exact bonus mine can reuse those symmetry transforms without a new system or data field.
- The current uncommitted `project.godot` change and existing import/translation/PDF noise are outside this task and must remain untouched.

## Authorized write set

- `docs/CURRENT_GAME_DESIGN.md`
- `config/tables/board_cell_types.csv`
- `config/tables/board_rules.csv`
- `runtime/config/board_cells.json`
- `runtime/config/board_rules.json`
- `scripts/app/systems/multiplayer_rules.gd`
- `tests/test_multiplayer_rules.gd`
- `docs/receipts/F-ZC-001-MINE-QUOTA-READ-ONLY-005.md`
- `docs/receipts/F-ZC-001-MINE-QUOTA-CLOSE-006.md`
- `docs/active_scope.yaml`

## Non-goals

- Do not change mine price, mine income, income interval, starting gold, base income, unlock behavior, card-deck mine requirements, map size, territory ownership, or visuals.
- Do not edit or stage `project.godot` or unrelated untracked files.

## Acceptance

- Generic `gold_mine` appearance weight and descriptive probability are zero; the remaining generic pool probabilities are normalized and exported.
- Each active faction has exactly one `starting_resource = mine` cell and exactly one other mine in its territory.
- The bonus mine is not adjacent to that faction's base.
- No neutral-territory cell is a mine.
- All 15 room maps and FFA pass the rule across multiple deterministic seeds.
- Mirror/rotation symmetry, connectivity, base resources, map variety, configuration validation/export, GDScript indentation, and Godot parse pass.
