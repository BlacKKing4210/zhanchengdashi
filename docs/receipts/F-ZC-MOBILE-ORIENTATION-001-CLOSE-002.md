# F-ZC-MOBILE-ORIENTATION-001 Completion Receipt

## Result

- Status: `ACCEPTED_FOR_INTERNAL_ANDROID_TESTING`.
- Player-visible rule: the Android phone package launches in portrait and is locked to portrait; rotating the phone must not switch the activity to landscape.
- Runtime source: `project.godot` now declares `window/handheld/orientation=1` under `[display]`.
- Superseded package evidence: the prior APK declared `android:screenOrientation=0` (landscape).
- Current package evidence: the newly exported APK declares exactly one `android:screenOrientation=1` value for the Godot activity.
- No sensor, user-controlled, reverse-portrait, unspecified, or landscape orientation override is present in `project.godot` or `export_presets.cfg`.

## Android artifacts

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `build/android/JungleLaw-android.apk` | 40,940,111 | `00A853EBBA86CEC758084423D34AB17ED44EF2239050787B5EBDCB9332BA094C` |
| `build/android/JungleLaw-android-2026-08-11.apk` | 40,940,111 | `00A853EBBA86CEC758084423D34AB17ED44EF2239050787B5EBDCB9332BA094C` |

## Verification

- Engine/export templates: Godot `4.6.2.stable.official.71f334935` with matching Android templates, run in an isolated temporary project copy so the user's live Godot 4.6.3 editor was not stopped or used as the build workspace.
- Configuration validation/export: passed, 16 tables and 387 rows.
- Stage/live runtime configuration: 17 JSON files compared; zero missing or hash-mismatched files.
- Godot import/parse preflight: exit `0`.
- Android export: exit `0`; zero script, parse, failed-resource, or generic error matches.
- APK manifest: `android:screenOrientation=1`.
- APK archive stream: 417 entries opened and read completely; 91,482,622 uncompressed bytes consumed.
- Normal project smoke: five headless frames with an isolated user-data directory and reserved TEST-NET server override; exit `0`, zero script/parse/resource error matches.
- APK signature: v2 and v3 verified; one RSA-2048 Godot internal-test signer. v1, v3.1, and v4 are not used.
- Android package: `com.blackking4210.junglelaw`, version `1.0.0`, target/compile SDK 35.
- Stage-to-live copy: fixed-name and dated APK hashes both match the verified stage APK.

## Boundaries and remaining evidence

- The APK remains internally signed and is not a store-production artifact.
- No physical Android phone was connected for install-and-rotate observation. The project setting and packaged AndroidManifest deterministically prove the requested phone orientation lock; a device capture remains optional target-device evidence.
- No mobile UI layout, gameplay, camera, art, Windows, Web, dedicated-server, or iOS behavior was changed.
- `reusable_method_candidate: none`.
