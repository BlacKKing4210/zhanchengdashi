"""Check animal dialogue coverage and the authoritative CSV-to-runtime handoff."""
from __future__ import annotations

import json
import re
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.config_csv import read_config_dicts  # noqa: E402
from tools.validate_config import check_type  # noqa: E402


class AnimalSloganConfigTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = read_config_dicts(ROOT / "config/tables/cards.csv")
        cls.runtime = json.loads((ROOT / "runtime/config/cards.json").read_text(encoding="utf-8"))
        cls.schema = json.loads((ROOT / "config/schema/config_schema.json").read_text(encoding="utf-8"))
        main = (ROOT / "scripts/app/main.gd").read_text(encoding="utf-8")
        cls.mine_id = re.search(r'^const MINE_CARD_ID = "([^"]+)"', main, re.MULTILINE).group(1)

    @classmethod
    def is_animal(cls, card):
        # Match _card_kind: "building" alone does not exclude the beaver.
        if card["id"] == cls.mine_id or card["id"].startswith("defense_"):
            return False
        return not any(tag in {"mine", "gold_mine", "defense", "tower"} for tag in card.get("tags") or [])

    def test_every_animal_has_its_own_display_line(self):
        animals = [card for card in self.runtime if self.is_animal(card)]
        self.assertTrue(animals)
        seen = {}
        for card in animals:
            with self.subTest(card=card["id"]):
                line = card.get("slogan")
                self.assertIsInstance(line, str)
                self.assertTrue(line.strip(), "Every current animal needs a slogan")
                self.assertEqual(line, line.strip())
                self.assertNotIn(line, seen, f"Duplicate animal slogan from {seen.get(line)}")
                seen[line] = card["id"]

    def test_schema_and_export_preserve_configured_text(self):
        field = self.schema["tables"]["cards"]["fields"]["slogan"]
        self.assertEqual(field, {"type": "string", "required": False, "max_length": 32, "single_line": True})
        self.assertEqual([card["id"] for card in self.source], [card["id"] for card in self.runtime])
        for source, runtime in zip(self.source, self.runtime, strict=True):
            with self.subTest(card=source["id"]):
                self.assertIn("slogan", source)
                self.assertIn("slogan", runtime)
                self.assertEqual(runtime["slogan"], source["slogan"] or None)

    def test_single_line_length_boundary_and_unicode(self):
        field = self.schema["tables"]["cards"]["fields"]["slogan"]
        pattern = re.compile(self.schema["id_pattern"])
        for text in ["", "哈" * 32, "🐸" * 32]:
            with self.subTest(valid=text):
                self.assertIsNone(check_type("cards", "slogan", text, field, pattern))
        for text in ["哈" * 33, "🐸" * 33, "前一句\n后一句", "前一句\r后一句"]:
            with self.subTest(invalid=text):
                self.assertIsNotNone(check_type("cards", "slogan", text, field, pattern))

    def test_unconstrained_legacy_text_keeps_its_existing_contract(self):
        pattern = re.compile(self.schema["id_pattern"])
        self.assertIsNone(check_type("cards", "design_notes", "旧说明\n" * 50, {"type": "string"}, pattern))

    def test_quoted_csv_newline_reaches_the_single_line_validator(self):
        with tempfile.TemporaryDirectory(prefix="animal-slogan-") as directory:
            path = Path(directory) / "cards.csv"
            path.write_bytes('id,slogan\nID,动物口号\n,\nmouse,"前一句\n后一句"\n'.encode("utf-8"))
            value = read_config_dicts(path)[0]["slogan"]
        self.assertEqual(value, "前一句\n后一句")
        field = self.schema["tables"]["cards"]["fields"]["slogan"]
        self.assertIsNotNone(check_type("cards", "slogan", value, field, re.compile(self.schema["id_pattern"])))


if __name__ == "__main__":
    unittest.main()
