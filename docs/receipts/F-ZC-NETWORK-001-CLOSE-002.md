# F-ZC-NETWORK-001 Android Cloud Connection Completion Receipt

- Request: `REQ-20260811-MOBILE-CLOUD-CONNECTION-FIX`.
- Result: `COMPLETE` for the package-level repair and public-server connection path.
- Root cause: the previous Android export contained no `android.permission.INTERNET`, so Android blocked the client from opening Internet sockets even though the configured cloud endpoint was reachable.
- Fix: added `permissions/internet=true` to the Android export preset in `export_presets.cfg` and rebuilt the Android package.
- Server endpoint: `106.15.61.103:24567/UDP`; unchanged from the approved project configuration.
- Cloud baseline: a public Godot ENet client probe connected successfully to the endpoint. No server restart, firewall/security-group edit, deployment, migration, or remote data change was needed.
- Rebuilt package: `build/android/JungleLaw-android.apk`, 50,820,247 bytes, SHA-256 `81C71EE631A1A4A40D6F6D10D21C4C20096133A5268E501DA95B97F5A68D719F`.
- Manifest evidence: package `com.blackking4210.junglelaw`; `android.permission.INTERNET` present; portrait orientation (`screenOrientation=1`); arm64-v8a runtime.
- Signing evidence: APK Signature Scheme v2 and v3 both verify; certificate SHA-256 `ba0ae26c9bfe6e0f28a2ecb9c1464f626f57023d39622051d229a0a7620e926c`.
- Packaged-runtime evidence: the rebuilt APK's extracted Godot project reported `APK_PROJECT_ENDPOINT host=106.15.61.103 port=24567` and `APK_PROJECT_ENET_CONNECTED host=106.15.61.103 port=24567`.
- Integrity evidence: APK ZIP validation passed for 422 entries; 17 runtime JSON configuration files matched the isolated build stage; the Android export log contained no blocking error marker.
- Aliyun boundary: `production/deployment/aliyun-profile.yaml` remains an unpopulated template with remote writes disabled. This did not block the local package repair because the existing public service was proven reachable and no remote mutation was required.
- Remaining target-device gate: no Android device was attached through ADB, so physical-device installation and carrier/Wi-Fi smoke testing were not performed in this task. The package and external connection path are verified; final device acceptance remains producer-device evidence.
- Cleanup: temporary probe/build-stage files removed; the shared `android_export_preset` write lock returned.
