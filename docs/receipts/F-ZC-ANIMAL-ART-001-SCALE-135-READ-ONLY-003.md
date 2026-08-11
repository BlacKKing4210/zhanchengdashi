# F-ZC-ANIMAL-ART-001 Runtime Scale Read-Only Receipt

## Control state

- Request: `REQ-20260811-ANIMAL-SCALE-135`.
- Producer rule: the newly integrated animal images must display 35% larger throughout the game.
- Feature/version: `F-ZC-ANIMAL-ART-001` / `v1.1`.
- RAG: `READY`; index signature `d76d1cd4b826660d3cbb684373fd903fc1ec9412352678053f037014cf885cce`; request receipt contains 9 verified citations.
- Control fingerprint: `AB5DD4C9886383F27829DF913C3A5A274DFD936F4E7F4AD818B9ADBFE8292FAD`.
- Execution route: `L3`, current control agent acting as the unique `engineering_owner`; no new agent or task was created.
- Branch/commit baseline: `codex/animal-art-integration-20260811` at `26ed374e787650efee49ee4bc8b9df838e05a875`.

## Loaded sources and baselines

- Existing visual contract: `docs/receipts/F-ZC-ANIMAL-ART-001-VISUAL-CONTRACT.md`.
- Existing closure evidence: `docs/receipts/F-ZC-ANIMAL-ART-001-CLOSE-002.md`.
- New-image roster: 40 rows in `output/qa/F-ZC-ANIMAL-ART-001/source_manifest.csv`.
- Shared runtime file: `scripts/app/main.gd`, SHA-256 `72E44542F9B5B1E49AEB767482FB2C353FA2A005E389E55E879282EC7585ECCB`.
- Focused motion/scale regression: `tests/test_unit_procedural_motion.gd`, SHA-256 `7B4B7A82CD1F32853BFE4AF3A27A3E871E53CC9272283ED75F8E1B04155F8D22`.
- Capture path: `tests/capture_animal_art_integration.tscn`; existing before-change captures are under `output/qa/F-ZC-ANIMAL-ART-001/`.
- GDScript indentation contract: tabs from `.editorconfig`.

## Authorized implementation boundary

- Add one runtime scale rule: `1.35` for exactly the 40 card IDs registered by the new-image manifest; keep all other card art at `1.0`.
- Apply the rule consistently to lobby animals, card/deck/collection art, card detail art, living battle units, and death snapshots.
- Preserve existing rarity scaling, procedural pose scaling, draw anchors, world positions, unit tiles, collision, selection hit radius, input/touch bounds, card layout, configuration, and source PNG pixels.
- Allowed writes: `scripts/app/main.gd`, focused scale tests, this receipt and its completion receipt, task-local control state, and regenerated animal-art QA captures.
- Forbidden writes: animal PNG source/runtime pixels, CSV/JSON gameplay data, server/network code, unrelated UI, branding, package outputs, and unrelated untracked files.

## Acceptance

- All 40 manifest cards report an exact base display scale of `1.35`; representative non-integrated cards remain `1.0`.
- Existing rarity and procedural motion scales multiply the new display factor without mutating logical state.
- Every known animal draw path uses the shared display-scale rule.
- GDScript indentation, headless parse/startup, focused scale/motion regression, animal-art capture, and adjacent battle regressions pass.
- Regenerated 720x1280 player-visible captures show the larger animals without material overlap or clipping.
- Shared lock is returned and temporary task files are removed after closure.
