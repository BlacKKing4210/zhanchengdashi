# F-ZC-BRANDING-001 Completion And Release Receipt

## Outcome

- Status: `COMPLETE` for creation, Godot integration, and three-platform repackaging.
- Branch: `codex/animal-art-integration-20260811`.
- Scope delivered: one original application icon, one original portrait loading/boot image, Godot boot configuration, target-size QA evidence, and refreshed Windows/Android/Web release packages.
- Gameplay, balance, page layout, controls, navigation, and server behavior were not changed.

## Grounding And Ownership

- Request: `REQ-20260811-BRANDING-LOADING-REPACKAGE`.
- Feature: `F-ZC-BRANDING-001`.
- RAG gate after task activation: `READY`, golden queries `8/8`, pass rate `1.0`, mean recall `1.0`, index signature `0e9ab1ca1b750f006f0bdea0488938ab295cc08c4d778c8a64f25496a7301a47`.
- Control-plane preflight: `READY`, execution level `L3`, no duplicate task and no conflicting lock; fingerprint `9D5A4855C7F6CF6A89712BEC58BCBC9209680A44FD1BB79B3929E18BDC096552`.
- Producer authority: direct user request on 2026-08-11.
- Accountable implementation owner: `codex_primary`; shared locks were limited to branding assets, `project.godot`, QA evidence, and package outputs.
- Final closure refresh: RAG `READY`, index signature `d76d1cd4b826660d3cbb684373fd903fc1ec9412352678053f037014cf885cce`; `active_modules` and `shared_locks` are empty.

## Final Assets

| Asset | Dimensions / mode | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| `assets/branding/app_icon_1024.png` | `1024 x 1024`, RGB, opaque PNG | 1,828,949 | `F86F48EBBCF3C4323F1700E6847595257AADE734C6F61EA4EFFB64BDF9FBF62D` |
| `assets/branding/loading_portrait_1080x1920.png` | `1080 x 1920`, RGB, opaque PNG | 3,231,744 | `132A547BC9AD9B2F34136409AFE7303D625B88873A67B87326D5979298A3E363` |

- Both source images were generated as original raster art, then only center-fit resized with Lanczos sampling to the contracted dimensions.
- The icon remains recognizable in the committed `48 x 48` QA sample.
- The loading art remains readable in the committed `360 x 640` portrait QA sample, with the lion, crown, flags, and central hex tile inside the safe region.
- No text, title, watermark, button, or copied commercial identity is baked into either image.

## Godot Integration

- `application/config/icon`: `res://assets/branding/app_icon_1024.png`.
- `application/boot_splash/image`: `res://assets/branding/loading_portrait_1080x1920.png`.
- Boot splash: shown, filtered, warm-paper background, `stretch_mode=1`, minimum display `1000 ms`.
- Mobile orientation remains fixed portrait: `display/window/handheld/orientation=1`.
- Godot 4.6.2 editor import completed for both textures without resource/import errors.
- In-engine resource/settings check: `BRANDING_RUNTIME_PASS: icon=1024x1024 splash=1080x1920 portrait=1 minimum_ms=1000`.
- Normal project headless startup completed with exit code `0`; the only shutdown note was the existing ObjectDB leak warning on forced short-frame exit.

## Package Validation

- Packaging ran in an isolated temporary project copy with Godot `4.6.2-stable`.
- Configuration gate passed: `16` tables, `387` rows; `17` staged runtime JSON files were byte-hash equivalent to the live project's runtime JSON.
- Every entry in the Windows ZIP, Android APK, and Web ZIP streamed successfully with no corrupt archive member.
- Export logs contain both branding resource paths for the packaged projects.
- Windows ZIP contains the expected `JungleLaw.exe`; exported-client smoke passed for `5` frames with exit code `0` against TEST-NET `192.0.2.1:9`.
- Web ZIP contains the required `.html`, `.js`, `.wasm`, and `.pck` files.
- Android APK contains `422` entries, only the `arm64-v8a` native ABI, and Manifest `screenOrientation=1`.
- Android launcher foreground extracted from the APK is `output/qa/F-ZC-BRANDING-001/android_launcher_icon.webp`, SHA-256 `F4EDE93D5D9094774E931A185424E045DD34D9CE7D8037E4D5E413A43C617D`; visual inspection confirms the new lion icon rather than the default Godot icon.
- APK signature verification: v2 `true`, v3 `true`, one internal-test signer; certificate SHA-256 `ba0ae26c9bfe6e0f28a2ecb9c1464f626f57023d39622051d229a0a7620e926c`.
- The Android export template reports a non-blocking missing optional `themed_icon.xml`; the application does not reference it, while the normal adaptive icon's foreground/background resources are present and verified. A monochrome Android themed icon remains outside this request.

## Release Artifacts

| Platform | Latest artifact | Bytes | SHA-256 |
| --- | --- | ---: | --- |
| Windows x64 | `build/windows/JungleLaw-windows-x64.zip` | 60,146,866 | `A0F67B8ED6285193D20AEF0A5D6D8984D400082356951CBEC142699DD66C65CA` |
| Android arm64 | `build/android/JungleLaw-android.apk` | 50,820,247 | `D9BB31BDC1F83F6A06FF4C36DDD7D9661279D6F1DDD0A4FC31EE6953CBCF0FB1` |
| Web | `build/web/JungleLaw-web.zip` | 38,609,864 | `636F8F93F9A5CC3A01A075684AD525AA717B3DA9070DEF14CDED9F7B43DCFBE8` |

- Same-hash dated copies were also refreshed with suffix `2026-08-11`.
- Package outputs remain ignored build artifacts and are not added to Git.
- Android is signed for internal testing, not store production. A producer-owned production keystore/AAB flow is still required for store release.
- The isolated temporary build directory and stale pre-existing APK `.idsig` sidecar were removed after verified copies were present in the project build directories.

## Visual Gate And Remaining Boundary

- Current gate: `RUNTIME_SLICE_APPROVED WITH CONCERNS`.
- Package-level icon evidence, engine resource checks, target-size QA, and exported resource logs are complete.
- `RELEASE_VISUAL_APPROVED` remains pending producer review of the boot splash on physical Android hardware and any platform-specific crop/theme behavior.
- Reusable method candidate: `none`; the existing image-generation, visual-quality, Godot integration, and packaging workflows covered the task.
