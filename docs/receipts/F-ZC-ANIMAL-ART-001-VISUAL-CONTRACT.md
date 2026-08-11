# F-ZC-ANIMAL-ART-001 Visual Quality Contract

- Player-facing memory point: every animal reads as a distinct miniature 1930s-fairground combat character, with occupation/weapon silhouette visible before fine detail.
- Target runtime: Godot 4.6.x, portrait design canvas `720 x 1280`.
- Uses: deck grid, card detail, camp preview, selected-unit detail, and 44-pixel battle units.
- Approved source: the coherent 40-image set supplied in `D:\AI\art\草图导出` on `2026-08-11`.
- Style principles: bold ink edge, compact chibi silhouette, restrained role color, transparent background, one readable held prop or costume cue.
- Non-goals: no UI or layout redesign, no invented animal substitution beyond the supplied files, no reuse of third-party names/logos/layouts, and no gameplay or numeric changes.
- Runtime decomposition: one transparent PNG per existing card ID, loaded through the current `art_path` contract; no flattened screen art.
- Import rule: retain RGBA transparency, preserve source pixels, no deterministic redraw or AI regeneration, and use the current Godot texture filtering/import pipeline.
- Performance budget: one `480 x 480` source texture per replaced card, no new shaders, particles, atlases, or per-frame resource loads.
- Accessibility/readability: silhouettes must remain distinguishable at card sizes and at the 44-pixel battle-unit size; team rings, health bars, names, and interaction geometry remain unchanged.
- Representative slice: `rabbit`, because it exercises deck/detail and battle-unit scale without requiring a semantic substitution.
- Scale-out sampling: `ant` (small silhouette), `seal` (wide silhouette), `sheep` (tall silhouette), `pig` (large filled silhouette), `swan` and `crane` (explicit substitution-labelled sources).
- Representative runtime result: the 14 PNGs under `output/qa/F-ZC-ANIMAL-ART-001/` cover deck and battle presentation for `rabbit`, `ant`, `seal`, `sheep`, `pig`, `swan`, and `crane`. They prove the supplied art in deck detail, collection cards, bottom battle cards, and visible 44-pixel battle units through the normal Godot texture path.
- Full-set runtime result: `godot-capture.txt` records `ANIMAL_ART_TEXTURES_PASS: 40/40` and `ANIMAL_ART_CAPTURE_PASS` after importing the supplied textures in an isolated Godot project copy.
- Current gate: `SCALE_OUT_APPROVED WITH CONCERNS`; all 40 mapped images load at the expected size and sampled silhouettes have no blocking transparency, scale, anchor, import, or readability issue.
- Open visual concerns: `天鹅（章鱼）.png` is visibly an octopus while the existing card remains `天鹅`; `鹤（鹅）.png` is visibly a goose while the existing card remains `鹤`. The supplied pixels were integrated as requested, but producer confirmation or corrected files are required before release visual acceptance.
- Release boundary: this task can reach `SCALE_OUT_APPROVED` with local target-resolution runtime evidence, but not `RELEASE_VISUAL_APPROVED` without an exported build and target-device review.
