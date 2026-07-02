from __future__ import annotations

from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def main() -> int:
    errors: list[str] = []
    for path in sorted((ROOT / "scripts").rglob("*.gd")):
        for line_number, line in enumerate(path.read_text(encoding="utf-8-sig").splitlines(), 1):
            if line.startswith(" "):
                errors.append(f"{path.relative_to(ROOT)}:{line_number}: use tabs for GDScript indentation")

    if errors:
        print("GDScript indentation check failed:")
        print("\n".join(errors))
        return 1

    print("GDScript indentation check passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
