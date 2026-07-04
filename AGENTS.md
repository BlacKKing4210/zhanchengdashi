# Project Agent Notes

This repository is a game project foundation for `zhanchengdashi`.

## Default Workflow

- Treat tasks as game-development work unless the user says otherwise.
- Use the public workflow at `C:\Users\76398\Documents\Codex\2026-07-03\codex-game-studio-default\outputs\codex-game-studio-general-game-development-process.md` as the upstream game-development process when available.
- Use `docs/DEVELOPMENT_WORKFLOW.md` as this project's adaptation of the public workflow.
- Follow a document-first workflow for every future gameplay, balance, UI, system, or technical change: update the relevant design/workflow document first, then implement the matching game change.
- Keep project assets, configuration, scripts, and documents easy to move into Godot, Unity, or Unreal later.
- Prefer data-driven gameplay: design values belong in `config/tables/`, runtime exports belong in `runtime/config/`, and validation belongs in `tools/`.
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
- `config/schema/config_schema.json` defines fields, types, uniqueness, and cross-table references.
- Run `python tools/validate_config.py` before committing table changes.
- Run `python tools/export_config.py` to update JSON files under `runtime/config/`.

## Git Hygiene

- Keep commits focused and reviewable.
- After each completed modification task, commit the changes and push the current branch to GitHub unless the user explicitly says not to.
- Commit generated runtime config only when it is the expected engine-facing source.
- Do not commit local cache, build output, editor metadata, or engine-generated import caches.
