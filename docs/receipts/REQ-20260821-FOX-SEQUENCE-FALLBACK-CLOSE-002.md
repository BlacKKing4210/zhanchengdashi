# REQ-20260821-FOX-SEQUENCE-FALLBACK completion receipt

- Feature: `F-ZC-ANIMAL-ANIMATION-001`
- Version: `v1.0.0-fox-sequence-fallback`
- Date: `2026-08-21`
- Owner: `codex-primary`
- Status: `LOCAL IMPLEMENTATION COMPLETE / NOT PACKAGED / NOT DEPLOYED`

## Delivered behavior

1. Battlefield fox units now use the registered `idle` (13 frames at 10 FPS), `move` (15 frames at 15 FPS), and progress-sampled `attack` (10 frames) sequences.
2. The renderer resolves sequence resources through `assets/animal_sequences/manifest.json`; adding a later animal is a validated resource-and-manifest operation rather than a new fox-specific branch in `main.gd`.
3. An optional move/attack action that is not registered uses the valid idle sequence plus the existing procedural pose. An invalid sequence manifest/registration or an unregistered animal uses the pre-existing static texture plus `UnitMotionFeedback` unchanged.
4. Sequence frames are battlefield-only. Collection, deck, popup, detail, and upgrade art still use `config/tables/cards.csv::art_path`.
5. Sequence sampling is visual-only and does not change unit position, collision, HP, damage timing, cooldown, targeting, team, or network authority fields.

## Source and ingest evidence

- Supplied archive: `D:\AI\art\狐狸远程.zip`, 3,454,652 bytes.
- Archive SHA-256: `3235D0961681105B7F0F31A924C5BD4F255F6EB3DE435A1E04E857973501C0B6`.
- Ingest result: `{"frames": 38, "status": "MATCH"}`.
- All 38 original PNG payloads are retained unchanged under sanitized English paths. The manifest records every source-frame SHA-256, common source region `[230, 50, 410, 410]`, and foot-padding ratio `80/410`.
- Godot-generated `.png.import` sidecars are allowed only beside the matching source PNG; no unexpected source files are accepted by the verifier.
- Manifest: 8,537 bytes, SHA-256 `FCEDD7227EC23E2BED0F7CEB591E9B817A0101EBC8B2B1DE38F130461CFE88E6`.

## Implementation evidence

- Resolver: `scripts/app/systems/unit_sequence_animation.gd`, SHA-256 `FC6FD71C19163488EA4314E18CA27B65FF8627219CED55DD9D2642789532A2B0`.
- Narrow battle integration: `scripts/app/main.gd`, SHA-256 `23829FE79C1DD466462938D92F08EAADF57843956C0AC0041683B670FC118979`.
- Focused test: `tests/test_unit_sequence_animation.gd`, SHA-256 `245296CC2A724D72EB0D612FD20BF671409DE23B67109B0145D2A5A2A53305F9`.
- Runtime capture driver: `tests/capture_unit_sequence_animation.gd`, SHA-256 `D4E7EDF1A721A2066F193E38A10EE5EB7821A3AC425BFE70C9E562543B42A8D6`.
- Ingest tool: `tools/ingest_fox_sequence_frames.py`, SHA-256 `15D08ECCEF43ED3707369602DF4C6DF3C5DEC05440E14261D789A3CC98651544`.

## Automated verification

Godot `4.6.2.stable.official.71f334935` ran from the final implementation tree. Every listed scene exited `0`, emitted its pass marker, and had zero matches for `SCRIPT ERROR`, `Parse Error`, `TEST_FAIL`, assertion failure, segmentation fault, or signal 11:

| Scene | Result | Log SHA-256 |
|---|---|---|
| `test_unit_sequence_animation` | `UNIT_SEQUENCE_ANIMATION_TEST_PASS` | `0FB11FEBAF018E1E5233B099E9AB258BEE6AE3C126FE7680765133C4A23FC277` |
| `test_unit_procedural_motion` | `Unit procedural motion tests passed.` | `6B811BD2EF5087E78C981CE8C80355C4F427D48518328A9107B5EBE391ADCE86` |
| `test_classic_battle_regression` | pass / exit 0 | `452666148E93C027BCB0239AC977A9D03DB18EA36163DED8BDD5E75F2BA45A04` |
| `test_multiplayer_match_rules` | pass / exit 0 | `B102280F35C9CE06B44261169C1F57126F15736F5809A9B9EA5C0092A6AD14E4` |

