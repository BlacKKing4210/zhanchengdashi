# F-ZC-RELEASE-20260811 Read-Only Receipt

## Intake

- Request: produce the current package and upload both the animal-art branch and `main`.
- Request ID: `REQ-20260811-RELEASE-AND-PUSH`.
- Feature ID: `F-ZC-RELEASE-20260811`.
- Execution level: `L3`, handled by the current accountable agent because project rules prohibit creating another agent without an explicit user request.
- RAG gate: `READY`, 8/8 golden queries, mean recall `1.0`, task context contains 9 citations.
- Producer decision: `docs/receipts/F-ZC-RELEASE-20260811-PRODUCER-DECISION-001.md`.

## Baselines

- Working branch: `codex/animal-art-integration-20260811` at `47ba0c4` before release-hygiene writes.
- Local `main`: `112057e`.
- Remote `origin/main`: `a2d6f1d965011aa52521bdcaab5b79a2a08a817b`.
- Remote feature branch: absent at preflight.
- Relationship: remote `main` -> local `main` -> current feature branch is linear; publish must stop if a fresh remote check changes this relationship.
- Existing unrelated untracked PDF and Godot import/translation files are not release inputs and must not be staged.

## Build contract

- Formal release process: `docs/RELEASE_PACKAGING.md` and `tools/package_release.ps1`.
- Platforms: Windows x64 ZIP, Android arm64 APK, Web ZIP.
- Engine: Godot `4.6.2` console, matching the only installed `4.6.2.stable` export-template set.
- Build location: isolated temporary project copy; do not stop or write through the user's live Godot 4.6.3 editor.
- Android signing: internal/debug signing only; no production keystore environment is configured.
- Effective client endpoint: `project.godot` sets `network/server_host` to `106.15.61.103`; the packaged project is not configured to use localhost or a LAN endpoint.
- Release hygiene: move the engineering source/hash manifest out of `assets/` before export so Godot does not import it as a translation resource.

## Allowed writes

- `output/qa/F-ZC-ANIMAL-ART-001/source_manifest.csv` and references to its path.
- `docs/active_scope.yaml` and `docs/receipts/F-ZC-RELEASE-20260811-*`.
- ignored release outputs under `build/windows/`, `build/android/`, and `build/web/`.
- local/remote refs for `codex/animal-art-integration-20260811` and `main`, only after package acceptance.

## Acceptance and stop conditions

- Configuration validation/export, GDScript indentation, package exports, archive CRC, required Web files, hash receipt, Windows packaged-runtime smoke, and APK structure/signing inspection must pass.
- Export logs must have no script/parse/resource-load errors attributable to the release source.
- Package contents must exclude project-only evidence, tests, tools, docs, raw configuration, and temporary RAG state.
- Published branch SHAs must equal the locally accepted release commit; `main` must move by fast-forward only.
- Stop on package failure, remote divergence, non-fast-forward main, or credential/authentication failure.

## Read-only verdict

`READY WITH CONCERNS`: Android is suitable for internal-device testing, not store production; the visual gate remains below `RELEASE_VISUAL_APPROVED` until packaged target-device review resolves the two known semantic animal-image mismatches.
