"""One-shot producer CSV encoding/header repair and derived legacy-field sync."""
import csv
import io
from pathlib import Path

from config_csv import read_config_dicts, write_config_dicts

ROOT = Path(__file__).resolve().parents[1]


def main():
    path = ROOT / "config/tables/cards.csv"
    raw = path.read_bytes()
    try:
        content = raw.decode("utf-8-sig")
    except UnicodeDecodeError:
        content = raw.decode("gbk")
    rows = list(csv.reader(io.StringIO(content)))
    assert len(rows[0]) == 22
    rows[0][20:] = ["skill_chance", "skill_target"]
    fields = rows[0]
    cards = [dict(zip(fields, row)) for row in rows[3:] if row and row[0]]
    defenses_path = ROOT / "config/tables/defenses.csv"
    defenses = read_config_dicts(defenses_path)
    by_id = {row["id"]: row for row in defenses}
    # The producer's visible text is authoritative; old animal effect columns
    # describe a different design. Runtime compiles text into a checked profile.
    for card in cards:
        if card["id"] in by_id:
            defense = by_id[card["id"]]
            effect = card["skill_effect"] if card["skill_id"].startswith("defense_") else card["skill_id"]
            card["skill_id"] = defense["skill_id"]
            card["skill_effect"] = effect if effect not in {"", "defense_basic"} else ""
            card["skill_trigger"] = "passive"
            if effect == "plunder":
                card["skill_trigger"] = "on_attack"
            elif effect == "gold":
                card["skill_trigger"] = "on_kill"
            elif effect == "global_damage":
                card["skill_trigger"] = "on_interval"
            for dst, src in (("rarity", "rarity"), ("max_hp", "max_hp"),
                             ("attack_range", "attack_range"), ("base_damage", "attack"),
                             ("attack_cooldown_sec", "summon_interval_sec")):
                defense[dst] = card[src]
        elif card["id"] != "gold_mine_card":
            for field in ("skill_id", "skill_trigger", "skill_effect", "skill_power",
                          "skill_cooldown_sec", "skill_chance", "skill_target"):
                card[field] = ""
    notes = dict(zip(fields, rows[2]))
    write_config_dicts(path, fields, cards, usage_notes=notes)
    write_config_dicts(defenses_path, list(defenses[0]), defenses)
    print(f"Preserved producer values/text for {len(cards)} cards; UTF-8 and tower mirror synchronized.")


if __name__ == "__main__":
    main()
