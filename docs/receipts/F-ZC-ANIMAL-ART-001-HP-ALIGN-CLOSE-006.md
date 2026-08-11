# F-ZC-ANIMAL-ART-001 Battle Animal / HP Bar Alignment Completion Receipt

## Result

- Request: `REQ-20260811-ANIMAL-FOOT-HP-ALIGNMENT`.
- Status: `COMPLETE`; visual gate for this scoped runtime correction: `RUNTIME_SLICE_APPROVED` at `720 x 1280`.
- Branch baseline: `codex/animal-art-integration-20260811` at `50e1d31a8e4a9ec7222438922160b48508587cd1`.
- Final RAG: `READY`; index signature `f7894a35934a3a541f3c866e94540ec3f7da8be3791374e7c5f1dee76c312d5a`; final task receipt contains 9 verified citations.
- Player-visible result: the 40 newly integrated battle animals now sit consistently just above their fixed HP bars instead of floating above them by the source PNG's scaled transparent bottom padding.

## Implemented behavior

- Reused the existing 40-card integrated-art roster as an exact per-card transparent-bottom ratio map derived from each `480 x 480` source PNG.
- The living battle-unit draw path shifts only the texture rectangle in local draw space; each visible alpha silhouette now ends at the existing logical foot point.
- The HP bar remains at `pos.y + 20` while the logical foot remains at `pos.y + 14`, preserving the intended 6-design-pixel idle gap.
- The correction is local-space and composes with the existing 1.35 display scale, rarity scale, procedural scale, rotation, and offset.
- Non-integrated animals resolve to zero compensation. Card/deck/detail art and death effects retain their prior anchors.
- World/tile coordinates, collision, selection/touch bounds, shadow, HP values, HP-bar coordinates, gameplay configuration, source PNG pixels, and server/network behavior were not changed.

## Evidence

- Imported-alpha parity: all `40/40` integrated textures had their Godot-imported alpha used rectangle recomputed; every measured bottom-padding ratio matched the configured value.
- Representative alignment math: parrot (`59 px`), rabbit (`106 px`), and pigeon (`145 px`) all resolve to visible local alpha bottom `0.0`, the existing logical foot.
- Non-integrated regression: bear resolves to padding ratio `0.0` and keeps the original foot rectangle.
- GDScript indentation: passed with the project tab policy.
- Godot 4.6.2 editor parse: passed with exit `0`.
- `test_unit_procedural_motion.tscn`: passed, including 40/40 alpha parity and no logical-state mutation.
- `test_battle_unit_inspection.tscn`: passed.
- `test_classic_battle_regression.tscn`: passed for five random-map variants.
- `test_animal_gold_economy.tscn`: passed.
- Normal main-scene startup smoke: exit `0` after three frames.
- OpenGL capture: `ANIMAL_ART_TEXTURES_PASS: 40/40` and `ANIMAL_ART_CAPTURE_PASS`.
- Player-visible evidence: seven regenerated battle screenshots under `output/qa/F-ZC-ANIMAL-ART-001/`, all `720 x 1280`, covering rabbit, ant, seal, sheep, pig, swan, and crane.
- Visual review: all seven show the animal silhouette adjacent to but not overlapping the HP bar; no material clipping or selection-ring regression was found.
- Some headless scenes emit pre-existing ObjectDB/resource shutdown warnings after their explicit PASS result; no assertion, parser, startup, or capture failure occurred.

## Final hashes and boundaries

- `scripts/app/main.gd`: SHA-256 `8F3A336AFC0C3EA1397EFF97A2DFBA742313CAC7E6667B2F9D010B258FD814C7`.
- `tests/test_unit_procedural_motion.gd`: SHA-256 `59477B4374DDAB41F652AC5E8D0E1347353E7742EC58B60B18359AAFB23128D2`.
- Animal source/runtime PNG changes: `0`.
- Configuration/runtime JSON changes: `0`.
- No Android, Windows, or Web package was rebuilt for this scoped visual correction.
- Shared battle-animal rendering lock returned; task-local control intake removed.
- Reusable method candidate: none; the per-card ratios are project- and asset-specific.
