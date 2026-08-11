# F-ZC-RELEASE-20260811 Animal Groundline Repackage Acceptance

## Decision

- Request: `REQ-20260811-ANIMAL-GROUNDLINE-REPACKAGE-PUBLISH`.
- Package status: `ACCEPTED_FOR_INTERNAL_DISTRIBUTION`.
- Exact packaged source: `codex/animal-art-integration-20260811` at `499b3314cf234ae5c25665907786a1e5c12f0a6d`.
- Engine/template: Godot `4.6.2.stable.official.71f334935` with the installed `4.6.2.stable` Windows, Android, and Web export templates.
- Build method: `tools/package_release.ps1` in an isolated temporary project created from `git archive HEAD`; the user's live Godot 4.6.3 project cache was not used as the build workspace.
- Two earlier same-task candidates were rejected after Godot scanned `knowledge/*.csv` as translation inputs and emitted three optimized-translation errors. The accepted source excludes `knowledge/` from every export preset and adds `knowledge/.gdignore`; the final export has no RAG scan/import/export errors and no knowledge payload.

## Final artifacts

| Platform | Fixed artifact | Versioned artifact | Bytes | SHA-256 |
| --- | --- | --- | ---: | --- |
| Windows x64 | `build/windows/JungleLaw-windows-x64.zip` | `build/windows/JungleLaw-windows-x64-2026-08-11-groundline-r2.zip` | 60,136,474 | `E73FAA8AE34B5F57F84140BF13F4167BB703C3EED39705D8598BFCA84BC8F008` |
| Android arm64 | `build/android/JungleLaw-android.apk` | `build/android/JungleLaw-android-2026-08-11-groundline-r2.apk` | 50,812,055 | `7F866CB6C39C10FE9C1356175FEA51D9D9D928ED7C33567AFD823F7160DA67AB` |
| Web | `build/web/JungleLaw-web.zip` | `build/web/JungleLaw-web-2026-08-11-groundline-r2.zip` | 38,598,855 | `9830739CF7D4F7B8E6C4EA19ED463B769C99D5D93281279D2E577E58EDB8304D` |

Each fixed artifact and its matching versioned archive have identical hashes. Stage-to-project copy verification passed `6/6`.

## Verification

- Configuration validation/export: passed, 16 tables / 387 rows.
- Final Android, Web, and Windows export logs: no actual `ERROR:`, script error, parse error, failed-resource error, `knowledge/` save, or translation-resource save.
- Full entry streaming: passed for all three fixed artifacts. Windows ZIP has one entry (`JungleLaw.exe`); Android APK has 422 entries; Web ZIP has 9 entries and the required HTML, JS, WASM, and PCK files.
- Windows packaged-runtime smoke: exit `0` after five headless frames with a reserved TEST-NET endpoint override; no script, parse, resource-load, or runtime error. The pre-existing ObjectDB shutdown warning remains non-blocking.
- Android manifest: package `com.blackking4210.junglelaw`, label `丛林法则`, version `1.0.0`, min SDK 24, target/compile SDK 35, `arm64-v8a` only, `android.permission.INTERNET`, portrait feature, and main activity `screenOrientation=1`.
- Android orientation is therefore locked to portrait at the package manifest level; the source project remains 1080 x 1920 with handheld orientation `1`.
- Android signature: verified with APK Signature Scheme v2 and v3, one RSA-2048 Godot internal/debug signer. It is not a production/store signing identity.
- Approved cloud endpoint: packaged `project.binary` contains `network/server_host` and `106.15.61.103`; the accepted effective endpoint is `106.15.61.103:24567` and is not localhost, loopback, or a LAN address.
- Integrated animal package check: all `40/40` source-manifest targets have both an APK import entry and its compiled texture. The accepted groundline calibration remains the code/assets from commits `63eefe1` and `81e5f78`.
- Branding package check: `2/2` approved resources (`app_icon_1024.png`, `loading_portrait_1080x1920.png`) have import metadata and compiled textures; the packaged project settings reference both.
- Project-only leakage: zero APK entries for RAG, knowledge, receipts, docs, tests, tools, output, temporary files, or raw config sources.

## Remaining boundaries

- No Android device was connected (`adb devices` returned an empty device list), so APK installation, target-device launch, device screenshot/performance, and real phone-to-cloud login remain unverified.
- `aapt2` retains the known non-blocking warning that an optional adaptive themed-icon XML is missing; the normal application icon is present.
- No Alibaba Cloud server write or restart was authorized or performed. The release proves client package configuration, not live service health.
- Visual acceptance remains `RUNTIME_SLICE_APPROVED` for the 40-animal groundline calibration and is not promoted to `RELEASE_VISUAL_APPROVED` without exported Android-device capture.
- Release binaries remain ignored under `build/` and are not Git content.
