# REQ-20260813-CROSS-PLATFORM-ACCOUNT-CREDENTIALS Read-only receipt

- Request: complete named account/password login for supported platforms and let a logged-in player view their credentials safely.
- Feature: `F-ZC-AUTH-001`
- Owner: `codex-primary`
- Started: `2026-08-13`
- RAG gate: `READY`, final index `ddd324ba092fd52e895643466355f0734d7248442bc6c4450bcebe7fc40e8966`
- Task context: `temp/rag/receipts/tasks/REQ-20260813-CROSS-PLATFORM-ACCOUNT-CREDENTIALS.json` with 10 cited chunks.
- Control-plane result: `READY`, L3, fingerprint `71338A9F9D143B6F83248A9999042C0EA1CCFDB3F184C416C6F2CE1AF8CB1CA9`, no duplicate task and no write conflict.

## Approved behavior

1. The same named account and password may bind multiple supported client installations to one server `UserID` and profile.
2. The account center shows the named account and `UserID` after login.
3. A password can be revealed only when it was typed during the current foreground process session. It is never fetched from the server or persisted by the client.
4. Focus loss, application pause, disconnect, account switch, or exit clears the in-memory password.
5. Automatic token login can show the account name but cannot reveal a historical password.

## Baseline hashes

- `docs/PLAYER_ACCOUNT_AND_SERVER_PROFILE_DESIGN.docx`: `285A9C9386DB0F108EB7B8A2B1519EB06896B8D65DA450A51A12C8F2875A4CB4`
- `tools/build_player_account_design_docx.py`: `290AEB2E867B4C56458EEE8699AF8C560D6CCFEE5B15FF94D84146FE27087C16`
- `scripts/server/player_account_store.gd`: `D46F4237297ED2B102A07DC707F7A947AAD6E812BC1BC578F9ECD72F2F102FD2`
- `scripts/network/online_room.gd`: `E49C9ECD6A8312ABAD116EDE9BBE6D8CE62AC1293E6CD5E9F7600C35F78C54BC`
- `scripts/app/main.gd`: `2E6E42CE53A0F72AC4B21643EFE1EF1CD4C6653B08F18215A7AE694AE79509FB`
- `tests/test_player_account_store.gd`: `5BDEB3C7C58EAAC94498917FC070CA0BCD7CDCB8A6CDF9BF7578400DA34AC7BC`
- `tests/test_account_password_login_loop.gd`: `414BA00B67E720B50536E21CCFA1CB6FF41702097137FAADF7B6BF39433ABF62`
- `tests/test_account_manual_login_entry.gd`: `311CC04DBB1CE9452305B2D6A62701936DAAE25B39DBB01538F6D5F31E4F3E86`

## Known release blockers

- The historical account design DOCX was preserved and v1.4 was generated as `docs/PLAYER_ACCOUNT_AND_SERVER_PROFILE_DESIGN_v1.4.docx`; the RAG manifest now routes account design authority to the versioned file.
- `production/deployment/aliyun-profile.yaml` is not populated and both remote-write switches are disabled. No remote deployment is authorized.
- The current account RPC transports account/password through ordinary ENet UDP without a configured encrypted authentication channel. Local behavior tests cannot close public-network security acceptance.
- Windows and Android share the Godot client path; real package-to-package, external-network validation remains pending. Web and iOS are not claimed as supported by this receipt.
- Existing whole-profile writes have no server-side revision conflict handling. Multi-installation identity is in scope here; production-grade concurrent profile merge and anti-cheat authority remain a separate P0 server task.

## Write ownership

The lock is held only for the files listed in `docs/active_scope.yaml`. Existing unrelated worktree changes, especially the group-buff changes in `scripts/app/main.gd`, are preserved and excluded from this task's commit.

Runtime screenshot capture is isolated in `tests/capture_account_credentials_ui.gd` and writes only to `temp/qa/F-ZC-AUTH-001/`.
