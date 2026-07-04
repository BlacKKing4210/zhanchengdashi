from __future__ import annotations

import csv
import json
import re
import sys
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
SCHEMA_PATH = ROOT / "config" / "schema" / "config_schema.json"


def load_schema() -> dict[str, Any]:
    with SCHEMA_PATH.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def load_tables(schema: dict[str, Any]) -> dict[str, list[dict[str, str]]]:
    tables: dict[str, list[dict[str, str]]] = {}
    for table_name, table_schema in schema["tables"].items():
        table_path = ROOT / table_schema["file"]
        if not table_path.exists():
            raise FileNotFoundError(f"{table_name}: missing file {table_path}")

        try:
            with table_path.open("r", encoding="utf-8-sig", newline="") as handle:
                reader = csv.DictReader(handle)
                if reader.fieldnames is None:
                    tables[table_name] = []
                    continue
                tables[table_name] = [
                    {key: (value or "").strip() for key, value in row.items()}
                    for row in reader
                ]
        except UnicodeDecodeError as exc:
            relative_path = table_path.relative_to(ROOT).as_posix()
            raise ValueError(
                f"{table_name}: {relative_path} must be UTF-8 CSV "
                f"(decode failed at byte {exc.start}: {exc.reason})"
            ) from exc
    return tables


def check_type(
    table_name: str,
    field_name: str,
    value: str,
    field_schema: dict[str, Any],
    id_regex: re.Pattern[str],
) -> str | None:
    if value == "":
        return None

    field_type = field_schema["type"]
    if field_type == "string":
        return None
    if field_type == "id":
        if not id_regex.match(value):
            return f"{table_name}.{field_name}: '{value}' is not a valid id"
        return None
    if field_type == "enum":
        if value not in field_schema["values"]:
            allowed = ", ".join(field_schema["values"])
            return f"{table_name}.{field_name}: '{value}' not in [{allowed}]"
        return None
    if field_type == "int":
        try:
            int(value)
        except ValueError:
            return f"{table_name}.{field_name}: '{value}' is not an int"
        return None
    if field_type == "float":
        try:
            float(value)
        except ValueError:
            return f"{table_name}.{field_name}: '{value}' is not a float"
        return None
    if field_type == "bool":
        if value.lower() not in {"true", "false"}:
            return f"{table_name}.{field_name}: '{value}' is not a bool"
        return None
    if field_type == "list":
        for item in value.split("|"):
            item = item.strip()
            if item and not id_regex.match(item):
                return f"{table_name}.{field_name}: list item '{item}' is not a valid id"
        return None

    return f"{table_name}.{field_name}: unknown schema type '{field_type}'"


def check_global_value(row: dict[str, str]) -> str | None:
    value_type = row.get("type", "")
    value = row.get("value", "")
    key = row.get("key", "<missing>")
    if value == "":
        return f"global.{key}: value is required"
    if value_type == "int":
        try:
            int(value)
        except ValueError:
            return f"global.{key}: '{value}' is not an int"
    elif value_type == "float":
        try:
            float(value)
        except ValueError:
            return f"global.{key}: '{value}' is not a float"
    elif value_type == "bool" and value.lower() not in {"true", "false"}:
        return f"global.{key}: '{value}' is not a bool"
    return None


def validate(schema: dict[str, Any], tables: dict[str, list[dict[str, str]]]) -> tuple[list[str], list[str]]:
    errors: list[str] = []
    warnings: list[str] = []
    id_regex = re.compile(schema["id_pattern"])

    lookup: dict[str, dict[str, set[str]]] = {}

    for table_name, table_schema in schema["tables"].items():
        rows = tables[table_name]
        fields = table_schema["fields"]
        expected_columns = set(fields)
        actual_columns = set(rows[0].keys()) if rows else expected_columns

        missing_columns = expected_columns - actual_columns
        extra_columns = actual_columns - expected_columns
        for column in sorted(missing_columns):
            errors.append(f"{table_name}: missing column '{column}'")
        for column in sorted(extra_columns):
            warnings.append(f"{table_name}: extra column '{column}'")

        unique_field = table_schema.get("unique")
        unique_group = table_schema.get("unique_group")
        seen_values: set[str] = set()
        seen_groups: set[tuple[str, ...]] = set()

        for row_index, row in enumerate(rows, start=2):
            for field_name, field_schema in fields.items():
                value = row.get(field_name, "")
                if field_schema.get("required") and value == "":
                    errors.append(f"{table_name}:{row_index}: required field '{field_name}' is empty")
                    continue

                type_error = check_type(table_name, field_name, value, field_schema, id_regex)
                if type_error:
                    errors.append(f"{table_name}:{row_index}: {type_error}")

            if table_name == "global":
                global_error = check_global_value(row)
                if global_error:
                    errors.append(f"{table_name}:{row_index}: {global_error}")

            if unique_field:
                value = row.get(unique_field, "")
                if value in seen_values:
                    errors.append(f"{table_name}:{row_index}: duplicate {unique_field} '{value}'")
                seen_values.add(value)

            if unique_group:
                group = tuple(row.get(field, "") for field in unique_group)
                if group in seen_groups:
                    fields_text = ", ".join(unique_group)
                    errors.append(f"{table_name}:{row_index}: duplicate group [{fields_text}] {group}")
                seen_groups.add(group)

        lookup[table_name] = {}
        for field_name in fields:
            lookup[table_name][field_name] = {
                row.get(field_name, "")
                for row in rows
                if row.get(field_name, "") != ""
            }

    for table_name, table_schema in schema["tables"].items():
        rows = tables[table_name]
        for reference in table_schema.get("references", []):
            field_name = reference["field"]
            target_table = reference["table"]
            target_column = reference["column"]
            allow_empty = reference.get("allow_empty", False)
            target_values = lookup[target_table][target_column]

            for row_index, row in enumerate(rows, start=2):
                value = row.get(field_name, "")
                if allow_empty and value == "":
                    continue
                if value not in target_values:
                    errors.append(
                        f"{table_name}:{row_index}: {field_name} '{value}' "
                        f"does not exist in {target_table}.{target_column}"
                    )

    return errors, warnings


def main() -> int:
    try:
        schema = load_schema()
        tables = load_tables(schema)
        errors, warnings = validate(schema, tables)
    except Exception as exc:  # noqa: BLE001
        print(f"Config validation failed: {exc}", file=sys.stderr)
        return 1

    for warning in warnings:
        print(f"WARNING: {warning}")
    if errors:
        for error in errors:
            print(f"ERROR: {error}", file=sys.stderr)
        print(f"Config validation failed with {len(errors)} error(s).", file=sys.stderr)
        return 1

    table_count = len(tables)
    row_count = sum(len(rows) for rows in tables.values())
    print(f"Config validation passed: {table_count} tables, {row_count} rows.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
