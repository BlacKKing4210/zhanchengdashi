# F-ZC-RELEASE-20260811 Package Acceptance

## Decision

- Package status: `ACCEPTED_FOR_INTERNAL_DISTRIBUTION`.
- Source branch baseline: `codex/animal-art-integration-20260811` at `47ba0c4`, plus the release-hygiene changes recorded in this delivery commit.
- Engine/template version: Godot `4.6.2.stable.official.71f334935` with installed `4.6.2.stable` Windows/Android/Web templates.
- Build method: `tools/package_release.ps1` in an isolated temporary project copy; the user's live Godot 4.6.3 editor was not stopped or used as the build workspace.
- Release visual state: remains `SCALE_OUT_APPROVED WITH CONCERNS`, not `RELEASE_VISUAL_APPROVED`; exported packages exist, but no Android target-device install/capture or packaged player-visible parity review was performed.

## Artifacts

| Platform | Fixed artifact | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| Windows x64 | `build/windows/JungleLaw-windows-x64.zip` | 51,020,372 | `9FACA36C47CB6FE915FDC13515784C01F17D87535EDC7AE90D40253D0C9A8DA0` |
| Android arm64 | `build/android/JungleLaw-android.apk` | 40,940,111 | `35AF8CF5B2CE89AB4238F560C0DCBBBF8722E143AA864BF83ED9EE8197705BD8` |
| Web | `build/web/JungleLaw-web.zip` | 24,502,384 | `182435D9B2AB7182EB02EF842C3A01B0658A46C810CF3A8D41804A6069AE3C45` |

The matching `-2026-08-11` archives have identical hashes to their fixed-name counterparts.

## Verification

- Stage package script: exit `0`.
- Configuration validation/export: passed; 16 tables / 387 rows; stage and live runtime JSON hashes match.
- Android, Web, and Windows export logs: 3/3 present with zero `SCRIPT ERROR`, parse-error, failed-resource, or generic error matches.
- Full ZIP/APK entry streaming: passed for Windows ZIP, Android APK, and Web ZIP.
- Windows ZIP contents: exactly `JungleLaw.exe`.
- Windows packaged-runtime smoke: exit `0` after five headless frames; zero script, parse, or failed-resource errors. A reserved TEST-NET endpoint was supplied for the smoke so no real account server was touched.
- Web ZIP: required HTML/JS/WASM/PCK files present; zero forbidden project-only paths.
- Binary leak scan across fixed Windows/Android/Web artifacts: zero matches for QA manifest, RAG, receipt, test-capture, or task identifiers.
- Android signature: verified with APK Signature Scheme v2 and v3; one RSA-2048 signer.
- Android package: `com.blackking4210.junglelaw`, version `1.0.0`, min SDK 24, target/compile SDK 35, `arm64-v8a` only.
- Android signing boundary: Godot internal/debug certificate, not production/store signing.
- Animal source/hash manifest: 40/40 current runtime PNG hashes pass after relocation to `output/qa/F-ZC-ANIMAL-ART-001/source_manifest.csv`.
- Stage-to-live artifact copy: 6/6 hashes match.

## Open findings

- `MINOR`: Android `aapt2 dump badging` reports a missing optional `themed_icon.xml` reference; the normal application icon is present. This does not block the internal APK but should be corrected before store release.
- `MATERIAL FOR RELEASE VISUAL APPROVAL`: the supplied `天鹅（章鱼）.png` and `鹤（鹅）.png` remain semantically mismatched with the existing card names.
- No Android device installation, packaged Web browser session, target-device performance run, or final exported-build visual parity capture was performed; those gates remain pending.

## Publication gate

Package evidence permits Git publication of the exact release source. Before each push, recheck the remote refs and require fast-forward ancestry. Do not commit the ignored binary packages to Git.
