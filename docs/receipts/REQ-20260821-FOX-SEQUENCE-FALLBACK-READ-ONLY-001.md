# REQ-20260821-FOX-SEQUENCE-FALLBACK read-only receipt

- Feature: `F-ZC-ANIMAL-ANIMATION-001`
- Date: `2026-08-21`
- Owner: `codex-primary` (existing engineering owner)
- User objective: ingest the supplied fox sequence frames and establish a reusable runtime rule: registered animals use their available frame actions; animals without registered frame actions retain the current generic procedural motion.
- Document class: `IMPLEMENTATION_CONTRACT / NARROW`, using the approved simple feature template.
- RAG gate: `READY`, index `9f83187ede486de13ce88eb833a2f0c028f879ad0b0d112b079bc06c00bc58be`, 16/16 golden queries, mean recall and pass rate `1.0`.
- Task receipt: `temp/rag/receipts/tasks/REQ-20260821-FOX-SEQUENCE-FALLBACK-001.json`, 8 citations.

## Approved observable behavior

1. Battlefield fox units use `idle`, `move`, and `attack` frames from a validated data-driven sequence manifest.
2. Sequence selection changes visuals only. Unit position, collision, target selection, damage timing, cooldowns, networking authority, and card configuration remain unchanged.
3. A registered animal whose optional move/attack action is not present falls back safely to the existing procedural pose applied to a valid idle frame; an invalid manifest/registration or an animal with no registration uses the current static card texture and existing `UnitMotionFeedback` behavior unchanged.
4. Card collection, deck, popup, and non-battle art continue to use `config/tables/cards.csv::art_path`; the new sequences are a battlefield-unit layer only.
5. The loader rejects malformed manifests, unsafe resource paths, missing frames, inconsistent frame metadata, and invalid source rectangles without breaking battle rendering.

## Source asset audit

- Supplied archive: `狐狸远程.zip`, 3,454,652 bytes, SHA-256 `3235D0961681105B7F0F31A924C5BD4F255F6EB3DE435A1E04E857973501C0B6`.
- Archive groups recovered from raw UTF-8 names: `狐狸行走` (15 frames), `狐狸施法` (10 frames), and `狐狸待机1` (13 frames).
- All 38 files are `836 x 480` RGBA PNGs; every canvas edge is fully transparent.
- Shared visible bounds are stable enough for one non-destructive source region. Source pixels remain unchanged; runtime crops the common region rather than baking resized derivatives.
- The source was supplied by the producer for this project. Broader public-distribution rights are not independently certified by this engineering receipt and remain a release-level check.

## Baseline

- Branch / HEAD: `codex/animal-art-integration-20260811` / `07dc5950b0d57c9fa929d93916ad6767ab4790a1`.
- Godot: `4.6.2.stable.official.71f334935`.
- `scripts/app/main.gd` SHA-256: `D9A6347B02206500AF1920E0471FC4CCCBE61B3F32CC659CAF4FE392F2E39D02`.
- `scripts/app/systems/unit_motion_feedback.gd` SHA-256: `AFCA4FDBF3C56962B221573B9A882B5899E8F31CA3CD6B285FAA9684A16C8559`.
- `tests/test_unit_procedural_motion.gd` SHA-256: `9AC411E0448CD88633DD6F1F66E6F16B03F480ED64B405FAC06DB75A4CEA81FD`.
- Fox identity and static art remain authoritative in `config/tables/cards.csv::fox` and `runtime/config/cards.json`; neither file is in this task's write set.
- The worktree contains unrelated admin-dashboard/deployment changes. They must remain untouched and must not enter this task's staged diff.

## Write scope

- Task coordination: `docs/active_scope.yaml`, `knowledge/knowledge_manifest.csv`, this receipt, and the matching close receipt.
- Formal Word contract and deterministic builder.
- A validated ingest helper, manifest, and sanitized English asset paths under `assets/animal_sequences/fox/`.
- One reusable sequence resolver plus a narrow integration in `scripts/app/main.gd`.
- Focused selection/fallback tests and a runtime capture scene.
- Temporary evidence only under `temp/qa/F-ZC-ANIMAL-ANIMATION-001/fox-sequence-fallback/`.

## Non-goals

- No balance, stats, cooldown, targeting, network protocol, card-art, UI layout, or input changes.
- No frame generation, repainting, interpolation, or replacement of animals that were not supplied.
- No Android packaging, Alibaba Cloud deployment, or persistent local server process.

## Acceptance evidence

1. The ingest helper reproduces the exact 38 PNG hashes from the approved archive, writes only allowlisted paths, and rejects traversal, unexpected files, frame gaps, wrong dimensions, or wrong archive hash.
2. Focused Godot tests prove fox idle/move/attack frame selection, missing-action fallback, non-fox generic fallback, invalid-manifest fallback, stable source region, and unchanged logical unit state.
3. Existing procedural-motion regression remains green.
4. Godot import/parse and GDScript tab-indentation checks pass from the exact working tree.
5. A real runtime capture shows a fox using frame animation alongside a non-sequence animal using the generic motion path; capture evidence is not substituted by an asset inventory.
6. The final DOCX renders to PNG and all pages pass visual inspection.

## Gate statement

`READY FOR LOCKED DOCUMENT AND IMPLEMENTATION WORK`. Updating indexed formal sources makes the current RAG receipt stale; refresh the RAG gate and task pack before runtime promotion or closure.
