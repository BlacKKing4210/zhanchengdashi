# REQ-20260906-UI-STATES — completed scoped UI corrections

State: COMPLETE for the four requested runtime UI changes; no APK, device-release or server-deployment claim. Owner codex-primary; producer user-producer. Baseline 77567cc4e168d29f450f571382c01c76696245cb. Current branch codex/animal-art-integration-20260811.

## Delivered / player-visible evidence

- Affordable tiles: saturated #FFF000 over a thin #9D721B under-stroke. The same tile becomes muted gray at zero gold; untouched terrain assets and purchase logic. Engine images 07_yellow_battle_highlights.png and 08_green_battle_highlights.png show 25/50/100 affordable and 250 unavailable states.
- Legendary animal and tower cards: #ECC45F gold through shared rarity mapping, including their detail name plate and avatar background consumer. Other rarity mappings unchanged. Images 02_deck_gold_and_upgrade_dots.png and 10_gold_tower.png.
- Action affordance: gold primary #F3C454, teal secondary #87BABB, unavailable #DDD7CC with readable #625D55 label. Navigation uses only idle #B6C9C6 and selected gold. Secondary/retry/re-login actions stay clickable; CTA emphasis no longer doubles as its enabled state. Images 01_lobby_buttons.png, 05_room_disabled_join.png and 06_room_ready_join.png. ui-ux-pro-max contrast/state guidance informed semantic tokens and explicit availability; page geometry and input targets are unchanged.
- Upgrade dot: 14 px red center plus 2 px light separation ring, inside the card's top-right corner. Equipped and collection grids share the live upgrade predicate with the detail button and progress bar. No dot for unowned, insufficient or max-level cards. Images 03_upgrade_ready.png and 04_after_upgrade.png show the real upgrade tap consuming fragments and removing the dot. Scroll clipping has a GPU pixel regression. 09_tall_deck.png covers 720 x 1600.
- All images are under output/runtime_ui_states_20260906 and produced by the actual Godot drawing functions with isolated in-memory test state, not mockup artwork. Room connection labels in these fixtures are simulated UI state, not external server evidence.

## Verification

- Godot 4.6.3, gl_compatibility, RTX 4060 Laptop: test_ui_action_states PASS, 330 checks including pixel checks, all card eligibility edge states, real upgrade/re-login tap paths, 10 page/state captures and tile affordability transition. Headless counterpart PASS, 304 checks. Explicit --capture-ui-states test argument only; normal boot never invokes the test fixture.
- test_handdrawn_ui_skin PASS 63; rendering_clarity PASS 15; multiplayer_camera PASS; card_upgrade_health_rules (SceneTree --script entry) PASS; defense_tower_ui_contract PASS; online_room_code_input PASS; account_manual_login_entry PASS; runtime_gm_panel PASS; account_avatar_picker PASS.
- Battle logic benchmark: 72 units, 80 warmup steps, 400 samples; mean 1031.22 us, median 995 us, P95 1293 us, existing limit 4000 us. Not a phone FPS or GPU benchmark.
- GDScript indentation check and git diff --check pass. Some existing headless test fixtures still emit ObjectDB/resource shutdown warnings. Final GPU UI capture had no script errors or shutdown warning.
- Normal bootstrap launches the game and exits under a bounded 120-frame smoke run, but reports an OnlineRoom RPC checksum mismatch at /root/OnlineRoom. This is a separate unresolved network integration concern, not a passing live-room acceptance. No RPC methods, protocol files or cloud service were changed by this task; no server fix/deploy attempted.

## Final source hashes (SHA256)

- scripts/app/main.gd: D77EEEEE72176B6140A121E9DFBD28F292FCE740A4C2BFB4B76EA0D4AB1885FF
- scripts/app/ui/handdrawn_ui_skin.gd: 07BF155EEBFC601F6343AA7AD7E312E58D36490B49D1912F2955DAB72398A05E
- tests/test_ui_action_states.gd: 953C2E54C7D5E19B54D64766B7C39CF058BD0021758CA9FD33D510BBF37AF23B
- tests/test_ui_action_states.tscn: 597C9B9684A1A079C6921DDD45E08F3658FB287A4B54E33A8E7BDB5BCE36D04D

## Boundaries / cleanup

- Runtime write set is only main.gd and handdrawn_ui_skin.gd; new regression scene/script, scoped receipts/lock and selected runtime evidence accompany them. Config tables/runtime exports, animal and terrain source art, account persistence and click rectangles untouched.
- Producer workbook was opened/externally changed during execution: baseline SHA256 8D927D5508F8DA6AC01056CF954EA887F433D3179976043C5AF477EBEE402457, read-shared final snapshot 0A28971EA2FB63343524868C1B75C052F7C221EC6D8F5784EA430AC9831127B0. It was never edited or staged by this task; preserve the current producer version rather than restoring the baseline.
- Previous B icon-alpha permission remains pending and independent. No new atlas extraction or image processing attempted.
- Task-created failed parse processes stopped by exact test command-line match; user editor processes untouched. Task logs under temp/ui_states_20260906 removed after recording evidence, permanent tests and selected captures retained. No new persistent service or test profile created. Existing unrelated caches and local work preserved.
- Lock released. RAG refreshed after receipt/active-scope updates before Git delivery. Focused current-branch commit/push required; no main merge or APK. Rollback is a focused revert, not a workspace reset.
- reusable_method_candidate: none.
