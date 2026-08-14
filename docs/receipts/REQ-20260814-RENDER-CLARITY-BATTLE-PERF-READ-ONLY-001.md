# REQ-20260814-RENDER-CLARITY-BATTLE-PERF read-only receipt

- Feature: `F-ZC-001`
- Date: `2026-08-14`
- Owner: `codex-primary` (existing engineering owner)
- Control status: `READY`, execution level `L3`, action `activate_role_owner`
- Task fingerprint: `A68B4CCE79B89A6B50DFF884C6960E4CC719FDCB0E8D83E2261921044AC80A53`
- RAG gate: `READY`, index `866f88985c9b0dc710aff04b718a6f096ba0e188185b691b957aa489450f493d`, 13/13 golden queries, mean recall `1.0`
- Task receipt: `temp/rag/receipts/tasks/REQ-20260814-RENDER-CLARITY-BATTLE-PERF.json`, 10 citations

## Objective and observable behavior

Improve portrait rendering clarity without changing page layout, control positions, click targets, state meanings, or battle camera composition. Text must be rasterized at the actual viewport pixel size instead of rasterizing at the 720 x 1280 design size and scaling the resulting glyphs. Thin UI geometry must align consistently to physical pixels. Battle simulation must avoid repeated full-unit scans for already locked targets and repeated building-index rebuilds inside the per-unit loop.

## Resolution decision

- The formal portrait target remains `1080 x 1920`; the current project already declares that viewport.
- The supplied runtime screenshot is `540 x 960` (SHA-256 `E55A66D589B329EBB09D66B9A3A0C0862F2159C12143D90FB09E9EFC1E81F0F4`). Raising a fixed off-screen render target above 1080 x 1920 would increase GPU cost and then downsample again on that screen, so it is explicitly rejected.
- The approved increase is in effective UI raster resolution: preserve the stable 720 x 1280 logical layout, but emit text at native viewport font sizes and use pixel-snapped 2D transforms/vertices. Validate both `540 x 960` fallback and `1080 x 1920` target captures.

## Performance contract

- Preserve battle rules, unit cap, targeting priority, movement, damage, and result behavior.
- Build one unit-ID-to-index cache per simulation update; validate every cached index and fall back safely if the array changed.
- Build combat-building keys once per update, not once again for every unit that needs a navigation target.
- Benchmark a deterministic 72-unit locked-target workload after warm-up, reporting median and p95 update time from the same Godot executable and test source before and after the change.
- The development-machine target is p95 simulation update below `4.0 ms` for the focused 72-unit benchmark. Exported Android device acceptance remains a separate target-device gate.

## Write scope

- `docs/RENDERING_CLARITY_AND_BATTLE_PERFORMANCE_DESIGN_v1.0.docx`
- `docs/active_scope.yaml`
- this receipt and the matching close receipt
- `knowledge/knowledge_manifest.csv`
- `project.godot`
- `scripts/app/main.gd`
- focused rendering, capture, and battle-performance tests under `tests/`
- `tools/build_rendering_performance_docx.py`

Temporary evidence is limited to `temp/qa/F-ZC-001/render-clarity-battle-perf/`.

## Baseline and conflict handling

- Branch/HEAD: `codex/animal-art-integration-20260811` / `4cb2867c111205f945263c79759ae679ca5b29d0`.
- `scripts/app/main.gd` worktree SHA-256: `8C798E60139687B5AFD185FFDBD65A622159E5A765B7AA50B91480C0CC9ECD67`; HEAD blob: `81a2bc47691afb5aa3123b68ffeb52eb10277213`.
- `project.godot` worktree SHA-256: `0989903F628863D30A61F449419A0646FB08B50F967BA068866959DC9EC46B92`; HEAD blob: `9603ee13188c243ff261aa5539f9d4362259b86e`.
- Existing uncommitted group-buff, configuration, document, import, and editor-normalization changes belong to other scopes. They must remain untouched and must not enter this task's commit.
- `scripts/app/main.gd`, `project.godot`, `docs/active_scope.yaml`, and `knowledge/knowledge_manifest.csv` are shared dirty files; any commit must use selective staging and must be verified from the exact staged tree.

## Acceptance evidence

1. Automated checks prove logical layout stays 720 x 1280 while native text raster sizes scale to each viewport and restore the active draw transform correctly.
2. Runtime captures at 540 x 960 and 1080 x 1920 show unchanged layout with clearer title, resource values, buttons, navigation labels, borders, and icons.
3. The deterministic 72-unit benchmark records baseline and optimized median/p95 values from the same Godot 4.6.3 executable.
4. Focused battle regressions, mobile full-bleed tests, GDScript indentation validation, and a Godot parse/run pass succeed from the exact staged source.
5. No Android no-stutter claim is made without an exported package running on a representative phone; local evidence may close implementation but not device release acceptance.

## Gate statement

`READY FOR FORMAL DOCUMENT WRITEBACK`. Updating the indexed design source or manifest makes the current RAG receipt stale; rebuild RAG before runtime code changes.
