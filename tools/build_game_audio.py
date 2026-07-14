#!/usr/bin/env python3
"""Deterministically synthesize the original music and SFX used by the game."""

from __future__ import annotations

import argparse
import math
import wave
from pathlib import Path

import numpy as np


SAMPLE_RATE = 32000
PEAK_TARGET = 0.89
ROOT = Path(__file__).resolve().parents[1]
DEFAULT_OUTPUT = ROOT / "assets" / "audio"


def midi_frequency(note: float) -> float:
    return 440.0 * (2.0 ** ((note - 69.0) / 12.0))


def adsr(length: int, attack: float, decay: float, sustain: float, release: float) -> np.ndarray:
    envelope = np.ones(length, dtype=np.float64) * sustain
    attack_n = min(length, max(1, int(attack * SAMPLE_RATE)))
    decay_n = min(max(0, length - attack_n), max(1, int(decay * SAMPLE_RATE)))
    release_n = min(max(0, length - attack_n - decay_n), max(1, int(release * SAMPLE_RATE)))
    envelope[:attack_n] = np.linspace(0.0, 1.0, attack_n, endpoint=False)
    if decay_n:
        envelope[attack_n:attack_n + decay_n] = np.linspace(1.0, sustain, decay_n, endpoint=False)
    if release_n:
        envelope[-release_n:] *= np.linspace(1.0, 0.0, release_n)
    return envelope


def oscillator(frequency: float, length: int, instrument: str, rng: np.random.Generator) -> np.ndarray:
    time = np.arange(length, dtype=np.float64) / SAMPLE_RATE
    phase = 2.0 * np.pi * frequency * time
    if instrument == "marimba":
        signal = np.sin(phase) + 0.34 * np.sin(phase * 3.01) + 0.16 * np.sin(phase * 5.03)
        signal *= np.exp(-time * 4.4)
        envelope = adsr(length, 0.004, 0.07, 0.36, min(0.18, length / SAMPLE_RATE * 0.35))
    elif instrument == "pluck":
        signal = np.sin(phase) + 0.28 * np.sin(phase * 2.0) + 0.10 * np.sin(phase * 4.0)
        signal += 0.045 * rng.normal(0.0, 1.0, length) * np.exp(-time * 24.0)
        signal *= np.exp(-time * 2.8)
        envelope = adsr(length, 0.003, 0.05, 0.42, min(0.16, length / SAMPLE_RATE * 0.30))
    elif instrument == "pad":
        signal = np.sin(phase) + 0.20 * np.sin(phase * 2.0) + 0.08 * np.sin(phase * 3.0)
        signal += 0.08 * np.sin(phase * 0.997)
        envelope = adsr(length, 0.18, 0.32, 0.78, min(0.45, length / SAMPLE_RATE * 0.30))
    elif instrument == "bass":
        signal = np.sin(phase) + 0.24 * np.sin(phase * 2.0) + 0.07 * np.sin(phase * 3.0)
        signal *= 0.88 + 0.12 * np.cos(2.0 * np.pi * 2.0 * time)
        envelope = adsr(length, 0.006, 0.10, 0.58, min(0.14, length / SAMPLE_RATE * 0.25))
    elif instrument == "bell":
        signal = np.sin(phase) + 0.42 * np.sin(phase * 2.006) + 0.19 * np.sin(phase * 3.997)
        signal *= np.exp(-time * 2.6)
        envelope = adsr(length, 0.002, 0.05, 0.48, min(0.30, length / SAMPLE_RATE * 0.35))
    elif instrument == "brass":
        signal = sum(np.sin(phase * harmonic) / harmonic for harmonic in range(1, 6))
        envelope = adsr(length, 0.025, 0.08, 0.70, min(0.15, length / SAMPLE_RATE * 0.25))
    else:
        signal = np.sin(phase)
        envelope = adsr(length, 0.005, 0.05, 0.7, min(0.12, length / SAMPLE_RATE * 0.2))
    return (signal / max(1.0, np.max(np.abs(signal)))) * envelope


def pan_gains(pan: float) -> tuple[float, float]:
    angle = (np.clip(pan, -1.0, 1.0) + 1.0) * math.pi / 4.0
    return math.cos(angle), math.sin(angle)


