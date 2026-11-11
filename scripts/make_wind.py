#!/usr/bin/env python3
"""Generate the quiet wind bed for the app's optional sound (Menu → Sound).

Original, synthesised audio (no recordings, so no licence questions). Run from the Wilderness folder:
    python3 -I scripts/make_wind.py        # writes App/Sound/wind.m4a (90 s loop)

The noise is shaped in the frequency domain, so it is exactly periodic: the loop has no seam.
Slow gusts (also periodic) swell the level and brighten a soft rustle band.
"""
from __future__ import annotations

import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

PEAK = 0.5            # -6 dBFS; the app's player volume sets the real loudness
SECONDS = 90
RATE = 44100
SEED = 2026


def _band(n: int, rate: int, rng: np.random.Generator, lo: float, hi: float, tilt: float) -> np.ndarray:
    """Periodic noise with energy between lo and hi Hz, falling as 1/f^tilt, soft edges."""
    freqs = np.fft.rfftfreq(n, 1 / rate)
    f = np.maximum(freqs, 1.0)
    mag = f ** -tilt
    mag *= 1 / (1 + (lo / f) ** 4)          # gentle high-pass
    mag *= 1 / (1 + (f / hi) ** 6)          # steeper low-pass
    phase = rng.uniform(0, 2 * np.pi, len(freqs))
    x = np.fft.irfft(mag * np.exp(1j * phase), n)
    return x / np.max(np.abs(x))


def _gusts(n: int, rate: int, rng: np.random.Generator) -> np.ndarray:
    """Slow swells, 0.35..1, built from whole cycles over the loop so it repeats seamlessly."""
    t = np.arange(n) / n
    seconds = n / rate
    env = np.zeros(n)
    for period in (23.0, 11.0, 7.0):
        cycles = max(1, round(seconds / period))
        env += rng.uniform(0.6, 1.0) * np.sin(2 * np.pi * (cycles * t + rng.uniform()))
    env = (env - env.min()) / (env.max() - env.min())
    return 0.35 + 0.65 * env ** 1.5


def make_wind(seconds: float = SECONDS, rate: int = RATE, seed: int = SEED) -> np.ndarray:
    n = int(seconds * rate)
    rng = np.random.default_rng(seed)
    low = _band(n, rate, rng, lo=30, hi=350, tilt=1.0)
    rustle = _band(n, rate, rng, lo=250, hi=900, tilt=0.6)
    g = _gusts(n, rate, rng)
    w = g * low + 0.35 * g ** 2 * rustle
    return w * (PEAK / np.max(np.abs(w)))


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    out_dir = root / "App/Sound"
    out_dir.mkdir(exist_ok=True)
    wav, m4a = out_dir / "wind.wav", out_dir / "wind.m4a"
    pcm = (make_wind() * 32767).astype("<i2")
    with wave.open(str(wav), "wb") as f:
        f.setnchannels(1); f.setsampwidth(2); f.setframerate(RATE); f.writeframes(pcm.tobytes())
    subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", "96000", str(wav), str(m4a)], check=True)
    wav.unlink()
    print(f"wrote {m4a} ({m4a.stat().st_size // 1024} KB, {SECONDS} s loop)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