- Regression summary SHA-256: `C0069B3EABF3B8A0805F47E012F13C1C6005AC9A4E81D80E450E8E67C2FD70E0`.
- Whole-project Godot editor import/parse: exit `0`, hard-error matches `0`, log SHA-256 `095F36FE96050B39DAF40E529378C727184C78DFEA9C9726A2A4C3E704DEF0A7`.
- GDScript indentation: `GDScript indentation check passed: tab 2.`, log SHA-256 `CB9679D9F7F1FE50C8C22227780D95FD610A293FB170AB6DFCE7A43B24346438`.
- Known non-blocking harness noise: Windows root certificate-store warning and pre-existing Godot ObjectDB/resource-leak exit warnings. No authority/state lock, game-server, or persistent local service was created by this task.

## Player-visible evidence

The final GL Compatibility runtime capture exited `0` with `FOX_SEQUENCE_FALLBACK_CAPTURE_PASS`. The capture log has zero hard-error matches and SHA-256 `8C94C83C81A3C755582FCA84E7B674FF26A9D2EFAD2F790FAE372504BE91DD29`.

| Capture | Meaning | SHA-256 |
|---|---|---|
| `fox_sequence_idle_rabbit_generic.png` | sequence fox beside unregistered generic rabbit | `D769B92245B0E6C02C1DA6231632F2FA061371CEF6318A31CB152B23FAAAE71C` |
| `fox_sequence_move_rabbit_generic.png` | fox move frame while rabbit keeps generic motion | `59B6DD0B8A85CB9F24FD0B6DABF394A87A5B6C4227422096B2C1D47E74B0277E` |
| `fox_sequence_attack_rabbit_generic.png` | fox attack frame while rabbit keeps generic attack pose | `C28B8BB01ADE057F94C1E365BBB807D2168991555F801B672FC01EC8030FD62D` |

All three 720 x 1280 captures were visually inspected. The fox uses the supplied frame art, both units remain aligned to their battlefield feet/HP bars, and the non-sequence rabbit remains visible with its earlier procedural behavior.

## Formal document evidence

- DOCX: `docs/FOX_SEQUENCE_ANIMATION_AND_GENERIC_FALLBACK_DESIGN_v1.0.docx`, 307,465 bytes, SHA-256 `000D07C9F1C27125EEB3962084E9002C1752F8027545E93B1D5AE3B7626A8D17`.
- A4 portrait, 15 mm margins, one section, 12 Heading 1 and 6 Heading 2 paragraphs, TOC/PAGE/NUMPAGES fields, 3 inline frame images with alt text, and repeating table headers.
- Accessibility audit: high `0`, medium `0`, low `0`.
- Microsoft Word rendered the final document to 7 temporary PNG pages. All pages were visually inspected; the final pages contain no clipping, overlap, mojibake, or broken table continuation.
- The temporary PDF was used only for page rendering evidence and is not a deliverable.

## RAG, release, and rollback boundaries

- Final RAG gate: `READY`, 65 sources / 898 chunks, 16/16 golden queries, mean recall `1.0`, pass rate `1.0`, index signature `a8500bfe57bf135f354f6655dbfcddac10bf0b5382af92c12c10dfac06e50b11`.
- Final task pack: `READY`, 8 citations, with the new Word contract as the four highest-ranked citations.
- Final control-plane check: `READY / L3`, no duplicate or conflicting task IDs, fingerprint `313B7D0C098B04698B86F6F170F35E0E5F6540F897A77E2394A39A23A207B01D`.
- Rollback is non-destructive: remove the fox registration/resources and the narrow resolver integration; unchanged `cards.csv::art_path` and `UnitMotionFeedback` immediately restore the previous behavior for every animal.
- No Android package was produced. No Alibaba Cloud deployment or remote write was performed for this animation task.
- Public distribution rights for the user-supplied source remain a separate release gate; this receipt proves engineering integrity and runtime behavior, not third-party rights provenance.