def add_stereo(buffer: np.ndarray, signal: np.ndarray, start: int, amplitude: float, pan: float, circular: bool = True) -> None:
    left_gain, right_gain = pan_gains(pan)
    if circular:
        indices = (np.arange(signal.size, dtype=np.int64) + start) % buffer.shape[0]
        np.add.at(buffer[:, 0], indices, signal * amplitude * left_gain)
        np.add.at(buffer[:, 1], indices, signal * amplitude * right_gain)
        return
    if start >= buffer.shape[0]:
        return
    end = min(buffer.shape[0], start + signal.size)
    signal = signal[:end - start]
    buffer[start:end, 0] += signal * amplitude * left_gain
    buffer[start:end, 1] += signal * amplitude * right_gain


def add_note(
    buffer: np.ndarray,
    start_seconds: float,
    duration_seconds: float,
    note: float,
    instrument: str,
    amplitude: float,
    pan: float,
    rng: np.random.Generator,
    circular: bool = True,
) -> None:
    length = max(2, int(round(duration_seconds * SAMPLE_RATE)))
    signal = oscillator(midi_frequency(note), length, instrument, rng)
    add_stereo(buffer, signal, int(round(start_seconds * SAMPLE_RATE)), amplitude, pan, circular)


def kick(duration: float, rng: np.random.Generator) -> np.ndarray:
    length = max(2, int(duration * SAMPLE_RATE))
    time = np.arange(length) / SAMPLE_RATE
    frequency = 112.0 * np.exp(-time * 18.0) + 43.0
    phase = 2.0 * np.pi * np.cumsum(frequency) / SAMPLE_RATE
    signal = np.sin(phase) * np.exp(-time * 15.0)
    signal += rng.normal(0.0, 0.035, length) * np.exp(-time * 38.0)
    signal[-min(length, 96):] *= np.linspace(1.0, 0.0, min(length, 96))
    return signal


def snare(duration: float, rng: np.random.Generator, soft: bool = False) -> np.ndarray:
    length = max(2, int(duration * SAMPLE_RATE))
    time = np.arange(length) / SAMPLE_RATE
    noise = rng.normal(0.0, 1.0, length)
    noise = noise - np.convolve(noise, np.ones(13) / 13.0, mode="same")
    body = np.sin(2.0 * np.pi * 178.0 * time)
    decay = np.exp(-time * (18.0 if soft else 12.0))
    signal = (noise * (0.55 if soft else 0.72) + body * 0.28) * decay
    signal[-min(length, 96):] *= np.linspace(1.0, 0.0, min(length, 96))
    return signal


def shaker(duration: float, rng: np.random.Generator) -> np.ndarray:
    length = max(2, int(duration * SAMPLE_RATE))
    time = np.arange(length) / SAMPLE_RATE
    noise = rng.normal(0.0, 1.0, length)
    high = noise - np.convolve(noise, np.ones(21) / 21.0, mode="same")
    signal = high * np.exp(-time * 26.0)
    signal[-min(length, 64):] *= np.linspace(1.0, 0.0, min(length, 64))
    return signal


def add_drum(buffer: np.ndarray, start_seconds: float, sound: np.ndarray, amplitude: float, pan: float = 0.0) -> None:
    add_stereo(buffer, sound, int(round(start_seconds * SAMPLE_RATE)), amplitude, pan, True)


def circular_reverb(buffer: np.ndarray, taps: tuple[tuple[float, float], ...]) -> np.ndarray:
    result = buffer.copy()
    for delay_seconds, gain in taps:
        result += np.roll(buffer, int(round(delay_seconds * SAMPLE_RATE)), axis=0) * gain
    return result


