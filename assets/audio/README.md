# Game Audio Assets

All files in this directory are original, deterministic synthesized audio for this project.

- `music/menu_happy_loop.wav`: lighthearted non-combat loop, 104 BPM.
- `music/battle_happy_drive_loop.wav`: relaxed lighthearted battle loop with sparse percussion, 112 BPM.
- `sfx/*.wav`: UI, progression, gacha, room, combat, and result feedback.
- Source generator: `tools/build_game_audio.py`.

Runtime looping, routing, crossfades, cooldowns, pitch variation, and volume controls are owned by `scripts/app/systems/game_audio.gd`. Do not reference audio from `tmp/`; temporary probe files are excluded from exports.

Gacha cues use rounded sine-based wood tones with smooth 35ms attacks. `gacha_open`
is 0.62s at peak -14.9dBFS, `gacha_reveal` is 0.14s at -17.1dBFS (shorter than
the 0.18s card cadence), and `gacha_new_hero` is a 1.05s rising major motif at
-13.2dBFS. The UI bus adds its existing -6dB. The new-hero cue fires only once
when a first-owned animal transitions from rarity to its portrait, by tap or timer.
Regenerate just these cues with `python tools/build_game_audio.py --gacha-only`.
