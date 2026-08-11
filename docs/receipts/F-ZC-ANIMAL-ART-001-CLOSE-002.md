# F-ZC-ANIMAL-ART-001 Closure Receipt

## Result

- Status: `SCALE_OUT_APPROVED WITH CONCERNS`
- Branch: `codex/animal-art-integration-20260811`
- Baseline checkpoint: `38c7793`
- Source set: `D:\AI\art\草图导出`
- Runtime target: `assets/card_art/animals/*.png`
- Configuration contract: existing `runtime/config/cards.json` `art_path` values; no card ID, name, skill, balance, input, layout, or click-target change.

## Delivered scope

- Replaced exactly 40 existing animal-card PNGs using the producer-supplied source pixels.
- Added `output/qa/F-ZC-ANIMAL-ART-001/source_manifest.csv` with card IDs, Chinese names, source filenames, runtime targets, and SHA-256 values; it stays outside runtime export paths.
- Added a repeatable Godot capture scene that validates all 40 texture resources and captures seven representative deck/battle pairs.
- Added 14 target-resolution runtime screenshots plus the Godot capture receipt under `output/qa/F-ZC-ANIMAL-ART-001/`.

## Acceptance evidence

- Manifest rows: `40`.
- Source-to-target SHA-256 matches: `40/40`.
- Runtime card-to-`art_path` matches: `40/40`.
- Changed animal PNG set versus checkpoint `38c7793`: exactly the 40 manifest IDs; the other 20 animal PNGs are unchanged.
- Texture dimensions: `40/40` at `480 x 480` RGBA.
- Opaque pixels touching outer edges: maximum `0`.
- Godot 4.6.3 OpenGL import/capture: exit `0`; `ANIMAL_ART_TEXTURES_PASS: 40/40`; `ANIMAL_ART_CAPTURE_PASS`.
- Player-visible samples: `rabbit`, `ant`, `seal`, `sheep`, `pig`, `swan`, and `crane` in deck and battle contexts.
- `tools/validate_config.py`: passed, 16 tables / 387 rows.
- `tools/export_config.py`: passed; generated runtime JSON remained clean in Git.
- `tools/check_gd_indentation.py`: passed, tab indentation.
- `test_battle_unit_inspection.tscn`: passed.
- `test_classic_battle_regression.tscn`: passed for five random-map variants.
- `test_animal_gold_economy.tscn`: passed.
- Main scene headless startup smoke: exit `0`.

## Known concerns and non-regressions

- `天鹅（章鱼）.png` is an octopus image mapped to the existing `swan`/`天鹅` card.
- `鹤（鹅）.png` is a goose image mapped to the existing `crane`/`鹤` card.
- `test_animal_skill_audit.tscn` still fails the pre-existing hedgehog thorns assertion: `expected 0.000, got 1.000`. The same failure reproduces from the pre-integration checkpoint `38c7793`, so it is recorded as a baseline defect and not attributed to this image-only change.
- Isolated Windows test profiles report inability to read the root certificate store; local offline scenes still execute and this does not affect image loading evidence.
- `RELEASE_VISUAL_APPROVED` remains pending an exported-build and target-device review, plus resolution of the two semantic source-image mismatches.

## Closeout

- Shared animal-art write lock returned in `docs/active_scope.yaml`.
- User's running Godot editor process was not stopped or modified.
- Reusable method candidate: none; the retained capture scene and manifest are sufficient project-local regression aids.
