# F-ZC-RELEASE-20260811 Producer Decision

- feature_id: `F-ZC-RELEASE-20260811`
- decision_state: `approved`
- approved_rule: build the current animal-art integration branch for Windows, Android, and Web; after package validation, publish the feature branch to the configured GitHub `origin`, fast-forward local `main` to the same verified commit, and publish `main`.
- superseded_rule: local-only feature branch; remote publication was previously withheld because explicit destination authorization was absent.
- formal_source_target: this receipt plus `docs/active_scope.yaml`.
- affected_domains: release engineering, QA, visual acceptance, source control.
- affected_files: release artifacts under `build/`, release receipts, the animal QA manifest location, local branch refs, and remote `origin` refs for `codex/animal-art-integration-20260811` and `main`.
- execution_readiness: authorization is explicit in the producer's 2026-08-11 instruction, subject to package, remote-divergence, and fast-forward gates.
- unresolved_producer_decisions: none for internal-test packaging and Git publication. Android remains internally/debug signed because no production signing identity is configured.
- reusable_method_candidate: none.
