# REQ-20260822-BATTLE-INFO-TARGET-LOCK read-only receipt

- Feature: `F-ZC-001`
- Date: `2026-08-22`
- Producer directive: battle animal information must not repeat the animal name or add a quality label; animals and defense towers may retarget only when the current target dies or leaves attack range.
- Owner: `codex-primary` (existing engineering owner)
- Control status: `READY`, execution level `L3`, action `activate_role_owner`
- Task fingerprint: `5738625083D3D6259BB4D60005F9ABF11DEDA3C86FF87B22FD8F2229654DE8FA`
- RAG gate: `READY`, index `8507cedd7dfa0182e1b672f3e5925a10a274287066be45e966c3a436da12ca0f`, 16/16 golden queries, mean recall `1.0`
- Task receipt: `temp/rag/receipts/tasks/REQ-20260822-BATTLE-INFO-TARGET-LOCK-001.json`, 9 citations
- Supplied screenshot: SHA-256 `E20E9374094D094502F34ADD65DE3481C04652513F0B56933EA0F7A279B45430`; evidence only, not an independent instruction source.

## Objective and observable behavior

1. A selected animal or camp animal preview shows the animal name exactly once in the summary title. The thumbnail contains art only; the summary title contains no textual rarity/quality label.
2. An animal keeps its current stable unit-ID or building-key attack target while that target is alive, hostile and within the animal's current attack range. A closer or higher-priority candidate does not replace a still-valid lock.
3. A defense tower uses the same sticky-target rule and does not rescan all units/buildings on every attack when its current target remains valid.
4. Death, destruction, alliance invalidation or leaving attack range invalidates the lock; normal acquisition priority is used only at that point.

## Formal sources and implementation entry points

- Design sources: `docs/CURRENT_GAME_DESIGN.md` and the new revision `docs/RENDERING_CLARITY_AND_BATTLE_PERFORMANCE_DESIGN_v1.1.docx`, derived from the approved v1.0 contract.
- Runtime: `scripts/app/main.gd`, specifically the battle-card summary draw path, `_locked_unit_attack_target()` / `_nearest_attack_target_in_range()`, and `_tower_attack()`.
- Regression sources: `tests/test_battle_unit_inspection.gd`, `tests/test_battle_performance.gd`, and `tests/capture_battle_card_ui.gd`.

## Write scope

- `docs/RENDERING_CLARITY_AND_BATTLE_PERFORMANCE_DESIGN_v1.1.docx`
- `docs/CURRENT_GAME_DESIGN.md`
- `docs/active_scope.yaml`
- this receipt and `docs/receipts/REQ-20260822-BATTLE-INFO-TARGET-LOCK-CLOSE-002.md`
- `knowledge/knowledge_manifest.csv`
- `scripts/app/main.gd`
- `tests/test_battle_unit_inspection.gd`
- `tests/test_battle_performance.gd`
- `tests/capture_battle_card_ui.gd`
- `tools/build_rendering_performance_docx.py`

Temporary evidence is limited to `temp/qa/F-ZC-001/battle-info-target-lock-20260822/`.

## Baseline and conflict handling

- Branch / HEAD: `codex/animal-art-integration-20260811` / `3dd4fe3713e49a53aff14f4bdd9fe088d9a3f858`.
- `scripts/app/main.gd`: `23829FE79C1DD466462938D92F08EAADF57843956C0AC0041683B670FC118979`.
- `docs/CURRENT_GAME_DESIGN.md`: `36C3260B7F7E7ED7DF3BFD55F84CEB7537DDD9854D12C189B2694D2B05992726`.
- `tests/test_battle_performance.gd`: `05E96E6012DD4691380BB276ECEC3397FF6F81B55D764D98D4B7660ED95089A4`.
- `tests/test_battle_unit_inspection.gd`: `9DC1989F000E577811CD9181A7918DEBD999EF82CEC4197C7C455FC6CE193D21`.
- `tests/capture_battle_card_ui.gd`: `AF7C148831AF07ED67AAAD9B2A7CD67DF0CFFD186BAB6A3E483B98A2DF001B5C`.
- Formal DOCX: `7DA80F8D483F3816F9730882410DE3957FB3BC7FDE6E5BCCA0A3FE589BC75F5C`.
- The admin dashboard v1.2 task is `WAITING_USER_AUTH`; it released all paths in this write set and retains only dashboard-local files. Its unfinished changes remain untouched and excluded from this task's commit.

## Acceptance evidence required

1. Focused tests prove that a closer candidate cannot steal a valid animal/tower lock, while death and out-of-range movement both cause reacquisition.
2. Unit inspection tests prove the textual title contains no rarity label and retains exactly one animal name.
3. A real Godot capture at the target portrait viewport visually shows the thumbnail without a second name and the summary without quality text.
4. GDScript indentation validation, project-level Godot parse, focused regressions and the deterministic battle benchmark pass.
5. No configuration table changes are authorized or needed. No APK, server or Alibaba Cloud deployment is part of this request.

## Gate statement

`READY FOR DOCUMENT-FIRST WRITE AND SCOPED IMPLEMENTATION`.
