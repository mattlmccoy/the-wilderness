"""Tests for the generated wind bed: it must loop without a click, stay quiet, and be reproducible."""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from make_wind import PEAK, make_wind  # noqa: E402

RATE = 22050


def test_length_and_peak_level():
    w = make_wind(seconds=8, rate=RATE, seed=1)
    assert len(w) == 8 * RATE
    assert np.max(np.abs(w)) <= PEAK + 1e-9
    assert np.max(np.abs(w)) > PEAK * 0.9            # normalised, not accidentally near-silent


def test_loop_seam_has_no_click():
    w = make_wind(seconds=8, rate=RATE, seed=1)
    jump = abs(w[0] - w[-1])
    typical = np.median(np.abs(np.diff(w)))
    assert jump < 5 * typical, f"seam jump {jump:.5f} vs typical step {typical:.5f}"


def test_it_is_wind_not_hiss():
    # Energy should sit low: most power under 800 Hz, like distant wind.
    w = make_wind(seconds=8, rate=RATE, seed=1)
    spec = np.abs(np.fft.rfft(w)) ** 2
    freqs = np.fft.rfftfreq(len(w), 1 / RATE)
    assert spec[freqs < 800].sum() / spec.sum() > 0.85


def test_gusts_rise_and_fall():
    w = make_wind(seconds=20, rate=RATE, seed=1)
    rms = [np.sqrt(np.mean(w[i:i + RATE] ** 2)) for i in range(0, len(w) - RATE, RATE)]
    assert max(rms) / min(rms) > 1.5                   # audible swells, not a flat drone


def test_same_seed_same_sound():
    assert np.array_equal(make_wind(seconds=2, rate=RATE, seed=7), make_wind(seconds=2, rate=RATE, seed=7))
