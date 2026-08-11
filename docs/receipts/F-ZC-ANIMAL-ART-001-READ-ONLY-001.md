# F-ZC-ANIMAL-ART-001 Read-Only Receipt

- Request: `REQ-20260811-ANIMAL-ART-INTEGRATION`
- Feature: `F-ZC-ANIMAL-ART-001`
- Date: `2026-08-11`
- Project root: `D:\AI\zhanchengdashi`
- Branch: `codex/animal-art-integration-20260811`
- Baseline commit: `38c7793`
- Producer authority: the user explicitly requested that the images under `D:\AI\art\草图导出` be implemented in the game.
- Unique writer: `codex_primary`
- Execution level: `L1 direct_execute`

## RAG Gate

- Project gate: `tmp/rag/receipts/rag-gate.json`
- Task receipt: `tmp/rag/receipts/tasks/REQ-20260811-ANIMAL-ART-INTEGRATION.json`
- Context pack: `tmp/rag/context/REQ-20260811-ANIMAL-ART-INTEGRATION.md`
- Index signature: `b4a869ae8e04cebfb398181a59ebdc78e32e01d9629d69883f9b7831f9a02fb2`
- Golden-query result: `8/8 PASS`, mean recall at K `1.0`
- Task citations: `8`

## Loaded Skills

- `game-studio-orchestrator`
- `game-project-control-plane`
- `game-project-rag`
- `game-visual-quality-pipeline`
- `godot-feature-slice-implementation`
- `codex-game-studio-default` (supplementary)

## Source And Runtime Contract

- Source set: 40 producer-supplied transparent PNG files under `D:\AI\art\草图导出`.
- Runtime target: the first 40 animal art paths in `config/tables/cards.csv`, from `mouse` through `lynx`.
- Runtime load path: `scripts/app/main.gd::_card_texture()` loads each card's `art_path`; the same texture is used by deck/card views, building preview, selected-unit view, and battle-unit drawing.
- Source mechanical result: 40/40 files exist, 40/40 are `480 x 480` RGBA, 40/40 have transparent canvas edges, and all 40 target files exist.
- Existing Godot editor process is treated as user-owned. It must not be closed. Import and runtime QA will use an isolated project copy.

## Allowed Writes

- `assets/card_art/animals/{mouse..lynx}.png` for the exact 40 mapped IDs.
- `assets/card_art/animals/source_manifest.csv`.
- `tests/capture_animal_art_integration.gd` and `.tscn`.
- `docs/receipts/F-ZC-ANIMAL-ART-001-*.md`.
- `docs/active_scope.yaml` for the task-level owner and lock lifecycle.
- `output/qa/F-ZC-ANIMAL-ART-001/*.png` for player-visible QA evidence.

## Non-Goals

- Do not change card IDs, Chinese names, rarity, stats, skills, voices, decks, economy, layouts, click targets, motion code, or server behavior.
- Do not replace the remaining 20 legendary animal images that have no producer-supplied source in this batch.
- Do not modify or stop the user's running Godot editor.

## Concerns And Mapping Decision

- `天鹅（章鱼）.png` maps to existing `swan.png`; the artwork reads as an octopus while the existing card remains `天鹅`.
- `鹤（鹅）.png` maps to existing `crane.png`; the artwork reads as a goose while the existing card remains `鹤`.
- These two mappings follow the producer-supplied leading filename and preserve the asset-only scope. Renaming cards or redesigning skills requires a separate producer decision.

## Acceptance

1. All 40 target PNG hashes exactly match their mapped source PNG hashes.
2. Existing `cards.csv` and `runtime/config/cards.json` paths continue to resolve without fallback textures.
3. A representative rabbit slice is captured in the real Godot rendering path before scale-out.
4. After scale-out, target-resolution captures prove representative small, wide, tall, and substitution-labelled animals in deck and battle contexts.
5. Config validation/export and scoped Godot regressions pass in an isolated copy; normal runtime starts without parser or resource errors.
6. Only authorized project files change, temporary isolated copies are removed, and the task lock is released at closure.

## Verdict

`READY WITH CONCERNS`: proceed with the rabbit representative slice, review runtime evidence, then scale out only if the slice has no blocking visual or import issue.
