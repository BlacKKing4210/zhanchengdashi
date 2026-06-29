# Project Agent Notes

This repository is a game project foundation for `zhanchengdashi`.

## Default Workflow

- Treat tasks as game-development work unless the user says otherwise.
- Keep project assets, configuration, scripts, and documents easy to move into Godot, Unity, or Unreal later.
- Prefer data-driven gameplay: design values belong in `config/tables/`, runtime exports belong in `runtime/config/`, and validation belongs in `tools/`.
- For procedural feedback and prototype motion, prefer engine-side tween/animation/shader/particle work before requesting new sequence-frame art.
- Do not copy proprietary names, logos, characters, currencies, layouts, or assets from commercial games.

## Configuration Tables

- CSV source tables live in `config/tables/`.
- `config/schema/config_schema.json` defines fields, types, uniqueness, and cross-table references.
- Run `python tools/validate_config.py` before committing table changes.
- Run `python tools/export_config.py` to update JSON files under `runtime/config/`.

## Git Hygiene

- Keep commits focused and reviewable.
- Commit generated runtime config only when it is the expected engine-facing source.
- Do not commit local cache, build output, editor metadata, or engine-generated import caches.
