"""Tests for the real-recording soundscape builder (docs/superpowers/plans/2026-11-15-living-sound.md)."""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from make_soundscape import bloom, loop_crossfade, retune_ratio, set_level, trim_strike  # noqa: E402

SR = 8000


def _noise(seconds, seed=0):
    return np.random.default_rng(seed).standard_normal(int(seconds * SR)) * 0.1


def test_loop_has_the_requested_length_and_no_seam():
    x = _noise(30)
    y = loop_crossfade(x, SR, fade_seconds=5)
    assert len(y) == len(x) - 5 * SR
    jump = abs(y[0] - y[-1])
    assert jump < 5 * np.median(np.abs(np.diff(y)))


def test_loop_keeps_its_loudness_through_the_crossfade():
    x = _noise(30)
    y = loop_crossfade(x, SR, fade_seconds=5)
    head = np.sqrt(np.mean(y[: 5 * SR] ** 2))       # the crossfaded stretch
    body = np.sqrt(np.mean(y[10 * SR: 20 * SR] ** 2))
    assert 0.8 < head / body < 1.25                   # equal-power: no dip, no bump


def test_strike_starts_at_the_hit_and_fades_to_silence():
    x = np.concatenate([np.zeros(SR), np.exp(-np.arange(10 * SR) / SR) * np.sin(np.arange(10 * SR))])
    y = trim_strike(x, SR, max_seconds=6, fade_seconds=1.5)
    assert len(y) <= 6 * SR
    assert np.argmax(np.abs(y)) < 0.05 * SR           # the hit is right at the start
    assert abs(y[-1]) < 1e-6


def test_retune_moves_a_pitch_onto_the_target():
    assert abs(retune_ratio(276.0, 293.66) - 293.66 / 276.0) < 1e-12


def _big_noise():
    # Large (> 256 KB) and passed straight in as a temporary: NumPy 2.2 on Python 3.14 then
    # "elides" x ** 2 into the caller's array and squares the audio in place.
    return np.random.default_rng(0).standard_normal((300_000, 2)) * 0.05


def test_set_level_hits_the_target_and_never_clips():
    y = set_level(_big_noise(), rms_db=-20, peak=0.9)
    assert abs(20 * np.log10(np.sqrt(np.mean(np.square(y)))) + 20) < 0.5
    assert np.max(np.abs(y)) <= 0.9 + 1e-9


def test_set_level_holds_back_for_the_peak():
    y = set_level(_big_noise(), rms_db=-3, peak=0.5)
    assert abs(np.max(np.abs(y)) - 0.5) < 1e-9


def _strike():
    t = np.arange(12 * SR) / SR
    return np.exp(-t / 3) * np.sin(2 * np.pi * 300 * t)      # a hit at t=0, then the ring


def _envelope(y, seconds=0.1):
    w = int(seconds * SR)
    return np.sqrt(np.convolve(y ** 2, np.ones(w) / w, "valid"))


def test_a_bloom_has_no_strike_it_swells_in():
    y = bloom(_strike(), SR, skip_seconds=1.0, rise_seconds=1.5, length_seconds=7, fall_seconds=4)
    env = _envelope(y)
    peak_at = np.argmax(env) / SR
    assert peak_at > 1.0                                       # the loudest moment is well after the start
    assert env[int(0.1 * SR)] < 0.2 * env.max()                # it begins almost silent


def test_a_bloom_breathes_out_to_silence():
    y = bloom(_strike(), SR, skip_seconds=1.0, rise_seconds=1.5, length_seconds=7, fall_seconds=4)
    assert len(y) == 7 * SR
    assert abs(y[-1]) < 1e-9 and abs(y[0]) < 1e-9
