# REQ-20260813-ACCOUNT-CREDENTIAL-COPY-APK read-only receipt

- Feature: `F-ZC-AUTH-001`
- Date: `2026-08-13`
- Owner: `codex-primary` (existing engineering owner)
- Control status: `READY`, execution level `L3`, action `activate_role_owner`
- Task fingerprint: `AD9459F22887A736BA574E6B3EC21C7B2F4D3487AA569F6A9B9F7A46C77658D9`
- RAG gate: `READY`, index `ddd324ba092fd52e895643466355f0734d7248442bc6c4450bcebe7fc40e8966`, 13/13 golden queries, mean recall `1.0`
- Task receipt: `temp/rag/receipts/tasks/REQ-20260813-ACCOUNT-CREDENTIAL-COPY-APK.json`, 8 citations

## Objective and observable behavior

Add one `复制账号密码` action to the signed-in account panel and produce a new portrait Android internal-test APK. The action copies the canonical account name and the password still held from the current foreground manual-login session as one labelled text payload. It never retrieves an old password from the server, refresh token, local credential file or password hash.

## Safety and non-goals

- Automatic login, guest profiles and sessions without the current manually entered password must require re-verification before copying.
- Plaintext account/password must not be written to project files, `user://`, logs, receipts, crash output or server responses.
- The clipboard payload is tracked only in volatile memory. While the application remains runnable it is cleared after 60 seconds only when the clipboard is still unchanged, so newer user clipboard content is never erased.
- This task does not implement TLS/DTLS authentication, production password KDF, rate limiting, profile revisions, password reset, Alibaba Cloud deployment or production signing.
- The APK is an internal-test artifact, not production account-system release acceptance.

## Write scope

- `build/android/JungleLaw-android-2026-08-13-account-credential-copy-r1.apk`
- `docs/PLAYER_ACCOUNT_AND_SERVER_PROFILE_DESIGN_v1.5.docx`
- `docs/active_scope.yaml`
- this receipt and the matching close receipt
- `knowledge/knowledge_manifest.csv`
- `scripts/app/main.gd`
- `tests/capture_account_credentials_ui.gd`
- `tests/test_account_manual_login_entry.gd`
- `tools/build_player_account_design_docx.py`

Temporary QA output is limited to `temp/qa/F-ZC-AUTH-001/` and isolated build/test roots under `temp/`.

## Baseline and conflict handling

- Branch/HEAD: `codex/animal-art-integration-20260811` / `5293aec307e28d7dd04af91270bcd7355c01aee0`.
- `scripts/app/main.gd` worktree SHA-256: `8FC4692B78C96621891C063D435597E71766790894D5D6DE2A3CAC46C94ED89B`; HEAD blob: `bff22025c8e9f17e15e9614d49d288270116dc99`.
- `tests/test_account_manual_login_entry.gd` SHA-256: `13DB16D80E925D0D07BD240AEC49B39EEE2A5D6921CDC0FF84315717DDAEB3A7`; HEAD blob: `faf78aa933532bbbe389f748bf2288b2942c8692`.
- `tests/capture_account_credentials_ui.gd` SHA-256: `AACA046A8D92EE4AB1AF883575F5EAE63F5B6596C4097BD551EC2D7A5336747D`; HEAD blob: `dbb32963a8c715f63fba1113b475bd378de0b94a`.
- Existing uncommitted group-buff, configuration, document and editor-normalization changes belong to other completed/user scopes. They must remain untouched and must not enter the credential-copy commit or isolated APK snapshot.

## Acceptance evidence

1. Native mouse/touch hit path invokes the copy action; account, UserID, password-view and copy controls do not overlap at `720 x 1280`.
2. Session-available copy writes exactly the current account and password; unavailable copy opens re-verification and writes no payload.
3. Clipboard expiry clears only the task-owned unchanged payload and never logs or persists it.
4. Account tests, adjacent online/account regressions, indentation check and Godot editor parse pass from the exact isolated package source.
5. Runtime capture shows the button and successful-copy feedback at portrait target size.
6. The APK is freshly exported from the committed isolated snapshot, passes ZIP/package/signature inspection, preserves portrait orientation, app icon/loading assets and configured remote server address, and has recorded size/time/SHA-256.

## Gate statement

`READY FOR DOCUMENT WRITEBACK`. Updating the indexed account design and manifest will make the current RAG receipt stale; RAG must be rebuilt before runtime code changes.
