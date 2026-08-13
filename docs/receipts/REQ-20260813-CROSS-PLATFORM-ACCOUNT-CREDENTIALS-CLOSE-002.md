# REQ-20260813-CROSS-PLATFORM-ACCOUNT-CREDENTIALS close receipt

- Feature: `F-ZC-AUTH-001`
- Date: `2026-08-13`
- Owner: `codex-primary`
- Local implementation: `COMPLETE`
- Public cross-platform release: `NOT READY`
- Visual gate: `PROTOTYPE_READABLE`

## Delivered behavior

1. Successful named-account login responses now include canonical account name and `has_password`, while excluding password, salt and password hash.
2. Separate installation credentials can bind to the same named account and restore the same server `UserID` and profile. Each installation receives an independent refresh token that cannot be reused by another installation.
3. The account center shows account name, `UserID`, sync state and password state. A password is masked by default and can only reveal the value typed during the current foreground manual-login session.
4. Focus loss, application pause, disconnect, account switch and process exit clear current-session password memory. Automatic token login never provides or reveals an old password.
5. Account/password controls are native Godot `LineEdit` controls with pointer capture, explicit mobile virtual-keyboard behavior, password keyboard type, touch focus and submit-key focus progression.
6. Account switch rows show the named account when one exists and fall back to `UserID` for guest profiles.

## Automated evidence

- Final RAG gate: `READY`, index `ddd324ba092fd52e895643466355f0734d7248442bc6c4450bcebe7fc40e8966`, 13/13 golden queries, mean recall `1.0`, task context 10 citations.
- Godot 4.6.2 project editor parse: exit `0`.
- `tools/check_gd_indentation.py`: `GDScript indentation check passed: tab 2.`
- `tests/test_player_account_store.tscn`: `PLAYER_ACCOUNT_STORE_TEST_PASS`.
- `tests/test_account_password_login_loop.tscn`: `ACCOUNT_PASSWORD_LOGIN_LOOP_TEST_PASS`.
- `tests/test_account_manual_login_entry.tscn`: `Account manual login entry tests passed.`
- `tests/test_device_account_credentials.tscn`: passed.
- `tests/test_saved_account_auto_login.tscn`: passed.
- `tests/test_online_main_adapter.tscn`: passed.
- `tests/test_remote_account_auth_failure_delivery.tscn`: passed.
- Godot test user directories were redirected into `temp/godot-test-users/`; root-certificate-store warnings are a sandbox environment limitation and were not treated as authentication success evidence.

## Player-visible evidence

- Final runtime capture scene: `tests/capture_account_credentials_ui.tscn`.
- Target capture: Windows Godot runtime, OpenGL compatibility renderer, `720 x 1280` portrait.
- Masked state: `temp/qa/F-ZC-AUTH-001/account_credentials_masked.png`, SHA-256 `AF4FDC1949ABDF9433E3574F5C4A404321D4DF5265AB0F3A7239B2BED7EC60F1`.
- Revealed state: `temp/qa/F-ZC-AUTH-001/account_credentials_revealed.png`, SHA-256 `2B532A176FEB973CFD852C73C5971460D6D5A4AF04619EB15F99CB641E2E40B3`.
- Review: account name, `UserID`, masked password, reveal/hide action, session-only warning and bottom actions are readable and do not overlap. The reveal feedback toast remains inside the safe content region.
- The project has no approved editable Penpot account-screen source or visual-quality contract for this revision, so the visual gate cannot advance beyond `PROTOTYPE_READABLE`. Android exported-build visual and touch evidence is still required for release.

## Formal source evidence

- Authoritative account design: `docs/PLAYER_ACCOUNT_AND_SERVER_PROFILE_DESIGN_v1.4.docx`.
- DOCX SHA-256: `7E096CD8EBC82DDED5500B658E0722B4AE3F87005E72253A78F426DFC008B93A`.
- Structural validation: valid ZIP/OpenXML package, 48 non-empty paragraphs, 8 headings, one section, expected title/subject/footer, and required Windows/Android, ENet UDP and Alibaba Cloud gate text present.
- Page PNG rendering is `Pending`: LibreOffice is not installed; background Word rendering timed out. No Word process was force-terminated and no PDF was delivered.

## Release blockers

1. `NOT READY: Aliyun deployment profile`: `production/deployment/aliyun-profile.yaml` has no authorized target, domain, TLS, health check, backup, rollback, monitoring or remote-write authorization.
2. Account and password currently travel as ordinary ENet RPC parameters. Public-network release requires certificate-validated encrypted authentication. Godot documents ENet DTLS setup, but this project has no configured certificate/domain path yet.
3. The current password verifier is a custom 12,000-round SHA-256 loop rather than a versioned production password KDF such as Argon2id or PBKDF2, and there is no login rate limit or full token-revocation lifecycle.
4. Whole-profile client snapshots have no server revision or field-level authority, so simultaneous devices can overwrite one another and a modified client can forge profile values.
5. Logical cross-installation behavior is tested locally, but Windows and Android exported packages have not completed external Alibaba Cloud login, persistence/restart, packet-capture and bidirectional profile-restore acceptance. Web and iOS are not claimed as supported.

## Research and source status

- AnySearch: `DEGRADED`, quota unavailable; no generated credentials were saved.
- Official Godot documentation confirms `ENetConnection.dtls_client_setup()` must be called before connecting and `dtls_server_setup()` after creating the bound host, using `TLSOptions` with certificate validation. This is the approved direction, not evidence that the current transport is encrypted.

## Closure

The scoped local write lock is released. The work may resume under the same feature when the producer supplies a populated Alibaba Cloud profile and explicit staging write authorization; live deployment and target-package acceptance remain open.
