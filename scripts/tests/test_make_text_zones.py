"""Tests for scripts/make_text_zones.py: calm, dark places on the painting to set wall text."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import make_text_zones as tz  # noqa: E402


def test_quietness_prefers_dark_calm_over_bright_or_busy():
    dark_calm = np.full((40, 40), 0.15)
    bright_calm = np.full((40, 40), 0.85)
    busy = np.tile([[0.1, 0.9], [0.9, 0.1]], (20, 20))
    q = tz.quietness
    assert q(dark_calm) > q(bright_calm)
    assert q(dark_calm) > q(busy)


def test_zones_do_not_overlap_and_come_best_first():
    # A dark left half and a bright right half: the zones should all sit on the left.
    img = np.hstack([np.full((100, 100), 0.1), np.full((100, 100), 0.9)])
    zones = tz.find_zones(img, card_w=0.3, card_h=0.25, count=3)
    assert zones and all(z["x"] + z["w"] <= 0.55 for z in zones)
    scores = [z["score"] for z in zones]
    assert scores == sorted(scores, reverse=True)
    for i, a in enumerate(zones):
        for b in zones[i + 1:]:
            assert not tz.overlaps(a, b)


def test_zones_stay_on_the_painting():
    img = np.random.default_rng(1).random((80, 96))
    for z in tz.find_zones(img, card_w=0.34, card_h=0.2, count=6):
        assert 0 <= z["x"] and z["x"] + z["w"] <= 1 and 0 <= z["y"] and z["y"] + z["h"] <= 1


ZONES = Path(__file__).resolve().parent.parent.parent / "App/Content/textzones.json"


@pytest.mark.skipif(not ZONES.exists(), reason="textzones.json not generated yet")
def test_shipped_zones_cover_several_parts_of_the_painting():
    doc = json.loads(ZONES.read_text())
    zones = doc["zones"]
    assert len(zones) >= 5
    # Not all bunched together: zones in at least two of the three horizontal thirds.
    thirds = {int((z["x"] + z["w"] / 2) * 3) for z in zones}
    assert len(thirds) >= 2
