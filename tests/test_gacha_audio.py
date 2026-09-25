"""Measure canonical WAV cues; preserve before/after metrics, no extra asset copies."""
import argparse
import hashlib
import json
import math
import wave
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "temp/qa/home-polish-20260925"


def measure(path):
    with wave.open(str(path), "rb") as stream:
        rate = stream.getframerate()
        channels = stream.getnchannels()
        samples = np.frombuffer(stream.readframes(stream.getnframes()), dtype="<i2").astype(float) / 32767
    spectrum = np.abs(np.fft.rfft(samples * np.hanning(len(samples)))) ** 2
    frequencies = np.fft.rfftfreq(len(samples), 1 / rate)
    energy = max(float(spectrum.sum()), 1e-20)
    peak = float(np.max(np.abs(samples)))
    return {"path": str(path.relative_to(ROOT)), "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
            "rate": rate, "channels": channels, "duration_s": len(samples) / rate / channels,
            "peak_linear": peak, "peak_dbfs": 20 * math.log10(max(peak, 1e-20)),
            "rms_dbfs": 20 * math.log10(max(float(np.sqrt(np.mean(samples ** 2))), 1e-20)),
            "energy_above_3000_hz": float(spectrum[frequencies >= 3000].sum() / energy),
            "spectral_centroid_hz": float((frequencies * spectrum).sum() / energy),
            "max_adjacent_sample_step": float(np.max(np.abs(np.diff(samples)))),
            "clipped_samples": int(np.count_nonzero(np.abs(samples) >= 0.999))}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--phase", choices=["before", "after"], required=True)
    args = parser.parse_args()
    reports = []
    failures = []
    for name in ["gacha_open", "gacha_reveal", "gacha_new_hero"]:
        path = ROOT / "assets/audio/sfx" / (name + ".wav")
        if not path.exists():
            failures.append(name + " missing")
            continue
        report = measure(path)
        reports.append(report)
        if report["peak_linear"] > 0.26: failures.append(name + " peak above soft cue ceiling")
        if report["energy_above_3000_hz"] > 0.01: failures.append(name + " excessive high frequency energy")
        if report["clipped_samples"]: failures.append(name + " clipped")
        if name == "gacha_reveal" and report["duration_s"] > 0.18: failures.append(name + " overlaps normal ten-pull interval")
    result = {"phase": args.phase, "reports": reports, "failures": failures,
              "scope": "PCM source metrics; UI bus adds -6dB; subjective listening remains producer acceptance"}
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / ("gacha-audio-" + args.phase + ".json")).write_text(json.dumps(result, indent=2), encoding="utf-8")
    print(json.dumps(result, indent=2))
    if args.phase == "after": assert not failures, failures


if __name__ == "__main__":
    main()
