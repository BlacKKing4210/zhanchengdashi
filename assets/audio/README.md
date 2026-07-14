# Game Audio Assets

All files in this directory are original, deterministic synthesized audio for this project.

- `music/menu_happy_loop.wav`: lighthearted non-combat loop, 104 BPM.
- `music/battle_happy_drive_loop.wav`: relaxed lighthearted battle loop with sparse percussion, 112 BPM.
- `sfx/*.wav`: UI, progression, gacha, room, combat, and result feedback.
- Source generator: `tools/build_game_audio.py`.

Runtime looping, routing, crossfades, cooldowns, pitch variation, and volume controls are owned by `scripts/app/systems/game_audio.gd`. Do not reference audio from `tmp/`; temporary probe files are excluded from exports.
