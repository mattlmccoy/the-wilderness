"""Tests for the ethereal pad (Menu → Sound): it must be heard on a small TV or projector speaker,
loop without a seam, breathe slowly, and be reproducible."""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from make_ambience import PEAK, make_ambience  # noqa: E402

RATE = 22050
SECONDS = 24


def _pad():
    return make_ambience(seconds=SECONDS, rate=RATE, seed=1)


def _mono(x):
    return x.mean(axis=1)


def test_stereo_length_and_peak():
    x = _pad()
    assert x.shape == (SECONDS * RATE, 2)
    assert np.max(np.abs(x)) <= PEAK + 1e-9
    assert np.max(np.abs(x)) > PEAK * 0.9


def _band_db(x, lo=150, hi=4000):
    m = x.mean(axis=1) if x.ndim == 2 else x
    spec = np.fft.rfft(m)
    f = np.fft.rfftfreq(len(m), 1 / RATE)
    spec[(f < lo) | (f > hi)] = 0
    return 20 * np.log10(np.sqrt(np.mean(np.fft.irfft(spec, len(m)) ** 2)))


def test_louder_than_the_wind_where_small_speakers_play():
    # What a TV or projector speaker reproduces: the 150 Hz-4 kHz band. The wind bed put
    # only a sliver of its level there; the pad must be at least 6 dB above it.
    from make_wind import make_wind
    wind = make_wind(seconds=SECONDS, rate=RATE, seed=1)
    assert _band_db(_pad()) > _band_db(wind) + 6


def test_small_speakers_can_play_it():
    # Most energy between 150 Hz and 4 kHz, where a projector or TV speaker actually works.
    m = _mono(_pad())
    spec = np.abs(np.fft.rfft(m)) ** 2
    f = np.fft.rfftfreq(len(m), 1 / RATE)
    assert spec[(f >= 150) & (f <= 4000)].sum() / spec.sum() > 0.8


def test_loop_seam_is_seamless():
    x = _pad()
    for ch in range(2):
        jump = abs(x[0, ch] - x[-1, ch])
        typical = np.median(np.abs(np.diff(x[:, ch])))
        assert jump < 5 * typical


def test_it_breathes_but_never_drops_out():
    m = _mono(_pad())
    rms = np.array([np.sqrt(np.mean(m[i:i + RATE] ** 2)) for i in range(0, len(m) - RATE, RATE)])
    assert rms.max() / rms.min() > 1.2      # slow swells
    assert rms.min() > rms.max() * 0.25     # but always present


def test_reproducible():
    assert np.array_equal(make_ambience(seconds=4, rate=RATE, seed=3), make_ambience(seconds=4, rate=RATE, seed=3))
