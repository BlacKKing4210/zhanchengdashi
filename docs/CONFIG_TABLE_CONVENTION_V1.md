# Configuration CSV Three-Row Header Convention V1

## Purpose

All project configuration CSV files must remain easy for designers to read while keeping metadata out of runtime data.

## Mandatory structure

1. Row 1: machine field names used by code and exported JSON.
2. Row 2: Chinese field names. Every cell must be non-empty and align one-to-one with row 1.
3. Row 3: usage notes and supplemental explanations. Cells may be empty, but the row itself is mandatory and its width must match row 1.
4. Row 4 onward: runtime data.

## Loader and writer contract

- Configuration loaders must validate all three header rows and expose only row 4 onward as data.
- Validators must report physical CSV line numbers, so the first runtime row is line 4.
- Writers and generators must always emit the three header rows.
- Exporters must never place the Chinese-name row or usage-note row into `runtime/config/*.json`.
- Migration must preserve row 1 and every runtime data cell exactly.
- Configuration CSV files must be valid UTF-8; an existing UTF-8 BOM may be preserved.

## Project paths

- Editable source: `config/tables/*.csv`
- Schema: `config/schema/config_schema.json`
- Shared reader, writer, migration and validation helper: `tools/config_csv.py`
- Runtime export: `runtime/config/*.json`
- Project validation: `tools/validate_config.py`
- Runtime export command: `tools/export_config.py`

## Acceptance

- Every CSV in `config/tables` passes the three-row metadata validator.
- All Chinese field names are present.
- Row widths match.
- A pre-migration snapshot proves that machine headers and runtime rows are unchanged.
- Project validation passes after migration.
- Re-exported runtime JSON is byte-identical to the pre-migration runtime baseline.
