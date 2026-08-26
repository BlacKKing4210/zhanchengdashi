# REQ-20260826-DEFENSE-TOWER-REDESIGN-V1 Milestone Receipt

- Feature: `F-ZC-DEFENSE-TOWER-005`
- Date: `2026-08-26`
- Owner: `codex-primary`
- Milestone status: `WAITING_PRODUCER_APPROVAL`
- Runtime art status: `NOT_RUNTIME`

## Delivered and verified

- The producer-provided ten-tower table is synchronized across `cards.csv`, `defenses.csv`, `skills.csv`, both Chinese localization tables, and runtime JSON.
- Lv.1 attack, health, range, and attack interval are final post-effect values. Runtime no longer re-applies the packaging bonuses.
- Stable runtime skill mechanisms cover ranged-target priority, one-gold transfer, one extra animal target, ten-gold kill bounty, allied-territory global targeting, and the five-second all-animal pulse.
- Card details and in-battle tower details show the full skill text without ellipsis at `720×1280`.
- Two architecture-first whole-set direction boards are ready for producer selection. Both keep the tower body primary and contain no complete animal standing on a tower.

## Evidence

| Gate | Result | Evidence |
| --- | --- | --- |
| Configuration validation | PASS | `16 tables, 425 rows`; validate → export → validate |
| GDScript indentation | PASS | `tools/check_gd_indentation.py`; tab policy preserved |
| Tower mechanics | PASS | `tests/test_defense_tower_skills.tscn` |
| Deck integration | PASS | `tests/test_defense_deck_integration.tscn` |
| Defense rarity fallback | PASS | `tests/test_defense_rarity_fallback.gd` |
| Classic maps | PASS | `tests/test_classic_frontier_rules.tscn` |
| Ranked AI | PASS | `tests/test_ranked_ai_rosters.tscn` |
| Multiplayer rules | PASS | `tests/test_multiplayer_match_rules.tscn` |
| 72-unit performance | PASS | mean `0.998ms`, median `0.957ms`, P95 `1.210ms` < `4ms` |
| Godot parse/start | PASS | Godot `4.6.2`, headless start, exit `0` |
| Player-visible UI | PASS | `output/qa/F-ZC-DEFENSE-TOWER-005/*.png` |
| Formal DOCX render | PASS | 10 pages inspected; no clipping; temporary PDF removed |
| Art direction board review | PASS FOR SELECTION | A/B are RGB white-background review boards only |

Godot prints existing `ObjectDB instances leaked at exit` / resource-in-use cleanup warnings in several isolated test processes. All named tests return exit code `0`; these warnings are recorded and are not treated as runtime-art or device acceptance.

## Architecture-first art contract

- The tower occupies at least 85% of the main silhouette and must read first as a functional building.
- Animal identity is limited to integrated roof ridges, eaves, buttresses, armor plates, patterns, mechanisms, or conduits.
- A complete animal may not stand, sit, ride, pilot, or perch on the tower; a giant independent animal head may not replace the building body.
- Board A is the warmer wood-and-stone direction. Board B is the more unified stone-fortress direction.

## Remaining producer gate

The producer must select A or B, or give a hybrid direction. Only after that decision may the approved direction be regenerated as ten `480×480` transparent production assets, normalized, validated in one representative `720×1280` runtime slice, and then bound to all ten tower cards. No candidate-board pixels are cut directly into runtime.
