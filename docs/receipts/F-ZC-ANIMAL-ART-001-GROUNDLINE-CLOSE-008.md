# F-ZC-ANIMAL-ART-001 Animal Subject Groundline Calibration Completion Receipt

## Result

- Request: `REQ-20260811-ANIMAL-VISUAL-GROUNDLINE-CALIBRATION`.
- Feature/version: `F-ZC-ANIMAL-ART-001` / `v1.3`.
- Status: `COMPLETE`; scoped visual gate: `RUNTIME_SLICE_APPROVED` at `720 x 1280`.
- Final RAG: `READY`; index signature `f735768a0f311ba2dbee01d9edc50fe56895e8131e5fe4c263d1a17ad7c779c2`; final request receipt contains 9 verified citations.
- Branch baseline: `codex/animal-art-integration-20260811` at `63eefe1cf7ef9eb59248871863dc37d7fe0ba92d`.
- Player-visible result: every newly integrated battle animal now uses its cleaned subject bottom as the foot anchor; the formerly floating sheep, parrot, seal, pig, chicken, pigeon, and smaller outliers sit at a consistent gap above the HP bar.

## Root cause and correction

- The previous pass used the lowest non-transparent source pixel. Low-alpha export-board lines and detached residue were therefore treated as part of the animal and held the real body above the logical foot.
- The deterministic cleanup audited all 40 sources and changed 20 PNGs. It cleared 5,715 low-confidence pixels that were farther than eight source pixels from every alpha-64+ subject pixel.
- Cleared alpha-64+ subject pixels: `0`. Every retained RGBA pixel, every `480 x 480` canvas, subject identity, silhouette, scale, and orientation were preserved; no crop, stretch, redraw, or generated replacement was used.
- The largest corrected bottom paddings are parrot `59 -> 127`, seal `68 -> 117`, sheep `65 -> 91`, pig `61 -> 77`, and chicken `81 -> 91` source pixels. Smaller audited corrections cover pigeon, penguin, peacock, zebra, dolphin, and lynx.
- The battle draw path still uses the existing 1.35 integrated-art scale and rarity/procedural transforms. The HP bar remains at its prior logical position, six design pixels below the logical foot.
- Unit world/tile coordinates, collision, selection/touch bounds, shadows, HP data, gameplay configuration, card/deck/detail layout, server endpoint, and network code were unchanged.

## Asset and structural evidence

- `groundline_cleanup_report.csv`: 40 rows, 20 changed sources, 5,715 removed pixels, zero alpha-64+ removals, before/after hashes, and before/after bottom paddings.
- Cleanup idempotence: a second full scan returned `CLEAN`, `changed_count=0`, `removed_pixels=0`.
- Source manifest: current SHA-256 matched for `40/40` integrated animal PNGs.
- Cleanup report final hashes: matched current files for `40/40` sources.
- Godot imported-alpha parity: configured cleaned bottom ratio matched the imported used rectangle for `40/40` integrated cards.
- Source board: `output/qa/F-ZC-ANIMAL-ART-001/groundline_source_40.png`, `1000 x 2300`.
- Runtime board: `output/qa/F-ZC-ANIMAL-ART-001/battle_groundline_runtime_40.png`, `1040 x 2500`, assembled from 40 individual `720 x 1280` OpenGL runtime captures.
- Full-screen evidence: seven regenerated battle screenshots and seven matching deck screenshots; every full screenshot is `720 x 1280`.
- Visual review: all 40 runtime cells show the subject adjacent to but not overlapping the HP bar, with no material clipping, canvas residue, or selection-ring displacement. Sheep, parrot, seal, and pig were checked as explicit outliers.

## Runtime and regression evidence

- GDScript indentation: passed with the project tab policy.
- Godot 4.6.3 editor import/parse: passed after all 20 changed textures were reimported.
- `test_unit_procedural_motion.tscn`: passed, including 40/40 groundline parity and no logical-state mutation.
- `test_battle_unit_inspection.tscn`: passed.
- `test_classic_battle_regression.tscn`: passed for five random-map variants.
- `test_animal_gold_economy.tscn`: passed.
- Main-scene startup: passed for five headless frames using an isolated task user directory and reserved TEST-NET server override.
- The first all-40 headless capture attempt was rejected after timing out without writing an image because its render callback did not fire. The accepted evidence was regenerated with the working OpenGL window renderer, which reported `ANIMAL_ART_TEXTURES_PASS: 40/40` and `ANIMAL_ART_CAPTURE_PASS`.
- Some explicit-pass headless tests retain the project's pre-existing ObjectDB/resource shutdown warnings; no assertion, parser, import, startup, or capture failure remained.

## Final hashes and boundaries

- `scripts/app/main.gd`: SHA-256 `5B6BD9AB56B31C41639E2485FE6F7162C2ED45FDC2204C5310CFEF295403973C`.
- `tests/test_unit_procedural_motion.gd`: SHA-256 `A1EC2936609408CEFA62A4CC2FE281D84C8DC29D7DF4EECDD681D872323DD70C`.
- `tests/capture_animal_art_integration.gd`: SHA-256 `54FFF38C8956A8535B627920FE178E082311DBEBFDB0DE044EC0F5B75AD77EF5`.
- `tools/clean_integrated_animal_art.py`: SHA-256 `D9A5FA22B5ACFC4B0713C4151FE0AD62C3ABC5EAD81855E6B4A15C84CF27E409`.
- Cleanup report: SHA-256 `5A37B46B6ECA983E7318F53CC59A13A67697FF0CB2222AB327A6E69B84A0F347`.
- Source board: SHA-256 `031F07F2BDE50A908D6E30C1D8668B4AAADDAF84AF2AED4FA71B579CFC225945`.
- Runtime board: SHA-256 `751E60E9E05B223B524C1F342625A879D325571CA6F4C439CEB19B8A0B5F8D86`.
- Gameplay CSV/runtime JSON changes: `0`. Server/network changes: `0`. Package rebuilds: `0`.
- Shared battle-animal source and groundline lock returned. No temporary or unrelated file is included in the delivery.
