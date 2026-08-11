# F-ZC-ANIMAL-ART-001 Animal Subject Groundline Calibration Read-Only Receipt

## Control state

- Request: `REQ-20260811-ANIMAL-VISUAL-GROUNDLINE-CALIBRATION`.
- Producer-approved outcome: correct every newly integrated animal that still appears too far above its battle HP bar; source-image alignment and position changes are allowed.
- Feature/version: `F-ZC-ANIMAL-ART-001` / `v1.3`.
- RAG: `READY`; index signature `f7894a35934a3a541f3c866e94540ec3f7da8be3791374e7c5f1dee76c312d5a`; request receipt contains 9 verified citations.
- Control route: `L3`; the current control agent is the unique `engineering_owner` and `art_owner` for this bounded correction. No new agent or task is created.
- Task fingerprint: `B09A8FE5ABEEFDE5145F3F9E15B5C0FB410EF86F3DB76D4A63D290D3ECC9BBC6`.
- Branch/commit baseline: `codex/animal-art-integration-20260811` at `63eefe1cf7ef9eb59248871863dc37d7fe0ba92d`.

## Read-only diagnosis

- The previous correction aligned the lowest non-transparent source pixel to the logical battle foot. That pixel is not always part of the animal.
- The 40-source audit found low-alpha board/export residue outside several animal silhouettes. The largest false-bottom gaps are parrot (`69` source pixels), seal (`57`), and sheep (`22`); chicken, pigeon, pig, penguin, peacock, zebra, dolphin, and others have smaller residue or sparse edge outliers.
- At the existing 1.35 battle display scale, those false bottoms keep the actual body above the logical foot even though the mathematical alpha-bottom check passes.
- Unit world/tile coordinates, collision, selection/touch bounds, shadows, HP values, and HP-bar coordinates are not the cause.

## Approved implementation rule

- Clean only low-confidence canvas residue: an original pixel may be cleared only when its alpha is below `64` and it lies more than `8` source pixels from every alpha-`64+` subject pixel.
- Preserve the `480 x 480` canvas, all retained RGBA pixels, identity, silhouette, scale, and source orientation. Do not crop, stretch, repaint, or generate replacement art.
- Record before/after hashes, removed-pixel counts, and measured subject-bottom padding for the complete 40-card roster.
- Replace the old false-alpha-bottom anchors with the cleaned subject-bottom anchors for battle drawing only.
- Keep the existing 1.35 integrated-art scale and keep the HP bar at its current position, six design pixels below the logical foot.
- Preserve rarity scaling, procedural pose transforms, world/tile coordinates, collision, selection/touch bounds, card/deck/detail layouts, death effects, gameplay configuration, and server/network behavior.

## Write ownership

- Source cleanup tool: `tools/clean_integrated_animal_art.py`.
- Potentially changed source art is limited to the 20 audited PNGs declared in the task control intake; the tool must leave every zero-removal PNG byte-for-byte untouched.
- Runtime/test writes: `scripts/app/main.gd`, `tests/test_unit_procedural_motion.gd`, and `tests/capture_animal_art_integration.gd`.
- Evidence writes: the feature source manifest, cleanup report, 40-source board, 40-unit runtime board, seven existing representative battle captures, the seven matching deck captures emitted by the same QA scene, this receipt, the closure receipt, and `docs/active_scope.yaml`.
- Forbidden writes: gameplay CSV/JSON, unrelated UI/branding, packages, server/network code, main-branch state, and unrelated tracked or untracked files.

## Acceptance

- Cleanup is idempotent and removes no alpha-`64+` pixel; all 40 canvases remain `480 x 480`.
- Every configured battle groundline matches the cleaned imported texture bottom for all `40/40` integrated cards.
- A target-resolution runtime board covers all 40 animals and shows no material floating, HP-bar overlap, or clipping at idle pose.
- The seven representative `720 x 1280` battle screenshots are regenerated, including parrot-risk proxies seal/sheep and the smaller pig case.
- GDScript indentation, Godot editor parse/startup, focused alignment tests, adjacent battle regressions, and capture all pass.
- The task closes only after player-visible review and lock return.
