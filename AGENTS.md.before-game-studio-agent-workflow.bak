# Project Agent Notes

This repository is a game project foundation for `zhanchengdashi`.

## Default Workflow

- Treat tasks as game-development work unless the user says otherwise.
- Use the public workflow at `C:\Users\76398\Documents\Codex\2026-07-03\codex-game-studio-default\outputs\codex-game-studio-general-game-development-process.md` as the upstream game-development process when available.
- Use `docs/DEVELOPMENT_WORKFLOW.md` as this project's adaptation of the public workflow.
- Follow a document-first workflow for every future gameplay, balance, UI, system, or technical change: update the relevant design/workflow document first, then implement the matching game change.
- Deliver user-facing narrative documents as Word `.docx` by default. Markdown may remain as the source-controlled authoring format; PDF is generated only when explicitly requested for fixed-layout, print, signature, or archive use.
- Deliver user-facing table-heavy artifacts as Excel `.xlsx` by default. Small supporting tables may stay inside Word, while runtime CSV/JSON and other machine-readable files remain governed by the project's data pipeline.
- Keep project assets, configuration, scripts, and documents easy to move into Godot, Unity, or Unreal later.
- Prefer data-driven gameplay: design values belong in `config/tables/`, runtime exports belong in `runtime/config/`, and validation belongs in `tools/`.
- Follow the upstream professional art production flow from the public workflow v1.6+ for any visual-direction, concept-art, UI-art, sprite, map, VFX, or presentation-quality change.
- Follow the upstream UI/UE workflow from public workflow v1.9+: formal UI/UE sources must be editable Figma/FigJam links or `.fig` references; draw.io, Axure, XD, Markdown, Mermaid, and static screenshots are drafts or review exports, not final UI/UE sources.
- Before implementing an approved UI effect image or Figma page, require a source reference, design token map, component state matrix, Godot UI plan, responsive/safe-area rules, screenshot parity baseline, and UI QA checklist.
- This project is 2D-first. Art-facing work routes through: Producer -> Creative Director -> Art Director -> Visual Development Artist -> Concept Artist / Environment Artist / UI Artist -> 2D Animation Specialist -> Sprite Forge Specialist -> 2D Technical Artist -> Godot Specialist -> QA Lead.
- Treat Sprite Forge as an execution and handoff role after art direction is approved; it does not replace Art Director, Visual Development, Concept, Environment, or UI Artist judgment.
- For current game visual direction, create multi-version effect images first, save review outputs under `output/visual_concepts/`, document them in `docs/CURRENT_GAME_VISUAL_CONCEPT_OPTIONS.md`, and wait for user approval before implementing engine, UI, or asset changes based on them.
- For current UI effect-image work, route review through Producer -> Art Director -> UI Artist -> UI Programmer -> QA Lead, iterate until P0/P1 issues are cleared, and do not modify runtime UI, scenes, scripts, resource bindings, input logic, or click targets until the user explicitly says to implement.
- For page art upgrades, lock UE completely: page information, layout, click targets, control positions, state meanings, and click feedback timing must remain unchanged. Only 2D visual skin, palette, materials, borders, shadows, icons, and illustration polish may change.
- For skin-only page mockups, derive every preview from the current Godot page coordinates or the approved UI/UE wireframe. Any mockup that adds, removes, moves, renames, or reorders controls, resources, page sections, navigation, buttons, or feedback states is invalid.
- For 2D page art, prefer simple high-quality 2D: fewer shapes, colors, layers, and states; improve proportion, spacing, contrast, material restraint, reusable components, and readability instead of adding complexity.
- For procedural feedback and prototype motion, prefer engine-side tween/animation/shader/particle work before requesting new sequence-frame art.
- Do not copy proprietary names, logos, characters, currencies, layouts, or assets from commercial games.

## Godot / GDScript Indentation Safety

- Treat GDScript indentation as syntax-critical. Godot will fail to parse files that mix tabs and spaces, and a blind tab/space replacement can flatten block structure and create follow-up parser errors.
- Before editing any `.gd` file, check the project's `.editorconfig` `[*.gd]` rule and preserve that indentation style. For Godot projects, prefer Godot's default tab indentation unless the project has a fully enforced alternative.
- If a Godot project changes indentation policy, update `.editorconfig`, CI/check scripts, and all `.gd` files in one focused change. Never partially convert only touched lines.
- After any `.gd` edit, run the project's GDScript indentation check when available and launch/parse the Godot project to verify there are no parser errors before committing.
- When fixing indentation parser errors, restore or compare against the last known-good block structure first, then normalize indentation. Do not use mechanical tab-to-space or space-to-tab conversion without preserving nesting depth.

## Configuration Tables

- CSV source tables live in `config/tables/`.
- Excel `.xlsx` is the default human-facing review/edit format for table-heavy deliverables, but it does not silently replace the existing authoritative CSV source or runtime JSON pipeline. Any workbook-to-CSV synchronization must be explicit and validated.
- `config/schema/config_schema.json` defines fields, types, uniqueness, and cross-table references.
- After any user or Codex change to `config/tables/*.csv`, immediately run `python tools/validate_config.py` and `python tools/export_config.py` in the same task so the generated JSON under `runtime/config/` reflects the CSV before testing, committing, or pushing.
- Godot runtime reads `runtime/config/*.json`, not the CSV source tables directly; never leave CSV edits without the matching runtime export.
- Keep CSV source tables UTF-8 or UTF-8 BOM. If a user-edited CSV is saved as ANSI/GBK, convert it to UTF-8 while preserving the user's values before validating/exporting.

## Git Hygiene

- Keep commits focused and reviewable.
- After each completed modification task, commit the changes and push the current branch to GitHub unless the user explicitly says not to.
- Commit generated runtime config only when it is the expected engine-facing source.
- Do not commit local cache, build output, editor metadata, or engine-generated import caches.
