# REQ-20260906-ANIMAL-TABLE-V3 — implementation evidence

2026-09-06; owner codex-primary; producer user-producer. Runtime implementation accepted by scoped automated and GPU checks; no mobile package, device performance or remote deployment claim.

## Data integrity

- 71 cards (60 animals, 10 towers, 1 mine), UTF-8 three-row source schema. Compared against producer commit 06423d5: every ID, name, rarity, tier, art path, attack, HP, speed, range, summon interval, both growth columns, skill text, tags and design notes is unchanged. User's working skill_chance header preserved; missing skill_target restored. Only obsolete derived machine skill fields normalized/cleared.
- Added per-card growth to schema/runtime import; synchronized defense mirror and runtime JSON. Validation: 16 tables / 425 rows PASS. Unknown animal description deliberately injected in memory is rejected by validator; no source file was changed for that negative test.
- Exact skill-text profiles cover every current animal. Static final stats are never reapplied as effects. New ordinary attack interval was not provided; existing 1.7-second ordinary cooldown remains. Tower intervals follow latest CSV (mostly 1 second).
- User workbook design/战斗数值.xlsx and unrelated untracked files remain outside the change set.

## Behavior and regression

- tests/test_animal_table_v3.tscn: 3,781 checks, zero failures. Includes all 71 cards at levels 1–10, sub-one fractional growth, world-cell conversion, static-effect nonduplication, births, captures, random/periodic effects, transform, true gold transfer, death/kill attribution, auras/removal/nonstacking, attack critical/dodge boundary, guardian/reduction/retaliation, equal enemy-only splash, extra distinct targets, bounce count and stable IDs, directional piercing, two-cell jump landing, charge windup and swept single-hit collision.
- tests/test_card_upgrade_health_rules.gd: 710 current per-card health assertions PASS. Historical test_animal_skill_audit entry now routes to the comprehensive current V3 audit; obsolete permanent spawn buff/death-summon expectations have been superseded, not retained as current rules.
- test_battle_income_retaliation: 64 checks PASS. test_defense_tower_skills, test_defense_tower_ui_contract, test_defense_deck_integration PASS (expectations migrated to latest tower growth/intervals and true cell units).
- test_ui_action_states: 306 headless checks PASS; existing B skin/selection/upgrade-dot behavior preserved.
- Existing 72-unit benchmark PASS, CPU logic P95 about 1.4 ms. New 72-unit mixed-skill fixture final CPU logic P95 3.626 ms on this Windows workstation, below its 8 ms budget; this does not measure mobile hardware or guarantee a device frame rate.
- GDScript tab indentation PASS, Godot 4.6.3 compatibility parse/boot PASS, git diff whitespace check PASS. Some historical fixtures still emit resource/ObjectDB cleanup warnings at shutdown; assertions complete and process return codes pass. No gameplay assertion or script parser failure remains in the scoped suites.

## Player-visible evidence

- tests/capture_animal_table_v3.tscn produces real Godot GPU-rendered 720x1280 deterministic fixtures using production unit/effect/UI drawing. Inspected both images under output/runtime_animal_v3_20260906: battle_skill_feedback.png and deck_new_skill_description.png.
- Source aura rings, jump height, charge windup, splash ring and projectiles are visible. Critical red numbers (29 px versus normal 24 px) and miss moved above animal silhouettes onto small dark plates for contrast. Card detail uses exact producer text and integer-growth stats.
- Projectile effects reuse one live visual instead of per-frame allocations and remain visible across the existing 0.20-second online snapshot cadence. Actual damage remains authority-side; no account/network-service code or live service changed.

## Scope/cleanup

- Readiness refresh: READY, RAG signature f521d0dbb11362ae8837613b11aad25984feff8592bb85db2e7f992239ecd237.
- Internal current-design override records new rules; historical Word/design versions are not delivered as a newly revised document.
- Guard radius for unspecified surrounding protectors is 1 cell; deer grants HP at the first jump start; squirrel pays once at 8 seconds. Building attack bonuses are applied to buildings themselves, not inherited by their summoned animals. Ground jumps/charges stop at unavailable map cells. No extra systems/currencies/UI navigation were added.
- Shared lock returned at closure. Keep source tests and two selected GPU images; generated logs/cache remain ignored. Commit/push only the scoped game/data/tests/evidence files on the existing branch. No APK requested in this latest task, none produced.
