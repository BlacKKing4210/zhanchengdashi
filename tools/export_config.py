from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parents[1]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from tools.validate_config import load_schema, load_tables, validate  # noqa: E402


OUTPUT_DIR = ROOT / "runtime" / "config"


def cast_value(value: str, field_schema: dict[str, Any]) -> Any:
    if value == "":
        return None

    field_type = field_schema["type"]
    if field_type == "int":
        return int(value)
    if field_type == "float":
        return float(value)
    if field_type == "bool":
        return value.lower() == "true"
    if field_type == "list":
        return [item.strip() for item in value.split("|") if item.strip()]
    return value


def cast_global(row: dict[str, str]) -> Any:
    value = row["value"]
    value_type = row["type"]
    if value_type == "int":
        return int(value)
    if value_type == "float":
        return float(value)
    if value_type == "bool":
        return value.lower() == "true"
    return value


def export_tables(schema: dict[str, Any], tables: dict[str, list[dict[str, str]]]) -> list[str]:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    exported: list[str] = []

    for table_name, table_schema in schema["tables"].items():
        rows = tables[table_name]
        output_path = OUTPUT_DIR / f"{table_name}.json"

        if table_name == "global":
            payload: Any = {row["key"]: cast_global(row) for row in rows}
        else:
            fields = table_schema["fields"]
            payload = [
                {
                    field_name: cast_value(row.get(field_name, ""), field_schema)
                    for field_name, field_schema in fields.items()
                }
                for row in rows
            ]

        with output_path.open("w", encoding="utf-8", newline="\n") as handle:
            json.dump(payload, handle, ensure_ascii=False, indent=2)
            handle.write("\n")
        exported.append(str(output_path.relative_to(ROOT)).replace("\\", "/"))

    manifest = {
        "schema_version": schema["version"],
        "generated_by": "tools/export_config.py",
        "tables": exported,
    }
    manifest_path = OUTPUT_DIR / "config_manifest.json"
    with manifest_path.open("w", encoding="utf-8", newline="\n") as handle:
        json.dump(manifest, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    exported.append(str(manifest_path.relative_to(ROOT)).replace("\\", "/"))

    return exported


def main() -> int:
    schema = load_schema()
    tables = load_tables(schema)
    errors, warnings = validate(schema, tables)

    for warning in warnings:
        print(f"WARNING: {warning}")
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        print("Export aborted because config validation failed.", file=sys.stderr)
        return 1

    exported = export_tables(schema, tables)
    print("Exported runtime config:")
    for path in exported:
        print(f"- {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
