# F-ZC-001 Mine Quota Completion Receipt 006

- Request ID: `REQ-20260812-EXACT-BONUS-MINE-QUOTA`
- Feature: `F-ZC-001`
- Date: `2026-08-12`
- Owner: `codex_primary`
- Branch: `codex/animal-art-integration-20260811`
- Baseline commit: `f6a500f4edb10339c2d5d9da3d87b7943569f40e`
- Status: `COMPLETED FOR SOURCE INTEGRATION`

## Player-facing result

- Every faction has exactly one initially unlockable mine adjacent to its base.
- Outside the base-adjacent ring, every faction has exactly one additional mine in its territory.
- Every faction therefore has exactly two mines on the complete generated board. Ordinary cells cannot independently roll into a third mine.
- The additional mine is seeded and deterministic. It is mirrored for 1V1/2V2 and generated as a sixfold rotational group for 3V3/free-for-all, so opponents receive equivalent placement.

## Design and configuration

- `gold_mine.appearance_weight` changed from `5` to `0`; its descriptive ordinary-pool probability changed from `5.0%` to `0.0%`.
- The remaining ordinary-cell pool keeps weights `50/30/15` and publishes normalized probabilities `52.6% / 31.6% / 15.8%` for question/unit/defense.
- The current game design and board-rule notes now define mine count as a map quota instead of a probabilistic outcome.
- `tools/validate_config.py`: passed, `16` tables and `387` rows.
- `tools/export_config.py`: completed; only `runtime/config/board_cells.json` and `runtime/config/board_rules.json` changed as expected.

## Runtime implementation

- After bases and starting resources are placed, map generation removes every non-starting randomly rolled mine in symmetry-preserving groups.
- It then selects one eligible extra-mine mother cell per mirrored lane or rotational sector using the layout seed.
- Candidate cells must belong to the intended faction, contain no building or starting resource, contain a valid ordinary site, and not be adjacent to that faction's base.
- Failure to find a valid symmetric candidate rejects match generation instead of silently violating the quota.

## Verification

- Godot project import/parse: exit `0` with Godot `4.6.3.stable.official.7d41c59c4`.
- GDScript indentation: passed the project tab-indentation checker.
- `tests/test_multiplayer_rules.gd`: exit `0`; all five maps for each of 1V1, 2V2, and 3V3 plus the regular-hex FFA passed mirror/rotation, connectivity, deterministic variety, starting-resource, and exact mine-quota checks.
- Multi-seed quota matrix: all `15` room maps and FFA passed seeds `1`, `17`, `24680`, and `987654` using the fallback cell pool.
- Runtime-config matrix: all `15` room maps and FFA passed seed `42042` after loading exported `runtime/config/board_cells.json`.
- For every tested faction: `starting mines = 1`, `non-starting mines = 1`, `total mines = 2`; every extra mine was outside the base ring; every mine cost `50`; no neutral/inactive-territory mine existed.
- `tests/test_classic_battle_regression.tscn`: passed all five classic random-map variants.
- `tests/test_multiplayer_match_rules.tscn`: passed.
- `tests/test_lobby_multiplayer_ffa.tscn`: passed.
- The first implementation attempt exposed asymmetric replacement of removed fallback mines; the final implementation replaces removed mines by mirrored/rotated mother-cell groups, and the complete symmetry regression then passed.

## Known unrelated baseline

- `tests/test_multiplayer_camera.tscn` still fails its final post-drag building-click assertion (`expected (5, 2), got (-99, -99)`). `docs/receipts/F-ZC-MOBILE-VIEWPORT-002-CLOSE-002.md` records the identical assertion failing in a clean baseline. This task changes no camera, canvas, input, or selection code and does not claim that unrelated regression as fixed.
- Existing ObjectDB/resource-retention warnings remain visible at test shutdown and are not parser or mine-quota failures.

## Final tracked source hashes

| File | SHA-256 |
| --- | --- |
| `docs/CURRENT_GAME_DESIGN.md` | `45ABDBA1102B32ECB102260E2684B7BADD4D3EC6CC5F43B27E8E250E95CE7749` |
| `config/tables/board_cell_types.csv` | `19A08942231C76E7841867897637EE64530BF0334C91E9187F3AAF69AE4E48B4` |
| `config/tables/board_rules.csv` | `31BBDF6B7BC185B53C3C71D03B6410A72CD4182BA95F981A095EA4C2DE372C62` |
| `runtime/config/board_cells.json` | `62237DFE6309738B1B9AA51FE09C0DDAC40F62E98F254533106F9A8C54EAE40E` |
| `runtime/config/board_rules.json` | `1AE8EEE81C5D7601813318DED7A3ADD47CA5E3C3D86CE81571D0B9CFC4A92164` |
| `scripts/app/systems/multiplayer_rules.gd` | `A9702D85C5D6B85B05D6732BB100E421A619FF3EACDAB9E9E69FE76C944A911D` |
| `tests/test_multiplayer_rules.gd` | `BF5B297C64F1A4763BB8F125CD07F8A9CF504AE7D42C48C3F23FF4F8E189B93D` |

## Boundaries

- Mine price, income amount/interval, starting gold, base income, unlock behavior, cards, map size, territory ownership, server behavior, visuals, and Android packaging were not changed.
- No package was produced because this request was a source/configuration balance adjustment.
- Match-duration and gold-velocity telemetry are not available in this task; they remain post-release observation metrics rather than structural acceptance blockers.
- The pre-existing uncommitted `project.godot` change and unrelated import/translation/PDF files were preserved and excluded.
- `reusable_method_candidate: none`.
