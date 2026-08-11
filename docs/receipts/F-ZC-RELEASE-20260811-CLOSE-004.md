# F-ZC-RELEASE-20260811 Closure Receipt

## Scope

- Request: `REQ-20260811-RELEASE-AND-PUSH`.
- Feature: `F-ZC-RELEASE-20260811`.
- Delivery: package the animal-art integration for Windows x64, Android arm64, and Web, then publish the exact source to `main` and `codex/animal-art-integration-20260811`.
- Accountable producer for the authorized action: `producer_user`.
- Execution owner during the write window: `codex_primary`.

## Completed evidence

- Package acceptance: `docs/receipts/F-ZC-RELEASE-20260811-PACKAGE-003.md` records `ACCEPTED_FOR_INTERNAL_DISTRIBUTION`, artifact sizes and SHA-256 hashes, package inspection, Windows packaged-runtime smoke, Android signature inspection, configuration validation, and release limitations.
- Release metadata/hygiene commit: `60314ebf02061ea0fb4158efbeba981632ca7f85`.
- First publication verification: both `origin/main` and `origin/codex/animal-art-integration-20260811` resolved to `60314ebf02061ea0fb4158efbeba981632ca7f85` before this closure update.
- Final publication rule: the Git commit containing this closure receipt and the closed `docs/active_scope.yaml` must be pushed by fast-forward to both named remote branches, then both remote refs must resolve to that identical final commit.
- Release packages remain ignored binary deliverables under `build/`; no package binary is part of either Git branch.

## Gate result

- Package gate: `ACCEPTED_FOR_INTERNAL_DISTRIBUTION`.
- Git publication gate: eligible for final fast-forward publication after the closure commit.
- Visual gate: `SCALE_OUT_APPROVED WITH CONCERNS`; explicitly not `RELEASE_VISUAL_APPROVED` because Android target-device install/capture and exported-build visual parity evidence are absent, and two supplied animal files retain semantic naming mismatches.
- Store-release gate: pending production/store Android signing and the remaining target-device, icon, and visual checks.

## Ownership and cleanup

- The release-artifact and Git-publication write sets are complete; `active_modules` and `shared_locks` are returned to the project.
- No reusable-method candidate was identified beyond the existing release tooling and receipts.
- The isolated temporary package workspace may be deleted after final remote-ref verification because all accepted artifacts and formal evidence have already been copied into the project workspace.
