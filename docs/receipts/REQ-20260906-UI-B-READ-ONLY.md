# REQ-20260906-UI-B-IMPLEMENT — intake / implementation contract

- Authority: producer approves runtime integration, full-page battle terrain with HUD overlaid, and explicitly selects B (borderless + shallow shadow).
- Owner: codex-primary, sole writer. Existing shared locks checked: released. No server change.
- Baseline: f8e4e7a on codex/animal-art-integration-20260811. Recovery branch codex/pre-ui-art-20260906 at b54f4d3156f78a0125f6c79dd052cca8984bb272 pushed to origin. Snapshot includes producer's uncommitted design/战斗数值.xlsx; workbook remains untouched.
- RAG: temp/rag/context/REQ-20260906-UI-B-IMPLEMENT.md. Latest producer instructions and current code supersede old DOCX excerpts.
- Sources: output/visual_concepts/ui_border_ab_20260906/B_lobby_borderless.png and B_deck_borderless.png; producer-supplied hex PNGs; current runtime page geometry/input contract.
- Write set: app drawing/UI adapters; assets/ui/handdrawn; assets/art/terrain/handdrawn; scoped tests; this receipt, active_scope and visual concept status.
- Excluded: gameplay values, workbook, CSV/runtime config, account persistence/protocol, remote service, APK, unrelated caches and pending files.
- Loading: bind the already-approved 22_loading.png illustration (no UI/progress baked into it) as the engine boot splash; warm paper boot background. Keep original branding icon and source assets available for rollback.

## Components / acceptance

- Icon extraction contract: reproduce the already-approved B lobby icons as one transparent 3 x 3 atlas, each square cell isolated with 15% clear padding: shop awning, helmet, crossed swords; stone portal, hamster portrait, paw coin; blue paw ticket, attack paw, heart. No text/guides, no page UI, no external IP. B lobby is the written whole-set style approval; codex-primary verifies extraction parity and alpha before mapping AtlasTexture regions. Candidate remains outside assets until checked. Runtime atlas target assets/ui/handdrawn/icons.png; UI display 24-80 px. No repainting of animals/terrain.

- 720 x 1280 remains the design canvas. Paper #F4EEE3, surface #E9DFCE, raised #F6F0E7, ink #332F29, primary/selected #F2D28A, sage #CED4A9, blue #B8CFDF, lilac #CDB9D6, peach #EABCA5.
- Borderless rounded UI with shallow warm shadows; illustration outlines unchanged. Existing animal/tower art and 1.35 animal scaling retained.
- Nav uses two fill states plus an indicator. Card selection uses light raised emphasis + downward marker, not a red frame. Ownership and rarity remain legible.
- Detail stats group, full skill and progress share one center axis; portrait/name and action targets retained. Live stats only, no mock values, no range/interval fields.
- Native inputs/GM retain focus/scroll behavior. Terrain renders before HUD. Full viewport culling/camera inverse, HUD exclusion for taps/drag starts/wheel; no world-state or zoom changes.
- First verify a 720 x 1280 runtime battle slice before shared UI expansion; capture other pages and long portrait. Run parser/indentation, camera/input/card/tower/rendering/performance checks. Package and true-device validation remain separate.
- Commit only task files and push current branch; preserve workbook and unrelated files; release scoped lock and report actual evidence.
