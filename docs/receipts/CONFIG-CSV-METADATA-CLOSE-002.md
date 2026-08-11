# CONFIG-CSV-METADATA Close Receipt 002

- Date: 2026-07-28
- Project: `D:\AI\zhanchengdashi`
- Feature ID: `GLOBAL-CONFIG`
- Request ID: `REQ-ZC-GLOBAL-CONFIG-CSV-METADATA-20260728`
- Result: `READY`

## Delivered

- Added the mandatory three-row CSV convention.
- Added `tools/config_csv.py` as the shared reader, writer, migration and validation path.
- Updated `tools/validate_config.py` so runtime data starts on physical line 4.
- Updated `tools/build_unit_balance_doc.py` to skip metadata rows.
- Updated `tools/generate_card_redesign.py` to always emit all three header rows.
- Migrated all 19 CSV files under `config/tables`.

## Data preservation

- Migrated tables: 19
- Preserved runtime data rows: 525
- Row 2 Chinese names: all non-empty
- Row widths: all matched
- Runtime data start: line 4
- Pre/post machine headers and runtime rows: identical
- Baseline SHA-256: `4F905A1CFB341D84A036255F7C4AA3930752B5E53A733907908776741E3019F7`
- All 19 files: valid UTF-8 without BOM

## Runtime export preservation

- Project validator: passed, 15 tables and 327 runtime rows
- Runtime exports: 16 JSON files
- Pre/post runtime JSON: byte-identical for every file
- Aggregate SHA-256 over sorted runtime file hashes: `C3FA68CCCA89555FC4B3458E1E19C3D38617E8BF3DD98DF4866809F3E676975C`
- `git status -- runtime/config`: no changes

## Integration and regression evidence

- Metadata integration smoke: passed
  - balance-document loader read 34 units and 34 skills
  - card generator emitted three header rows into an isolated temporary file
- Godot 4.6.2 `test_rank_ai_decks.gd`: passed
- Godot 4.6.2 `test_multiplayer_rules.gd`: passed for all 15 room maps and the regular free-for-all map
- Godot reported its existing ObjectDB leak warning on exit; both tests returned exit code 0.
- Scoped `git diff --check`: passed
- Remaining direct `csv.DictReader` calls are confined to `tools/game_project_rag.py` for `knowledge_manifest.csv` and `golden_queries.csv`, not gameplay configuration tables.

## Artifact hashes

- `tools/config_csv.py`: `2B9BAD51B4BC306533809C1E98333188225B5C4791F3B8EA38B04E063A5F95FB`
- `tools/validate_config.py`: `353D551C779E05842D387D2EFAF7B4F09DA092EA15024D30186890030F81D9E7`
- `tools/build_unit_balance_doc.py`: `BCCB851386AE42C344BFF6817FC8BD8CCE2297823734B7FB3809524DAD0418FD`
- `tools/generate_card_redesign.py`: `F90173E83A4CB699FF3321E837E2B049228B2F31E5927F8CD857EA34DAD94759`

## Scope confirmation

- No gameplay value, ID, ordering, attribute, count, or localization content changed.
- No game UI, scene, asset, server, or unrelated task file changed.
- Shared locks remain empty.
