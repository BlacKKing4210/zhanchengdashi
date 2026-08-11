# F-ZC-RELEASE-20260811 Animal Groundline Repackage Closure

## Scope

- Request: `REQ-20260811-ANIMAL-GROUNDLINE-REPACKAGE-PUBLISH`.
- Delivery: rebuild the groundline-calibrated animal release for Windows x64, Android arm64, and Web; then publish the exact source to `main` and `codex/animal-art-integration-20260811` by fast-forward only.
- Accountable producer: `producer_user`.
- Execution owner during the write window: `codex_primary`.

## Completion evidence

- Final RAG gate: `READY`, 8/8 golden queries passed, mean recall `1.0`, index signature `f735768a0f311ba2dbee01d9edc50fe56895e8131e5fe4c263d1a17ad7c779c2`.
- Read-only receipt: `docs/receipts/F-ZC-RELEASE-20260811-REPACKAGE-READ-ONLY-005.md`.
- Package acceptance: `docs/receipts/F-ZC-RELEASE-20260811-REPACKAGE-006.md`.
- Release-hygiene source commit: `499b3314cf234ae5c25665907786a1e5c12f0a6d`.
- Accepted artifacts: three fixed packages and three `2026-08-11-groundline-r2` archives under ignored `build/` paths, with recorded SHA-256 and `6/6` stage-copy parity.
- The Git closure commit containing this receipt is the final publication source. Immediately before push, both remote destinations must be refreshed and independently proven to be ancestors of the closure commit; force push is prohibited.
- After push, `origin/main` and `origin/codex/animal-art-integration-20260811` must resolve to the identical closure commit.

## Gate result

- Package gate: `ACCEPTED_FOR_INTERNAL_DISTRIBUTION`.
- Git publication gate: eligible for non-force fast-forward publication after the final remote-ref recheck.
- Android store gate: pending production signing, optional themed-icon completion, and target-device acceptance.
- Live cloud gate: pending an actual Android device and an authorized, available Alibaba Cloud environment; no server deployment was performed.
- Release visual gate: not promoted beyond the accepted groundline runtime slice because no Android-device capture was available.

## Ownership and cleanup

- Release artifact and Git publication write sets are complete; the project active scope and shared locks are returned.
- The rejected and accepted isolated build directories are temporary and may be removed after final Git remote verification; release packages remain available under the project `build/` tree.
- No unrelated `.import`, translation, PDF, or temporary-crop file is part of the release commits.
