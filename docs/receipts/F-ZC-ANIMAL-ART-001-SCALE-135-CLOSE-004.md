# F-ZC-ANIMAL-ART-001 Runtime Scale Completion Receipt

## Result

- Request: `REQ-20260811-ANIMAL-SCALE-135`.
- Status: `COMPLETE`; visual gate for this adjustment: `RUNTIME_SLICE_APPROVED` at `720 x 1280`.
- Branch baseline: `codex/animal-art-integration-20260811` at `26ed374e787650efee49ee4bc8b9df838e05a875`.
- Producer-visible result: exactly the 40 newly integrated animal images display at `1.35` times their previous size throughout the current game runtime; the other 20 existing animal images remain at `1.0`.

## Implemented behavior

- Added one selective display-scale contract in `scripts/app/main.gd`: `INTEGRATED_ANIMAL_ART_DISPLAY_SCALE = 1.35` plus the exact 40-card manifest roster.
- Applied the contract to lobby animals, deck/card/collection art, card detail art, living battle units, and death snapshots.
- Preserved existing rarity multipliers and procedural pose scaling by multiplying them with the new display factor only at draw time.
- Preserved world positions, unit tiles, collision, selection hit radius, input/touch bounds, card layout, configuration, and all animal PNG pixels.
- Wide art uses the card's reserved transparent margins instead of being clipped to the old inner art rectangle; collection scrolling still clips to the page viewport.

## Evidence

- Roster parity: manifest `40`, runtime scale roster `40`, symmetric difference `0`.
- Selective scale regression: integrated `mouse`, `cat`, and `fox` report `1.35`; non-integrated `bear` reports `1.0`; rarity and procedural scales compose exactly without logical-state mutation.
- Direct-card-texture scan: all current animal card draw entry points route through the selective scale helper or the foot-anchored helper with the selective factor.
- Godot 4.6.2 editor/headless parse: exit `0`, no parser error.
- GDScript indentation: passed with tab indentation.
- `test_unit_procedural_motion.tscn`: passed.
- `test_battle_unit_inspection.tscn`: passed.
- `test_classic_battle_regression.tscn`: passed for five random-map variants.
- `test_animal_gold_economy.tscn`: passed.
- Normal main-scene startup smoke: exit `0` after three frames.
- OpenGL capture: `ANIMAL_ART_TEXTURES_PASS: 40/40` and `ANIMAL_ART_CAPTURE_PASS`.
- Player-visible evidence: 14 regenerated screenshots under `output/qa/F-ZC-ANIMAL-ART-001/`, all `720 x 1280`; deck and battle samples cover rabbit, ant, seal, sheep, pig, swan, and crane.
- Visual review: wide seal and tall crane silhouettes remain complete; no material overlap with names, health bars, buttons, or adjacent cards.
- Animal source/runtime PNG changes: `0`.

## Final hashes and boundaries

- `scripts/app/main.gd`: SHA-256 `2E8647857A2D2D9D132A6B87D6D37E3C3CB36ECDBF4C9742EB3D2E664C5DD79F`.
- `tests/test_unit_procedural_motion.gd`: SHA-256 `273D6C604CE713F78BA06247AFD7DE599A0133F8788C3088239C1109D4390403`.
- Some headless regression scenes emit resource/ObjectDB shutdown warnings after their explicit PASS result; no assertion, parse, startup, or capture failure occurred.
- No Android/Windows/Web package was rebuilt in this display-only task. `RELEASE_VISUAL_APPROVED` remains pending an exported-build and target-device review.
- Shared `scripts/app/main.gd` lock returned; task-local control intake removed.
- Reusable method candidate: none; the selective scale helper and regression remain project-local.
