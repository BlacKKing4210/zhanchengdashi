# F-ZC-BRANDING-001 Visual Quality Contract And Read-Only Receipt

- Request: create one game application icon and one portrait loading/boot image, integrate both through the normal Godot project path, then rebuild and validate Windows, Android, and Web packages.
- Producer authority: the producer-user explicitly requested creation, runtime integration, and repackaging on 2026-08-11.
- Player-facing memory point: a crowned animal commander above a hex-territory emblem immediately reads as the original 1930s animal-war game.
- Approved visual baseline: the current v15 1930s hand-painted fairground direction under `output/visual_concepts/`, using warm paper, deep ink outlines, muted crimson, antique gold, and restrained teal.
- Anti-copying boundary: create an original animal commander and emblem; do not copy commercial characters, logos, currencies, layouts, or named identities.
- Icon contract: opaque square PNG, `1024 x 1024`, one strong centered silhouette, no text, no watermark, 10 percent safe margin, readable at `48 x 48`.
- Loading contract: opaque portrait PNG, `1080 x 1920`, centered commander and hex-territory story beat, quiet top and bottom safe areas, no baked UI text, no button, no watermark.
- Runtime decomposition: `assets/branding/app_icon_1024.png` is the project/application icon; `assets/branding/loading_portrait_1080x1920.png` is the Godot boot splash. Neither image contains dynamic text or interactive UI.
- Target platforms: Windows Desktop, Android portrait phone, and Web portrait canvas.
- Responsive rule: Android remains fixed portrait; the loading focal point stays inside the center safe region under crop or aspect expansion.
- Performance budget: one `1024 x 1024` icon and one `1080 x 1920` loading texture; no shader, animation, per-frame load, network dependency, or new plugin.
- Baseline settings: `project.godot` currently uses `res://icon.svg`, has no custom boot splash, and already fixes handheld orientation to portrait (`window/handheld/orientation=1`).
- Write scope: `assets/branding/`, `project.godot`, task QA/receipt files, ignored package outputs under `build/`, and task-local temporary staging only.
- Excluded scope: gameplay, balance/config values, navigation, page layout, controls, server deployment, broad UI skin replacement, and unrelated existing worktree files.
- Acceptance: exact dimensions and image decoding pass; Godot imports and starts without parser/resource errors; the boot-splash project settings resolve to the new resources; generated icon remains legible at launcher size; Windows, Android, and Web exports pass package integrity checks; Android manifest remains portrait-only.
- Visual gate boundary: exported package evidence can support `RUNTIME_SLICE_APPROVED`; `RELEASE_VISUAL_APPROVED` still requires producer review on target devices.
