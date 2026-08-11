# F-ZC-MOBILE-VIEWPORT-002 Completion Receipt

## Result

- Status: `ACCEPTED_FOR_INTERNAL_ANDROID_TESTING`.
- Player-facing memory point: tall portrait phones extend the game's light-green sky and grass background to the physical top and bottom edges; no Godot gray clear area remains visible.
- Visual gate: `RUNTIME_SLICE_APPROVED` from target-resolution GPU captures. `RELEASE_VISUAL_APPROVED` remains pending a physical Android-device capture.
- Android remains fixed portrait. The new APK contains exactly one Godot activity orientation value, `android:screenOrientation=1`.

## Root cause and repair

- Root cause: `canvas_items + expand` exposes a taller logical viewport on long phones, while `scripts/app/main.gd` intentionally keeps the `720 x 1280` design canvas uniformly scaled and centered. The scene background previously painted only that design rectangle, so untouched top and bottom pixels fell through to Godot's default neutral gray clear color.
- Runtime repair: `_draw_full_bleed_background()` now paints the real viewport before the centered design transform. The top surplus continues `BACKGROUND_TOP_COLOR`; the bottom and side surplus continue `BACKGROUND_BASE_COLOR`.
- First-frame/resize fallback: `project.godot` declares `rendering/environment/defaults/default_clear_color` with the base scene color.
- Preserved behavior: design scale, canvas offset, input conversion, control positions, camera rules, stretch mode/aspect, and Android orientation are unchanged.

## Before and after evidence

- Baseline source: clean `HEAD` commit `ef2cd65e98d2e1ca9dba6df5d095ee6824637177` in an isolated project.
- Baseline `1080 x 2400`: deterministic negative test sampled both surplus areas as `(0.298, 0.298, 0.298, 1.0)` and failed three expected gray-background assertions.
- Baseline PNG: `output/qa/F-ZC-MOBILE-VIEWPORT-002/before_head_1080x2400.png`, SHA-256 `6965F59A1593E17D35CDE7669D5469880DDDADC44C001A616160E180E37A00E1`.
- Fixed target-resolution runs:

| Viewport | Canvas offset | Scale | Result | PNG SHA-256 |
| --- | --- | ---: | --- | --- |
| `1080 x 1920` | `(0, 0)` | `1.5` | `MOBILE_FULL_BLEED_PASS` | `C37D15BB19B60CAA9724A74083ED933D53E24B15B4FA4BF6D62DC8D52AEDB152` |
| `1080 x 2340` | `(0, 210)` | `1.5` | `MOBILE_FULL_BLEED_PASS` | `A19D77160562EC73729C78FF669B2C54BC3435BF54675D3FC8AFE2ECB0522FD3` |
| `1080 x 2400` | `(0, 240)` | `1.5` | `MOBILE_FULL_BLEED_PASS` | `4ED0EC78252A74FF49C8D39BD534F0EDCF569DFA06EA4479F7B9D3C38DF8DCFC` |
| `1440 x 3200` | `(0, 320)` | `2.0` | `MOBILE_FULL_BLEED_PASS` | `C7BC12D5F665D0DB1650754D558D32DA550CBB9DDF69A09B14DBC9E78ECC48F3` |

- The focused QA script asserts uniform design scaling, exact centering, expected top/bottom surplus colors, non-neutral top-edge color, exact render dimensions, and capture write success.

## Engineering verification

- Godot runtime and visual QA: `4.6.3.stable.official.7d41c59c4`, OpenGL Compatibility on NVIDIA RTX 4060 Laptop GPU.
- GDScript indentation: passed the project tab-indentation checker.
- Configuration validation: passed, 16 tables and 387 rows.
- Runtime configuration export: completed for all 17 JSON outputs; no tracked runtime configuration diff remained.
- Isolated import/parse: exit `0`.
- Classic battle regression: passed for five random-map variants.
- Lobby multiplayer entry regression: passed.
- Normal five-frame main-scene smoke: exit `0`; no script, parser, or failed-resource error.
- Existing test-harness shutdown warnings about retained ObjectDB/resources remain visible in several historical tests and the forced five-frame smoke; they are not parser failures and were not introduced by this change.
- `tests/test_multiplayer_camera.tscn` still fails its final post-drag building-click assertion. The identical assertion also fails in the clean `HEAD` baseline with no viewport repair, so it is recorded as a pre-existing unrelated regression rather than attributed to this change.

## Android package evidence

- Build engine/templates: Godot `4.6.2.stable.official.71f334935` with matching `4.6.2.stable` Android templates.
- Signing class: Godot internal debug signer; this is not a store-production package.
- Package: `com.blackking4210.junglelaw`, version `1.0.0`, compile/target SDK `35`, native ABI `arm64-v8a`.
- Manifest: `android:screenOrientation=1`.
- Signature: v2 and v3 verified; one RSA-2048 signer. v1, v3.1, and v4 are not used.
- Archive stream: all `432` entries read completely; `108,127,908` uncompressed bytes consumed.
- Known non-blocking template warning: an optional `themed_icon.xml` resource is absent, matching the previous accepted internal package condition.
- Published internal packages:

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `build/android/JungleLaw-android.apk` | 52,627,121 | `E108F650E469A0A07A7CF2105BBFFE96099417DD1BF223F6308F2F59F68E4F1B` |
| `build/android/JungleLaw-android-2026-08-11-full-bleed-r1.apk` | 52,627,121 | `E108F650E469A0A07A7CF2105BBFFE96099417DD1BF223F6308F2F59F68E4F1B` |

- The previous fixed-name APK remains recoverable from the unchanged `JungleLaw-android-2026-08-11-groundline-r2.apk` copy.

## Final tracked source hashes

| File | SHA-256 |
| --- | --- |
| `project.godot` | `5D3F4560BD63DA7404933283FF87C64D75B3CCEBCF3386D4ED1C788698A419F8` |
| `scripts/app/main.gd` | `24CCDB32AF44247408FF28C4AE6824CCE9A5F7216DC714C7CBBB57F67F492059` |
| `tests/test_mobile_full_bleed_background.gd` | `CCFECD3538FE712F29505684FDE7FECFA333B8E1B574A72AC526D931B8783D34` |
| `tests/test_mobile_full_bleed_background.tscn` | `9AA22B17E067CADD792E9C1A62E8671FD432963968790A607648F9CAE7256D3A` |
| `export_presets.cfg` | `EA73D33526A8E644488FBE21B2F1E5E06B13FE68EEDA074A5CCDA6D10CB3C07F` (unchanged) |

## Boundaries and cleanup

- No UI geometry, camera, touch target, gameplay, configuration table, server, asset, or Android orientation rule changed.
- No physical Android device was connected, so install/launch/rotation screenshots remain the final device-level evidence gap.
- Temporary isolated projects, import caches, logs, rejected export outputs, and their dedicated test user-data directories have been removed; they contained no player data and are not recoverable.
- Placeholder/candidate leakage: none.
- `reusable_method_candidate: none`.
