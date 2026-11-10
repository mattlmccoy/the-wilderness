import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from make_glints import select_catch_points  # noqa: E402


def test_isolated_highlights_are_all_kept():
    lum = np.full((40, 40), 0.2)
    spots = [(5, 5), (10, 30), (20, 20), (30, 8), (35, 35)]
    for r, c in spots:
        lum[r, c] = 1.0
    assert sorted(select_catch_points(lum)) == sorted(spots)


def test_flat_image_has_no_catch_points():
    assert select_catch_points(np.full((40, 40), 0.5)) == []


def test_points_at_the_image_edge_are_excluded():
    lum = np.full((100, 100), 0.2)
    lum[0, 50] = 1.0      # on the top edge: a crop artefact, not a highlight
    lum[50, 99] = 1.0     # on the right edge
    lum[50, 50] = 1.0     # inside
    assert select_catch_points(lum) == [(50, 50)]
