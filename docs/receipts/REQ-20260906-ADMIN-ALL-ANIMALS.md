# REQ-20260906-ADMIN-ALL-ANIMALS engineering receipt

## Read-only intake 2026-09-06

- Owner: codex-primary; feature F-ZC-ADMIN-001; intent execution; route L1 scoped existing-command extension with reproducible regression.
- Producer request: update the deployed admin and add one-click all-animal grants to one chosen account for testing. Default each animal +1 copy, existing owned copies additive, levels/decks/currency unchanged. No real grant target was supplied; acceptance must not issue live player grants.
- Formal sources: existing ADMIN_ANALYTICS_DASHBOARD_DESIGN, producer request, production/deployment/aliyun-profile.yaml staging, RAG task pack temp/rag/context/REQ-20260906-ADMIN-ALL-ANIMALS.md (READY).
- Baseline: branch codex/animal-art-integration-20260811; HEAD 72f1c0f; admin 1.3.1; deployed game SHA256 5318144037f2f81a962c22510ab2764557eca289534bc043b023789495e376f1 verified by SSH. Existing UI exposes names/full IDs and a first-screen operation form.
- Findings: Node and executor grant vectors limited to 20; authoritative deployed animal catalog has 60 entries. TLS source lineage expires September 11 but deployed pair expired August 28; old-pair expiry validation blocks renewal deployment, and one-shot post-restart probe has a readiness race.
- Write set: tools/admin_dashboard/{public/app.js,lib/resource_grants.mjs,server.mjs,package.json,README.md,all_animals.test.mjs}; scripts/server/player_account_store.gd (grant bound only); deploy/linux/junglelaw-admin-dashboard-cert-renew; tools/admin_dashboard/qa/; docs/active_scope.yaml (own entry only); this receipt; production/deployment/aliyun-profile.yaml (new version evidence only); ignored task build/QA paths.
- Excluded: active dog_rewards_gacha lock including tests/, main.gd, animal rules and CSV/runtime tables; account migration, battle logic, lock-target UI; production; other hosted projects; credentials; real player grants.

## Implementation contract

1. Resource page keeps the existing player picker and adds a visible single-account-only button “一键发放全部动物（各1份）”. Zero/multiple selection disables it; clicking uses an automatic auditable test reason, no second confirmation.
2. API accepts `grant.type=all_animals, amount=1` only for `target.kind=user`. Resolve the full animal catalog on the server from the deployed authoritative dashboard projection, never trust a client-supplied catalog; fail closed if absent/invalid. Freeze expanded card-copy list in the existing session-bound signed preview, enqueue one command using existing Owner/CSRF/idempotency/audit boundaries.
3. Node/executor vector capacity becomes 256. Existing executor validates every card/target before atomic persistence. Receipt UI summarizes the whole vector, not its first entry. Repeated click while busy is blocked; failed network retry retains the same key.
4. Game artifact is built from the verified deployed v1.3.0 isolated source plus the grant-bound-only patch, not today's unrelated game worktree.
5. TLS renewal validates the new pair's freshness but allows an expired old pair to be replaced; reconcile renewed lineage each timer run, bounded retry of verified HTTPS after restart, rollback on failure. Never edit/reload nginx.

## Acceptance and cleanup

Node API/regression and browser fixture checks; isolated Godot atomic 60-animal grant/replay/persistence tests; versioned artifact hashes; staging preflight/backup/rollback and service fingerprints; trusted external HTTPS and protected routes; no live queue additions; retain player state and authentication; commit/push scoped changes; refresh RAG and release own lock. Production remains unapproved.

## Closure 2026-09-06

Status: COMPLETE / STAGING_PUBLIC_DEPLOYED v1.4.0-aliyun-staging-rc2. Remote writes were executed only after scoped tests and read-only preflight. No real player resources were issued.

