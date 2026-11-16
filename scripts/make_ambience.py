#!/usr/bin/env python3
"""Generate the ethereal pad for the app's optional sound (Menu → Sound).

Original, synthesised audio (no recordings, so no licence questions). Run from the Wilderness folder:
    python3 -I scripts/make_ambience.py      # writes App/Sound/ambience.m4a (120 s stereo loop)

Four soft chords in D drift into one another; each voice is a pair of slightly detuned tones
with faint overtones, and a high shimmer comes and goes. Everything is built to repeat exactly
over the loop (frequencies on whole cycles, envelopes and the reverb circular), so it has no seam.
It sits between about 150 Hz and 4 kHz, where a TV or projector speaker can play it (the old wind
bed lived under 800 Hz and small speakers barely sounded it).
"""
from __future__ import annotations

import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

PEAK = 0.5            # -6 dBFS; the app's player volume sets the real loudness
SECONDS = 120
RATE = 44100
SEED = 2026

# Dadd9 → Bm7 → Gmaj9 → Asus2: open, unresolved, nothing that pulls for attention.
CHORDS = [
    [146.83, 220.00, 329.63, 369.99, 440.00],
    [246.94, 293.66, 369.99, 440.00, 659.26],
    [196.00, 246.94, 293.66, 369.99, 440.00],
    [220.00, 329.63, 493.88, 659.26],
]
DETUNE_HZ = 0.18      # the slow beating between each voice's two tones
OVERTONES = [(2, 0.22), (3, 0.07)]
SHIMMER = [880.00, 1318.51, 1479.98]   # A5, E6, F#6: the airy top


def _on_loop(freq: float, n: int, rate: int) -> float:
    """The nearest frequency that completes whole cycles over the loop (so it repeats exactly)."""
    return round(freq * n / rate) * rate / n


def _tone(freq: float, n: int, rate: int, phase: float) -> np.ndarray:
    t = np.arange(n) / rate
    return np.sin(2 * np.pi * _on_loop(freq, n, rate) * t + phase)


def _chord_envelopes(n: int, count: int) -> list[np.ndarray]:
    """One smooth, circular swell per chord; neighbours overlap so the harmony drifts, never cuts."""
    pos = np.arange(n) / n * count
    envs = []
    for k in range(count):
        d = (pos - k + count / 2) % count - count / 2      # distance from the chord's centre, wrapped
        envs.append(np.where(np.abs(d) < 1.0, np.cos(np.pi * d / 2) ** 2, 0.0))
    return envs


def _circular_filter(x: np.ndarray, rate: int, lo: float, hi: float) -> np.ndarray:
    spec = np.fft.rfft(x)
    f = np.maximum(np.fft.rfftfreq(len(x), 1 / rate), 1.0)
    spec *= 1 / (1 + (lo / f) ** 4) / (1 + (f / hi) ** 4)
    return np.fft.irfft(spec, len(x))


def _reverb(x: np.ndarray, rate: int, rng: np.random.Generator, seconds: float = 4.0) -> np.ndarray:
    """A long soft hall: circular convolution with decaying noise, so the tail wraps the loop."""
    n = len(x)
    m = min(n, int(seconds * rate))
    ir = np.zeros(n)
    t = np.arange(m) / rate
    ir[:m] = rng.standard_normal(m) * np.exp(-6.9 * t / seconds)
    ir /= np.sqrt(np.sum(ir ** 2))
    return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(ir), n)


def make_ambience(seconds: float = SECONDS, rate: int = RATE, seed: int = SEED) -> np.ndarray:
    """The pad as an (n, 2) float array, peak exactly PEAK."""
    rng = np.random.default_rng(seed)
    n = int(seconds * rate)
    t = np.arange(n) / n                                  # 0…1 over the loop
    envs = _chord_envelopes(n, len(CHORDS))
    out = np.zeros((n, 2))
    for ch in range(2):
        dry = np.zeros(n)
        for chord, env in zip(CHORDS, envs):
            for f in chord:
                voice = np.zeros(n)
                for side in (-1, 1):
                    base = f + side * DETUNE_HZ / 2
                    voice += _tone(base, n, rate, rng.uniform(0, 2 * np.pi))
                    for mult, gain in OVERTONES:
                        voice += gain * _tone(base * mult, n, rate, rng.uniform(0, 2 * np.pi))
                dry += env * voice / np.sqrt(len(chord))
        # The shimmer: high tones that each bloom twice per loop, at their own times.
        for f in SHIMMER:
            bloom = 0.5 - 0.5 * np.cos(2 * np.pi * (2 * t + rng.uniform(0, 1)))
            dry += 0.18 * bloom ** 2 * _tone(f, n, rate, rng.uniform(0, 2 * np.pi))
        # A slow breath over the whole pad: three swells a loop.
        dry *= 0.72 + 0.28 * (0.5 - 0.5 * np.cos(2 * np.pi * (3 * t + 0.1 * ch)))
        wet = _reverb(dry, rate, rng)
        mix = 0.45 * dry / np.max(np.abs(dry)) + 0.55 * wet / np.max(np.abs(wet))
        out[:, ch] = _circular_filter(mix, rate, lo=140.0, hi=4500.0)
    return out / np.max(np.abs(out)) * PEAK


def main() -> int:
    out_dir = Path("App/Sound")
    if not out_dir.is_dir():
        print("run from the Wilderness folder", file=sys.stderr)
        return 1
    pad = make_ambience()
    wav, m4a = out_dir / "ambience.wav", out_dir / "ambience.m4a"
    with wave.open(str(wav), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes((pad * 32767).astype("<i2").tobytes())
    subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "160000", str(wav), str(m4a)], check=True)
    wav.unlink()
    print(f"wrote {m4a} ({m4a.stat().st_size // 1024} KB, {SECONDS} s stereo loop)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