def finish_music(buffer: np.ndarray) -> np.ndarray:
    buffer -= np.mean(buffer, axis=0, keepdims=True)
    buffer = circular_reverb(buffer, ((0.105, 0.10), (0.217, 0.065), (0.337, 0.035)))
    buffer = np.tanh(buffer * 1.08)
    edge = min(128, buffer.shape[0] // 8)
    for channel in range(buffer.shape[1]):
        value_delta = buffer[0, channel] - buffer[-1, channel]
        slope_delta = (buffer[1, channel] - buffer[0, channel]) - (buffer[-1, channel] - buffer[-2, channel])
        scaled_slope = slope_delta * float(edge - 1)
        quadratic = 3.0 * value_delta - scaled_slope
        cubic = scaled_slope - 2.0 * value_delta
        t = np.linspace(0.0, 1.0, edge)
        buffer[-edge:, channel] += quadratic * t * t + cubic * t * t * t
    peak = float(np.max(np.abs(buffer)))
    if peak > 0.0:
        buffer *= PEAK_TARGET / peak
    return buffer


def compose_menu_music() -> np.ndarray:
    rng = np.random.default_rng(1042026)
    bpm = 104.0
    beat = 60.0 / bpm
    bars = 12
    total_seconds = bars * 4.0 * beat
    buffer = np.zeros((int(round(total_seconds * SAMPLE_RATE)), 2), dtype=np.float64)
    chords = [
        (50, 62, 66, 69), (45, 57, 61, 64), (47, 59, 62, 66), (43, 55, 59, 62),
        (50, 62, 66, 69), (42, 54, 57, 61), (43, 55, 59, 62), (45, 57, 61, 64),
        (47, 59, 62, 66), (43, 55, 59, 62), (45, 57, 61, 64), (50, 62, 66, 69),
    ]
    melody_patterns = [
        (74, 76, 78, 81, 78, 76, 74, 69),
        (73, 76, 81, 78, 76, 73, 71, 69),
        (71, 74, 78, 81, 78, 74, 71, 69),
        (71, 74, 76, 78, 76, 74, 71, 67),
    ]
    for bar, chord in enumerate(chords):
        bar_time = bar * 4.0 * beat
        root, *tones = chord
        for tone_index, tone in enumerate(tones):
            add_note(buffer, bar_time, 4.45 * beat, tone, "pad", 0.075, -0.34 + tone_index * 0.34, rng)
        for half in range(2):
            start = bar_time + half * 2.0 * beat
            add_note(buffer, start, 1.18 * beat, root, "bass", 0.20, -0.08, rng)
            for tone_index, tone in enumerate(tones):
                add_note(buffer, start + tone_index * 0.035, 0.82 * beat, tone + 12, "pluck", 0.10, -0.48 + tone_index * 0.46, rng)
        pattern = melody_patterns[bar % len(melody_patterns)]
        for step, note in enumerate(pattern):
            if (bar + step) % 7 == 5:
                continue
            add_note(buffer, bar_time + step * 0.5 * beat, 0.58 * beat, note, "marimba", 0.14, 0.26, rng)
        if bar % 2 == 1:
            add_note(buffer, bar_time + 2.5 * beat, 1.05 * beat, tones[-1] + 19, "bell", 0.055, 0.62, rng)
        for pulse in range(8):
            add_drum(buffer, bar_time + pulse * 0.5 * beat, shaker(0.085, rng), 0.022, 0.52 if pulse % 2 else -0.52)
        add_drum(buffer, bar_time, kick(0.22, rng), 0.17)
        add_drum(buffer, bar_time + 2.0 * beat, kick(0.18, rng), 0.11)
        add_drum(buffer, bar_time + beat, snare(0.16, rng, soft=True), 0.055, 0.15)
        add_drum(buffer, bar_time + 3.0 * beat, snare(0.16, rng, soft=True), 0.070, -0.12)
    return finish_music(buffer)


def compose_battle_music() -> np.ndarray:
    rng = np.random.default_rng(1122026)
    bpm = 112.0
    beat = 60.0 / bpm
    bars = 12
    total_seconds = bars * 4.0 * beat
    buffer = np.zeros((int(round(total_seconds * SAMPLE_RATE)), 2), dtype=np.float64)
    chords = [
        (50, 62, 66, 69), (45, 57, 61, 64), (47, 59, 62, 66), (43, 55, 59, 62),
        (50, 62, 66, 69), (43, 55, 59, 62), (40, 52, 55, 59), (45, 57, 61, 64),
        (47, 59, 62, 66), (43, 55, 59, 62), (45, 57, 61, 64), (50, 62, 66, 69),
    ]
    melody_patterns = [
        (74, 76, 78, 81, 78, 76, 74, 71),
        (73, 76, 78, 81, 78, 76, 73, 69),
        (71, 74, 76, 78, 81, 78, 74, 71),
    ]
    for bar, chord in enumerate(chords):
        bar_time = bar * 4.0 * beat
        root, *tones = chord
        for tone_index, tone in enumerate(tones):
            add_note(buffer, bar_time, 4.40 * beat, tone, "pad", 0.060, -0.30 + tone_index * 0.30, rng)
        for pulse in range(4):
            start = bar_time + pulse * beat
            bass_note = root + (12 if pulse == 3 and bar % 2 == 1 else 0)
            add_note(buffer, start, 0.72 * beat, bass_note, "bass", 0.13 if pulse % 2 == 0 else 0.09, -0.08, rng)
            tone = tones[pulse % len(tones)] + 12
            add_note(buffer, start + 0.08 * beat, 0.58 * beat, tone, "pluck", 0.065, -0.42 + (pulse % 3) * 0.36, rng)
        melody = melody_patterns[bar % len(melody_patterns)]
        for step, note in enumerate(melody):
            if (bar + step) % 6 == 4:
                continue
            add_note(buffer, bar_time + step * 0.5 * beat, 0.54 * beat, note, "marimba", 0.095, 0.28, rng)
        if bar in (3, 7, 11):
            add_note(buffer, bar_time + 2.5 * beat, 0.95 * beat, tones[-1] + 19, "bell", 0.035, 0.56, rng)
        for pulse in range(8):
            add_drum(buffer, bar_time + pulse * 0.5 * beat, shaker(0.07, rng), 0.016, 0.55 if pulse % 2 else -0.55)
        add_drum(buffer, bar_time, kick(0.20, rng), 0.12)
        add_drum(buffer, bar_time + 2.0 * beat, kick(0.18, rng), 0.075)
        add_drum(buffer, bar_time + beat, snare(0.16, rng, soft=True), 0.040, -0.10)
        add_drum(buffer, bar_time + 3.0 * beat, snare(0.16, rng, soft=True), 0.048, 0.12)
    return finish_music(buffer)


def mono_note(note: float, duration: float, instrument: str, amplitude: float, rng: np.random.Generator) -> np.ndarray:
    signal = oscillator(midi_frequency(note), max(2, int(duration * SAMPLE_RATE)), instrument, rng)
    return signal * amplitude


def mix_mono(duration: float, events: list[tuple[float, np.ndarray]]) -> np.ndarray:
    buffer = np.zeros(max(2, int(round(duration * SAMPLE_RATE))), dtype=np.float64)
    for start, signal in events:
        index = int(round(start * SAMPLE_RATE))
        if index >= buffer.size:
            continue
        end = min(buffer.size, index + signal.size)
        buffer[index:end] += signal[:end - index]
    buffer -= np.mean(buffer)
    edge = min(96, buffer.size // 6)
    buffer[:edge] *= np.linspace(0.0, 1.0, edge)
    buffer[-edge:] *= np.linspace(1.0, 0.0, edge)
    buffer = np.tanh(buffer * 1.10)
    peak = float(np.max(np.abs(buffer)))
    if peak > 0.0:
        buffer *= PEAK_TARGET / peak
    return buffer


def whoosh(duration: float, rising: bool, rng: np.random.Generator) -> np.ndarray:
    length = int(duration * SAMPLE_RATE)
    time = np.arange(length) / SAMPLE_RATE
    noise = rng.normal(0.0, 1.0, length)
    smooth = np.convolve(noise, np.ones(31) / 31.0, mode="same")
    high = noise - smooth
    sweep = np.linspace(0.2, 1.0, length) if rising else np.linspace(1.0, 0.2, length)
    envelope = np.sin(np.linspace(0.0, np.pi, length)) ** 1.4
    return high * sweep * envelope * 0.26


def compose_sfx() -> dict[str, np.ndarray]:
    rng = np.random.default_rng(42102026)
    sounds: dict[str, np.ndarray] = {}
    sounds["ui_click"] = mix_mono(0.09, [(0.0, mono_note(86, 0.085, "marimba", 0.72, rng))])
    sounds["ui_confirm"] = mix_mono(0.24, [
        (0.0, mono_note(74, 0.15, "pluck", 0.62, rng)),
        (0.075, mono_note(78, 0.16, "bell", 0.58, rng)),
    ])
    sounds["ui_error"] = mix_mono(0.28, [
        (0.0, mono_note(66, 0.18, "marimba", 0.58, rng)),
        (0.09, mono_note(63, 0.18, "marimba", 0.52, rng)),
    ])
    sounds["card_select"] = mix_mono(0.16, [
        (0.0, mono_note(74, 0.13, "pluck", 0.60, rng)),
        (0.045, mono_note(81, 0.10, "bell", 0.30, rng)),
    ])
    sounds["card_upgrade"] = mix_mono(0.72, [
        (0.00, mono_note(74, 0.28, "bell", 0.48, rng)),
        (0.10, mono_note(78, 0.32, "bell", 0.53, rng)),
        (0.21, mono_note(81, 0.42, "bell", 0.60, rng)),
        (0.34, mono_note(86, 0.34, "bell", 0.44, rng)),
    ])
    sounds["gacha_open"] = mix_mono(0.86, [
        (0.0, whoosh(0.58, True, rng)),
        (0.34, mono_note(74, 0.44, "bell", 0.48, rng)),
        (0.46, mono_note(81, 0.36, "bell", 0.55, rng)),
    ])
    sounds["gacha_reveal"] = mix_mono(0.44, [
        (0.0, mono_note(81, 0.32, "bell", 0.64, rng)),
        (0.07, mono_note(86, 0.31, "bell", 0.43, rng)),
    ])
    sounds["room_join"] = mix_mono(0.38, [
        (0.0, mono_note(69, 0.22, "pluck", 0.50, rng)),
        (0.105, mono_note(74, 0.24, "bell", 0.58, rng)),
    ])
    sounds["pause"] = mix_mono(0.17, [
        (0.0, mono_note(69, 0.13, "marimba", 0.50, rng)),
        (0.045, mono_note(69, 0.11, "marimba", 0.42, rng)),
    ])
    sounds["battle_start"] = mix_mono(0.92, [
        (0.00, mono_note(62, 0.30, "brass", 0.46, rng)),
        (0.12, mono_note(66, 0.34, "brass", 0.48, rng)),
        (0.25, mono_note(69, 0.40, "brass", 0.53, rng)),
        (0.42, mono_note(74, 0.44, "bell", 0.48, rng)),
    ])
    sounds["unit_spawn"] = mix_mono(0.22, [
        (0.0, kick(0.14, rng) * 0.35),
        (0.015, mono_note(74, 0.18, "pluck", 0.46, rng)),
    ])
    sounds["unit_attack"] = mix_mono(0.14, [
        (0.0, whoosh(0.12, False, rng) * 0.74),
        (0.045, mono_note(62, 0.08, "marimba", 0.30, rng)),
    ])
    sounds["ranged_attack"] = mix_mono(0.16, [
        (0.0, whoosh(0.14, True, rng) * 0.62),
        (0.0, mono_note(86, 0.12, "pluck", 0.39, rng)),
    ])
    sounds["tower_attack"] = mix_mono(0.20, [
        (0.0, kick(0.12, rng) * 0.44),
        (0.035, mono_note(69, 0.14, "pluck", 0.46, rng)),
    ])
    sounds["unit_hit"] = mix_mono(0.15, [
        (0.0, kick(0.11, rng) * 0.52),
        (0.012, snare(0.11, rng, soft=True) * 0.34),
    ])
    sounds["shield_hit"] = mix_mono(0.24, [
        (0.0, mono_note(81, 0.19, "bell", 0.52, rng)),
        (0.018, snare(0.12, rng, soft=True) * 0.20),
    ])
    sounds["unit_death"] = mix_mono(0.44, [
        (0.0, mono_note(62, 0.24, "pluck", 0.48, rng)),
        (0.10, mono_note(57, 0.25, "marimba", 0.45, rng)),
        (0.19, mono_note(50, 0.23, "marimba", 0.38, rng)),
    ])
    sounds["building_break"] = mix_mono(0.58, [
        (0.0, kick(0.26, rng) * 0.62),
        (0.015, snare(0.34, rng) * 0.46),
        (0.12, mono_note(50, 0.40, "marimba", 0.36, rng)),
    ])
    sounds["territory_capture"] = mix_mono(0.30, [
        (0.0, whoosh(0.18, True, rng) * 0.34),
        (0.04, mono_note(69, 0.17, "pluck", 0.38, rng)),
        (0.11, mono_note(74, 0.16, "marimba", 0.34, rng)),
    ])
    sounds["unlock"] = mix_mono(0.44, [
        (0.0, mono_note(74, 0.22, "pluck", 0.48, rng)),
        (0.08, mono_note(78, 0.28, "bell", 0.54, rng)),
        (0.16, mono_note(81, 0.25, "bell", 0.39, rng)),
    ])
    sounds["stat_gain"] = mix_mono(0.36, [
        (0.0, mono_note(69, 0.20, "marimba", 0.42, rng)),
        (0.085, mono_note(74, 0.23, "bell", 0.47, rng)),
    ])
    sounds["power_up"] = mix_mono(0.62, [
        (0.0, mono_note(69, 0.25, "bell", 0.40, rng)),
        (0.10, mono_note(74, 0.30, "bell", 0.48, rng)),
        (0.22, mono_note(78, 0.34, "bell", 0.53, rng)),
        (0.34, mono_note(81, 0.26, "bell", 0.44, rng)),
    ])
    sounds["victory"] = mix_mono(1.44, [
        (0.00, mono_note(62, 0.45, "brass", 0.45, rng)),
        (0.18, mono_note(66, 0.48, "brass", 0.48, rng)),
        (0.36, mono_note(69, 0.56, "brass", 0.52, rng)),
        (0.58, mono_note(74, 0.76, "bell", 0.56, rng)),
        (0.58, mono_note(78, 0.72, "bell", 0.38, rng)),
    ])
    sounds["draw"] = mix_mono(1.18, [
        (0.00, mono_note(69, 0.42, "marimba", 0.44, rng)),
        (0.24, mono_note(71, 0.45, "bell", 0.43, rng)),
        (0.48, mono_note(69, 0.58, "bell", 0.39, rng)),
    ])
    sounds["defeat"] = mix_mono(1.30, [
        (0.00, mono_note(69, 0.42, "marimba", 0.43, rng)),
        (0.22, mono_note(66, 0.44, "marimba", 0.40, rng)),
        (0.46, mono_note(62, 0.72, "bell", 0.38, rng)),
    ])
    return sounds


def write_wav(path: Path, samples: np.ndarray) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    clipped = np.clip(samples, -1.0, 1.0)
    pcm = np.round(clipped * 32767.0).astype("<i2")
    channels = 1 if pcm.ndim == 1 else pcm.shape[1]
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(channels)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(pcm.tobytes())


def verify_wav(path: Path, expect_channels: int) -> None:
    with wave.open(str(path), "rb") as handle:
        assert handle.getframerate() == SAMPLE_RATE, path
        assert handle.getsampwidth() == 2, path
        assert handle.getnchannels() == expect_channels, path
        frames = handle.readframes(handle.getnframes())
    samples = np.frombuffer(frames, dtype="<i2").astype(np.float64) / 32767.0
    assert samples.size > SAMPLE_RATE // 20, path
    assert np.isfinite(samples).all(), path
    assert float(np.max(np.abs(samples))) <= 0.91, path
    assert float(np.sqrt(np.mean(samples * samples))) > 0.01, path


def build(output: Path) -> None:
    music = {
        "menu_happy_loop": compose_menu_music(),
        "battle_happy_drive_loop": compose_battle_music(),
    }
    sfx = compose_sfx()
    for name, samples in music.items():
        path = output / "music" / f"{name}.wav"
        write_wav(path, samples)
        verify_wav(path, 2)
        print(f"music {name}: {samples.shape[0] / SAMPLE_RATE:.3f}s")
    for name, samples in sfx.items():
        path = output / "sfx" / f"{name}.wav"
        write_wav(path, samples)
        verify_wav(path, 1)
        print(f"sfx {name}: {samples.shape[0] / SAMPLE_RATE:.3f}s")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=DEFAULT_OUTPUT)
    args = parser.parse_args()
    build(args.output.resolve())


if __name__ == "__main__":
    main()