- Public endpoint: https://106.15.61.103/ ; trusted external TLS root HTTP 200, health HTTP 200 / live=true; unauthenticated accounts HTTP 401. In-app browser created the correct titled tab; its AX inspection timed out, so no fresh live login was claimed. Administrator state SHA256 before/after `65a57fbdc386f5179b26f0afe21bb03514c4f4cf70cf12dada3212f5231da839`; password and permissions unchanged.
- Node 28/28 tests PASS, GDScript indentation PASS; isolated baseline Godot regression `ADMIN_BACKEND_FEATURES_TEST_PASS` (expected fault injection logs); dedicated 60-animal test `ALL_ANIMALS_EXECUTOR_TEST_PASS` locally and on Alibaba Linux. Coverage: one command, exact selected player, every species, no unselected award, restart replay, invalid last entry rejects atomically.
- Browser fixture PASS at 1440x900 and 390x844; both new shortcut and normal submit remain visible; 0/1/2 selection states; actual authenticated HTTP preview/submit creates a single 60-entry fixture command. Final visual receipt shows all 60 card types. Synthetic receipt rendering is separate from the real executor fixture. Evidence: `temp/qa/admin-all-animals-20260906/browser-run/{desktop,mobile,result}.png` and `tools/admin_dashboard/qa/browser.mjs`.
- Linux game candidate: verified deployed v1.3.0 source plus **only** grant limit 20 to 256 in player_account_store.gd. `git diff --no-index` proved no other runtime script changes. Full game binary SHA256 `69c33449882ac2409c444af4b9d1e19edfd8e491fa578f2de46a5766e47f7d58`. Current worktree account migration, combat and new animal table work were excluded.
- Admin ZIP SHA256 `f4f1c10af9fe54e73fbc3352cf69f68d694a4ea4dfd73c225bd29be320a1c2ba`; remote verified all 21 allowlisted files. Current release `/opt/junglelaw-admin/releases/JungleLaw-admin-dashboard-v1.4.0-aliyun-staging-rc2`.
- Root-only coherent backup `/var/backups/junglelaw-admin-dashboard/admin-all-animals-20260906`; tar checksum verified; old game ELF, previous admin release, certificate pair/helper and authoritative/admin state retained. On failure transaction restores code pointers without reverting player data. Rollback prepared, not executed. Reproduction transaction is retained under the root-only upload path `/root/junglelaw-admin-all-animals-20260906/deploy.sh` and local ignored release directory.
- Graceful game stop succeeded, only JungleLaw game/admin restarted. Both active, NRestarts 0, ExecMainStatus 0; Fisher and nginx PID/start/status fingerprints unchanged; error-priority service journal empty after activation.
- Authoritative player file SHA256 and both preexisting processed command receipts remained identical. Pending 0 / processed 2 / failed 0. Remote read-only projection check: 30 players, 60 animal rows, all-animal preset expands to 60 grants for one synthetic in-memory target, no queue write.
- TLS repaired by projecting the already-issued trusted certificate, expires `2026-09-11T15:18:24Z`. A manual run of the existing renewal service passed Result=success / ExecMainStatus=0; timer remains active. Root-only old pair remains in the deployment backup. No nginx change/reload.
- Temporary local synthetic data and listeners were closed/removed by the tests. Shared lock `admin_all_animals_20260906` RELEASED; no active batch task remains for this request. Other task changes/locks preserved. RAG refresh and task pack returned READY, golden query pass rate 1.0, with the new closure source ZC_ADMIN_V140_CLOSE retrieved. The scoped Git commit contains this receipt; its SHA is reported at delivery rather than self-embedded.

### Retained limits

Production is not authorized. No real-account grant was submitted; Linux atomic settlement is fixture-tested. The 30 legacy remote records still have no real username and show explicitly labeled stable temporary names. `/api/readiness` retains its preexisting executor-heartbeat-not-observed limitation (503) even though liveness, data, command storage and Owner state are ready. Formal historical v1.3.1 Word/UI-design artifacts were not reissued for this operational extension; this is an engineering receipt, not a claimed new design approval.
