# F-ZC-ANIMAL-ART-001 Battle Animal / HP Bar Alignment Read-Only Receipt

## Control state

- Request: `REQ-20260811-ANIMAL-FOOT-HP-ALIGNMENT`.
- Producer-visible issue: in the supplied battle screenshot, the enlarged animal silhouettes sit too far above their fixed HP bars.
- Feature/version: `F-ZC-ANIMAL-ART-001` / `v1.2`.
- RAG: `READY`; index signature `040f12d8e3114eb668ce5ae4a75436147512a04f6462e2a2de3effe25e1675f1`; request receipt contains 9 verified citations.
- Control route: `L3`, current control agent acting as the unique `engineering_owner`; no new agent or task is created.
- Branch/commit baseline: `codex/animal-art-integration-20260811` at `50e1d31a8e4a9ec7222438922160b48508587cd1`.

## Read-only diagnosis

- The living battle animal texture is foot-anchored at `pos + Vector2(0, 14)` while the HP bar starts at `pos + Vector2(-18, 20)`, so the intended logical gap is 6 design pixels.
- The 40 newly integrated source textures are all `480 x 480`, but their alpha silhouettes end 59 to 145 source pixels above the canvas bottom (`0.12291667` to `0.30208333` of texture height).
- The existing 1.35 display scale also scales that transparent bottom padding, producing roughly 7.3 to 17.9 design pixels of extra visible separation before the intended 6-pixel gap.
- The supplied screenshot matches this failure mode. Unit world coordinates, tile coordinates, collision, selection/input bounds, shadow, and HP-bar coordinates are not the cause.

## Authorized implementation boundary

- Add an exact per-card transparent-bottom ratio for the same 40-card integrated-art roster.
- In the living battle-unit draw path only, shift the texture rectangle in local draw space so each visible alpha silhouette ends at the existing logical foot point.
- Keep the HP bar at its current position, preserving the intended 6-design-pixel idle gap.
- Preserve 1.35 integrated-art scaling, rarity scaling, procedural pose transforms, world/tile coordinates, collision, selection/touch bounds, shadows, all card/deck/detail layouts, death effects, source PNG pixels, configuration, and server/network behavior.
- Allowed tracked writes: `scripts/app/main.gd`, `tests/test_unit_procedural_motion.gd`, this receipt and its closure receipt, `docs/active_scope.yaml`, and the seven battle QA PNGs for the existing representative capture set.
- Forbidden writes: animal PNG pixels, CSV/JSON gameplay data, unrelated UI, branding, package outputs, server/network code, main-branch state, and unrelated untracked files.

## Acceptance

- The integrated-art padding map has exactly the same 40 IDs as the 1.35 display roster; non-integrated cards resolve to zero compensation.
- At idle pose, the compensated visible alpha bottom is mathematically equal to the existing logical foot point for representative minimum, middle, and maximum padding cases.
- The fixed HP-bar top remains 6 design pixels below the logical foot point.
- Procedural pose inputs and unit logical state are not mutated.
- GDScript indentation, Godot editor parse/startup, focused motion/alignment regression, adjacent battle regressions, and the 720x1280 runtime capture pass.
- Final target-resolution battle screenshots show materially reduced and consistent animal-to-bar spacing without overlap or clipping.
