#!/usr/bin/env python3
"""Build the living sound from real CC0 recordings (docs/superpowers/plans/2026-11-15-living-sound.md).

Sources are Freesound previews kept in assets-staging/sound/ (not in git; ids and authors in
App/Sound/CREDITS.md). Run from the Wilderness folder:
    python3 -I scripts/make_soundscape.py      # writes App/Sound/bed.m4a and App/Sound/bowl.m4a

The bed is looped with a long equal-power crossfade so it has no seam; the bowl is one clean
strike, tuned to D4 so the app can ring every figure in key by varispeed.
"""
from __future__ import annotations

import subprocess
import sys
from pathlib import Path

import numpy as np

RATE = 44100
STAGING = Path("assets-staging/sound")
OUT = Path("App/Sound")
D4 = 293.66


def load(path: Path, rate: int = RATE, channels: int = 2, ratio: float = 1.0,
         start: float = 0.0, seconds: float | None = None) -> np.ndarray:
    """Decode any audio file to float samples, shape (n, channels); `ratio` plays it faster
    (higher) or slower (lower), like a tape; start and seconds are in the source's own time."""
    cmd = ["ffmpeg", "-v", "error", "-ss", str(start)] + (["-t", str(seconds)] if seconds else []) + ["-i", str(path)]
    cmd += ["-af", f"aresample={RATE},asetrate={RATE}*{ratio},aresample={rate}", "-ac", str(channels), "-f", "f32le", "-"]
    raw = subprocess.run(cmd, capture_output=True, check=True).stdout
    return np.frombuffer(raw, np.float32).astype(float).reshape(-1, channels)


def loop_crossfade(x: np.ndarray, rate: int, fade_seconds: float) -> np.ndarray:
    """A seamless loop: the last `fade_seconds` fade (equal power) into the first, so the result
    is len(x) - fade long and its end runs straight into its start."""
    x = np.array(x, dtype=float)
    f = int(fade_seconds * rate)
    t = np.linspace(0, np.pi / 2, f)
    fade_in, fade_out = np.sin(t), np.cos(t)
    if x.ndim == 2:
        fade_in, fade_out = fade_in[:, None], fade_out[:, None]
    head = x[:f] * fade_in + x[-f:] * fade_out
    return np.concatenate([head, x[f:-f]])


def trim_strike(x: np.ndarray, rate: int, max_seconds: float, fade_seconds: float) -> np.ndarray:
    """One strike: from just before the hit to at most `max_seconds`, ending in a cosine fade."""
    x = np.array(x, dtype=float)
    mono = np.abs(x if x.ndim == 1 else x.mean(axis=1))
    start = max(int(np.argmax(mono > 0.25 * mono.max())) - int(0.004 * rate), 0)
    y = x[start:start + int(max_seconds * rate)].copy()
    f = min(int(fade_seconds * rate), len(y))
    ramp = 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, f))
    y[-f:] *= ramp if y.ndim == 1 else ramp[:, None]
    y[-1] = 0
    return y


def retune_ratio(f0: float, target: float) -> float:
    """Playback-rate ratio that moves `f0` onto `target` (varispeed: pitch and time together)."""
    return target / f0


def set_level(x: np.ndarray, rms_db: float, peak: float) -> np.ndarray:
    """Scale to an average level, but never past `peak`."""
    x = np.array(x, dtype=float)              # own copy: NumPy 2.2 + Python 3.14 can square a temporary in place
    rms = np.sqrt(np.mean(np.square(x)))
    g = min(10 ** (rms_db / 20) / rms, peak / np.max(np.abs(x)))
    return x * g


def write_m4a(x: np.ndarray, path: Path, rate: int = RATE, bitrate: int = 192000) -> None:
    wav = path.with_suffix(".wav")
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-f", "s16le", "-ar", str(rate), "-ac", str(x.shape[1]),
                    "-i", "-", str(wav)], input=pcm.tobytes(), check=True)
    subprocess.run(["afconvert", "-f", "m4af", "-d", "aac", "-b", str(bitrate), str(wav), str(path)], check=True)
    wav.unlink()


def main() -> int:
    if not OUT.is_dir():
        print("run from the Wilderness folder", file=sys.stderr)
        return 1
    semitone = 2 ** (1 / 12)
    # The bed, layer 1: "AMB_Meditation Choir" (Freesound 360352, zazz.sound.design, CC0), D major.
    choir = load(STAGING / "cand/360352.mp3", start=2, seconds=62)
    choir = set_level(loop_crossfade(choir, RATE, fade_seconds=10), rms_db=-20, peak=0.7)
    # Layer 2: "ultimate relaxation" (Freesound 263467, PhonZz, CC0), in C: raised a whole tone to D.
    # A different loop length from the choir, so together they never repeat the same way.
    pad = load(STAGING / "cand/263467.mp3", ratio=semitone ** 2, start=240, seconds=200)
    pad = set_level(loop_crossfade(pad, RATE, fade_seconds=16), rms_db=-23, peak=0.6)
    # The bowl: "Tibetan bowl_center hit" (Freesound 421829, dersinnsspace, CC0), 276 Hz → D4.
    bowl = load(STAGING / "ev/421829.mp3", ratio=retune_ratio(276.0, D4))
    bowl = set_level(trim_strike(bowl, RATE, max_seconds=14, fade_seconds=4), rms_db=-22, peak=0.85)
    for name, x in [("choir", choir), ("pad", pad), ("bowl", bowl)]:
        write_m4a(x, OUT / f"{name}.m4a")
        print(f"wrote {OUT / name}.m4a  {len(x) / RATE:5.1f} s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
