# REQ-20260813-ACCOUNT-CREDENTIAL-COPY-APK close receipt

- Feature: `F-ZC-AUTH-001`
- Date: `2026-08-13`
- Owner: `codex-primary`
- Local implementation: `COMPLETE`
- Android package: `INTERNAL TEST COMPLETE`
- Public account-system release: `NOT READY`
- Visual gate: `PROTOTYPE_READABLE`

## Delivered behavior

1. The signed-in account panel now has a `复制账号密码` action with a 204 x 48 mobile touch target that does not overlap the password reveal control.
2. Copying writes one labelled payload containing the canonical account name and only the password retained from the current foreground manual-login session.
3. Automatic token login, guest state and sessions without the current manual password open re-verification and write no clipboard payload.
4. The application tracks the copied payload only in volatile memory. After 60 seconds it clears the operating-system clipboard only when the clipboard still matches that payload, preserving anything the player copied later.
5. Password material is not added to server responses, device credential JSON, project files, logs or receipts.

## Exact package source

- Branch: `codex/animal-art-integration-20260811`
- Source commit: `5d6348cef9fe941db8c4ea3bc6dfa4b98dbd2a3a`
- Isolated source: `temp/release/REQ-20260813-ACCOUNT-CREDENTIAL-COPY-APK-5d6348c/`
- Unrelated group-buff, configuration, room-input and editor-normalization worktree changes were excluded from the source snapshot and package.
- Exact-snapshot RAG: `READY`, index signature `e9f690917103fd5ff28a2442ff4e88c818c66f52137dbce9aae149f621a5dc26`, 8/8 golden queries, mean recall `1.0`, task context 8 citations.

## Automated and runtime evidence

- Godot 4.6.2 clean editor import/parse completed with no script parse error.
- `tools/check_gd_indentation.py`: `GDScript indentation check passed: tab 2.`
- Config validation/export: 16 tables, 387 rows, runtime export complete.
- `tests/test_player_account_store.tscn`: `PLAYER_ACCOUNT_STORE_TEST_PASS`.
- `tests/test_account_password_login_loop.tscn`: `ACCOUNT_PASSWORD_LOGIN_LOOP_TEST_PASS`.
- `tests/test_account_manual_login_entry.tscn`: passed.
- `tests/test_device_account_credentials.tscn`: passed.
- `tests/test_saved_account_auto_login.tscn`: passed.
- `tests/test_online_main_adapter.tscn`: passed.
- `tests/test_remote_account_auth_failure_delivery.tscn`: passed.
- Windows graphical Godot clipboard test: exit `0`; real clipboard write/read, unchanged-payload clear, and newer-player-content preservation passed.
- Godot sandbox root-certificate-store and exit-time resource warnings were recorded separately and were not treated as authentication or clipboard success evidence.

## Player-visible evidence

- Target capture: Windows Godot runtime, Vulkan renderer, 720 x 1280 portrait.
- Masked: `temp/qa/F-ZC-AUTH-001/account_credentials_masked-5d6348c.png`, SHA-256 `910906CF800E682B63277D1127EF6678200106DBE3EC5DBF24CFB416B4E6C61D`.
- Revealed: `temp/qa/F-ZC-AUTH-001/account_credentials_revealed-5d6348c.png`, SHA-256 `6595D28706B53880ED0F81B8D7086821691929A56D5A53CAAAF578D0566C4E04`.
- Copy feedback: `temp/qa/F-ZC-AUTH-001/account_credentials_copy-5d6348c.png`, SHA-256 `BBD734F5786A693E6E40BAEC0C5D9DC3F50BBF4C9263DB2FACEA646110169422`.
- Review: account, UserID, password, reveal action, copy action, safety note and success toast are readable and do not overlap.
- No approved editable Penpot account screen or Android target-device screenshot exists, so the visual gate remains `PROTOTYPE_READABLE`.

## Formal source evidence

- Account design: `docs/PLAYER_ACCOUNT_AND_SERVER_PROFILE_DESIGN_v1.5.docx`.
- DOCX SHA-256: `72CD03701F5CFEC86857F3D2FDD6DB567309C8B205EA617D7EC0DAE723CB92C7`.
- Structural validation: valid OpenXML, 52 non-empty paragraphs, 8 headings, one section, and required copy/60-second/Windows/Android text present.
- Page rendering remains `Pending`: the packaged document renderer could not find LibreOffice. No PDF was produced or delivered.

## Android package evidence

- Artifact: `build/android/JungleLaw-android-2026-08-13-account-credential-copy-r1.apk`.
- Bytes: `50,828,632`.
- Build time UTC: `2026-08-13T13:30:14.9073751Z`.
- SHA-256: `EB354ADE654B2DC351015ABCBAE62160CB3D8BCDB0356FC7CCA9DB4BD921322E`.
- ZIP integrity: `PASS`, 424 entries.
- Package: `com.blackking4210.junglelaw`; label `丛林法则`; version code `1`; version name `1.0.0`; min SDK `24`; target SDK `35`; ABI `arm64-v8a`.
- Manifest: `android.permission.INTERNET` present; `screenOrientation=1` (fixed portrait, no landscape conversion).
- APK signature: verified with v2 and v3, one RSA-2048 Godot internal-test signer; certificate SHA-256 `BA0AE26C9BFE6E0F28A2ECB9C1464F626F57023D39622051D229A0A7620E926C`.
- Source configuration retains app icon, portrait loading image and remote endpoint `106.15.61.103:24567`.
- `adb devices -l` returned no connected device. Installation, Android touch/clipboard, external cloud login and target-device screenshot acceptance remain open.

## Production blockers

1. `NOT READY: Aliyun deployment profile`: no authorized Alibaba Cloud target, domain/TLS, health, backup, rollback, monitoring or remote-write authorization is recorded.
2. Public account/password authentication still uses ordinary ENet RPC rather than certificate-validated encrypted authentication.
3. The password verifier remains a custom 12,000-round SHA-256 construction without production KDF migration, login rate limiting or a complete token-revocation lifecycle.
4. Simultaneous profile writes have no revision/field-level authority protection.
5. This debug-signed ARM64 package is for internal testing only and has not passed physical Android installation or Alibaba Cloud cross-platform acceptance.

## Closure

The scoped local write lock is released. The requested copy action and new Android internal-test APK are complete; production account-system and target-device release gates remain explicitly open.
