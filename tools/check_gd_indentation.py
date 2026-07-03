from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def _gd_indent_rule() -> tuple[str, int]:
    style = "tab"
    size = 2
    in_gd_section = False
    for raw_line in (ROOT / ".editorconfig").read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("[") and line.endswith("]"):
            in_gd_section = line == "[*.gd]"
            continue
        if not in_gd_section or "=" not in line:
            continue
        key, value = [part.strip() for part in line.split("=", 1)]
        if key == "indent_style":
            style = value
        elif key == "indent_size" and value.isdigit():
            size = int(value)
    return style, size


def main() -> int:
    errors: list[str] = []
    indent_style, indent_size = _gd_indent_rule()
    for path in sorted((ROOT / "scripts").rglob("*.gd")):
        for line_number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
            leading = line[: len(line) - len(line.lstrip(" \t"))]
            if not leading:
                continue
            if indent_style == "tab":
                if " " in leading:
                    errors.append(f"{path.relative_to(ROOT)}:{line_number}: use tabs for GDScript indentation")
            else:
                if "\t" in leading:
                    errors.append(f"{path.relative_to(ROOT)}:{line_number}: use spaces for GDScript indentation")
                elif len(leading) % indent_size != 0:
                    errors.append(
                        f"{path.relative_to(ROOT)}:{line_number}: indent is not a multiple of {indent_size} spaces"
                    )

    if errors:
        print("GDScript indentation check failed:")
        print("\n".join(errors))
        return 1

    print(f"GDScript indentation check passed: {indent_style} {indent_size}.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
