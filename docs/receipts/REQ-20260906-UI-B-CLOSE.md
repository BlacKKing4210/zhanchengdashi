# REQ-20260906-UI-B-IMPLEMENT — core checkpoint

Overall: PARTIAL. B skin, terrain, loading and input adaptation implemented; distinctive icon atlas is NOT_RUNTIME pending producer authorization for local alpha cleanup. Do not report the entire art set as finished. Shared write lock released while awaiting that choice.

## Implemented

- Original eight terrain PNGs copied byte-identically (manifest SHA256 validation 8/8). Full-viewport terrain drawing, HUD overlaid, no board frame/mask; pointy-top world coordinates and 1.30 camera scale preserved.
- Drawing/culling expands to the viewport edges on tall devices. Default framing centers smaller maps or focuses the local base without an initial blank overscroll. HUD tap, drag-start, release and wheel exclusions prevent accidental purchases/panning underneath overlays.
- Borderless cached UI surfaces, shallow warm shadows, two-state nav backgrounds, raised card selection, muted rarity fills, actual levels/counts, aligned stats/skill/progress, untruncated long tower names. No balance/config/workbook changes.
- Account/room native input fields and GM/avatar overlays themed without replacing input/focus/virtual-keyboard behavior. Static approved loading illustration bound to boot splash. No icon atlas with fake transparency was bound into runtime.
- Short resource labels are retained until distinctive approved resource icons are available. Legacy nav pictograms remain temporarily; their replacement is outstanding.

## Evidence

- Godot 4.6.3, gl_compatibility, RTX 4060 Laptop desktop rendering. 21 page/state screenshots at 720 x 1280; 6 extra captures including 720 x 1600, high resource values, long tower skill, GM and an actual battle advanced 3 simulated seconds.
- Retained runtime images: output/runtime_ui_b_20260906/. Full task-local captures/logs: temp/ui_b_runtime_20260906/core_final/, extra/ and *.log. Images are engine renders with isolated in-memory fixtures, not external account/server acceptance.
- New test_handdrawn_ui_skin: PASS, 63 checks. Camera regression, rendering clarity (15 checks), tower UI/skills, room code input, manual login entry, GM and avatar tests pass. Latest indentation and git diff whitespace checks pass. No final script parser errors.
- 72-unit logic benchmark: mean 1159.98 us; median 1090 us; P95 1580 us; 400 samples after 80 warmup steps, under the existing 4000 us limit. This is not a phone FPS measurement.
- Some short-lived headless test harnesses report ObjectDB/audio-resource cleanup warnings at shutdown. Verbose new-test probe points to pause.wav, not a parser/texture failure. Interactive render captures terminate without script errors. This does not establish a leak-free device build.

## Remaining / rollback

- Built-in atlas generation and a background-edit retry both returned RGB with baked checkerboard. Neither is runtime-ready. Pending question asks whether to perform local pixel-preserving background removal or retain original icons.
- No APK generated, no phone/Android keyboard-on-device claim, no remote server deployment.
- Backup codex/pre-ui-art-20260906 at b54f4d3156f78a0125f6c79dd052cca8984bb272 is pushed. It includes the producer's dirty workbook. Original workbook stays dirty and untouched on the implementation branch; unrelated caches/local receipts are excluded from staging.
- Existing animal/building/branding sources retained. Rollback via backup branch or focused revert, never a destructive workspace reset.
