# F-ZC-NETWORK-001 Android Cloud Connection Read-Only Receipt

- Request: `REQ-20260811-MOBILE-CLOUD-CONNECTION-FIX`.
- Producer request: fix the Android package that cannot connect to the producer-owned cloud server.
- RAG gate: `READY`, golden queries `8/8`, pass rate `1.0`, mean recall `1.0`, index signature `d76d1cd4b826660d3cbb684373fd903fc1ec9412352678053f037014cf885cce`.
- Current branch baseline: `codex/animal-art-integration-20260811` at `60957430b070e588d6e816b6b9dd21c51868a5b1`.
- Current APK: `build/android/JungleLaw-android.apk`, SHA-256 `D9BB31BDC1F83F6A06FF4C36DDD7D9661279D6F1DDD0A4FC31EE6953CBCF0FB1`.
- Client source endpoint: `106.15.61.103:24567/UDP` from `project.godot`; the APK's `assets/project.binary` contains the same public IP.
- Public server baseline: Godot ENet handshake returned `REMOTE_ENET_CONNECTED host=106.15.61.103 port=24567`, proving the configured public server and UDP listener are reachable from an external client path at the time of diagnosis.
- Root cause: `aapt2 dump permissions` reports no Android `uses-permission`; `export_presets.cfg` has no `permissions/internet=true`. The APK therefore cannot open Internet sockets on Android even though the endpoint and server are valid.
- Aliyun boundary: `production/deployment/aliyun-profile.yaml` is still an unpopulated template with remote writes disabled. No remote write, restart, firewall change, upload, migration, or server-data mutation is authorized or required for this repair.
- Authorized local write scope: `export_presets.cfg`, Android build outputs, task QA evidence, and completion receipt only.
- Non-goals: no server restart/deployment, no endpoint change, no gameplay/account protocol change, no Windows/Web rebuild, and no modification of unrelated untracked files.
- Acceptance: Android export preset explicitly enables Internet permission; rebuilt APK Manifest contains `android.permission.INTERNET`; APK still targets `106.15.61.103:24567`, remains portrait-only and arm64; v2/v3 signing passes; the rebuilt packaged client has a successful ENet handshake to the public endpoint through a package-derived project runtime; config/package integrity checks pass.
