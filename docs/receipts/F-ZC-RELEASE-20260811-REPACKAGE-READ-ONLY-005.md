# F-ZC-RELEASE-20260811 Animal Groundline Repackage Read-Only Receipt

## Intake

- Request: rebuild the current package and upload the accepted source to Git.
- Request ID: `REQ-20260811-ANIMAL-GROUNDLINE-REPACKAGE-PUBLISH`.
- Feature IDs: `F-ZC-RELEASE-20260811`, `F-ZC-ANIMAL-ART-001`.
- Accountable producer: `producer_user`.
- Execution owner: `codex_primary`; no separate agent was created.
- RAG gate: `READY`, 8/8 golden queries passed with mean recall `1.0`; the request-specific context receipt is `tmp/rag/receipts/tasks/REQ-20260811-ANIMAL-GROUNDLINE-REPACKAGE-PUBLISH.json`.

## Accepted baseline

- Working branch: `codex/animal-art-integration-20260811` at `81e5f781d5a48a3e80bbd763e7af33caeb48190d`.
- The accepted delta after the last published feature commit is `63eefe1` plus `81e5f78`, covering first-pass HP-bar alignment and per-animal groundline calibration.
- Refreshed remote baseline: `origin/main` at `1d128e7fbb8b271c7c615d0f5c7a3066831346a9`; `origin/codex/animal-art-integration-20260811` at `50e1d31a8e4a9ec7222438922160b48508587cd1`.
- Both remote refs are ancestors of the accepted working baseline. Publication is allowed only as a non-force fast-forward and must be rechecked immediately before push.
- Existing untracked Godot `.import`/translation files, `output/pdf/current-game-style-reference-reset.pdf`, and `tmp_line_crop.png.import` are unrelated and excluded from staging.

## Build and verification contract

- Follow `docs/RELEASE_PACKAGING.md` and `tools/package_release.ps1`; refresh Windows x64, Android arm64, and Web packages.
- Use a unique archive suffix for this second same-day build so the earlier `2026-08-11` artifacts are not mistaken for the groundline-calibrated package.
- Validate and export configuration before package export.
- Android must remain portrait-only at 1080 x 1920, declare Internet permission, package as `com.blackking4210.junglelaw`, include the approved icon/loading art, and retain the effective endpoint `106.15.61.103:24567` rather than localhost, loopback, or a LAN address.
- Inspect hashes, archive integrity, required Web files, export logs, Windows packaged-runtime startup, APK signature/manifest/ABI, and the inclusion of the 40 new animal assets and calibration data.
- Android target-device installation and live Alibaba Cloud service acceptance are separate gates; the deployment profile does not authorize remote server writes in this task.
- Release binaries remain ignored under `build/` and must not be committed.

## Read-only verdict

`READY WITH CONCERNS`: the source and fast-forward topology are eligible for packaging and publication. Internal Android distribution remains debug-signed unless a production keystore is supplied; device-level install, live cloud connection, and final exported-build visual capture must be reported honestly if unavailable.
