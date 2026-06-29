# zhanchengdashi

`zhanchengdashi` is prepared as a data-driven Godot game project foundation. The configuration pipeline stays portable CSV/JSON, while the current Godot project can already load exported runtime config through the `ConfigDB` autoload.

## Project Layout

```text
assets/             Art, audio, UI, and other source assets
config/schema/      Configuration table schema
config/tables/      CSV source tables edited by designers
docs/               Process, Git, and config-table documentation
runtime/config/     JSON config exported for game runtime use
scenes/             Godot scenes
scripts/            Godot gameplay and support scripts
tests/              Automated tests and QA fixtures
tools/              Local validation/export utilities
```

## Configuration Workflow

Validate source tables:

```powershell
python tools/validate_config.py
# or: py -3 tools/validate_config.py
```

Export runtime JSON:

```powershell
python tools/export_config.py
# or: py -3 tools/export_config.py
```

The exported files are written to `runtime/config/`.

## GitHub Remote

The repository is configured for:

```text
git@github.com:BlacKKing4210/zhanchengdashi.git
```

Recommended branch flow is documented in `docs/GIT_WORKFLOW.md`.

## Current Foundation

- Generic game repo structure
- Git ignore and line-ending rules
- Designer-editable CSV config tables
- Schema-based config validation
- JSON runtime export tool
- Godot `ConfigDB` autoload for runtime config access
- Minimal Godot main scene
- GitHub Actions config validation workflow
- Project foundation documentation with PDF review output
