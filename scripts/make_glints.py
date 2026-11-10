#!/usr/bin/env python3
"""Precompute where glints may appear (spec §4.1) and write App/Content/glints.json.

Usage: python3 -I scripts/make_glints.py <image> <out.json>

A pixel is a candidate when its luminance is above the image's 60th percentile and
above the mean of its 7x7 neighbourhood: edges and highlights where light could catch.
The outer 2% of the image is ignored. The strongest 6% of candidates are kept
(at least 40, or all if fewer).
The image is the Met's 600x502 reference; its black border (11 px left/right,
10 px top/bottom) is cropped so points are in artwork-normalised coordinates.
"""
import json
import math
import sys
from pathlib import Path

import numpy as np

WINDOW = 7
PERCENTILE = 60
KEEP_FRACTION = 0.06
MIN_KEEP = 40
BORDER_X, BORDER_Y = 11, 10
EDGE_MARGIN = 0.02  # ignore the outer 2%: crop artefacts, and glints on the woven border look wrong


def local_mean(a: np.ndarray, k: int = WINDOW) -> np.ndarray:
    pad = k // 2
    p = np.pad(a, pad, mode="reflect")
    c = np.cumsum(np.cumsum(p, axis=0), axis=1)
    c = np.pad(c, ((1, 0), (1, 0)))
    h, w = a.shape
    s = c[k:k + h, k:k + w] - c[0:h, k:k + w] - c[k:k + h, 0:w] + c[0:h, 0:w]
    return s / (k * k)


def select_catch_points(lum: np.ndarray) -> list[tuple[int, int]]:
    mean = local_mean(lum)
    lift = lum - mean
    mask = (lum > np.percentile(lum, PERCENTILE)) & (lift > 1e-9)
    h, w = lum.shape
    my, mx = max(1, round(EDGE_MARGIN * h)), max(1, round(EDGE_MARGIN * w))
    inner = np.zeros_like(mask)
    inner[my:h - my, mx:w - mx] = True
    mask &= inner
    rows, cols = np.nonzero(mask)
    if rows.size == 0:
        return []
    keep = min(rows.size, max(MIN_KEEP, math.ceil(KEEP_FRACTION * rows.size)))
    order = np.argsort(-lift[rows, cols], kind="stable")[:keep]
    return [(int(rows[i]), int(cols[i])) for i in order]


def main(image: Path, out: Path) -> None:
    from PIL import Image

    img = Image.open(image).convert("RGB")
    w, h = img.size
    img = img.crop((BORDER_X, BORDER_Y, w - BORDER_X, h - BORDER_Y))
    rgb = np.asarray(img, dtype=float) / 255.0
    lum = 0.2126 * rgb[..., 0] + 0.7152 * rgb[..., 1] + 0.0722 * rgb[..., 2]
    ch, cw = lum.shape
    pts = [{"x": round(c / (cw - 1), 4), "y": round(r / (ch - 1), 4)} for r, c in select_catch_points(lum)]
    out.write_text(json.dumps({"source": image.name, "points": pts}, indent=1) + "\n")
    print(f"{len(pts)} glint points from {image.name}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    main(Path(sys.argv[1]), Path(sys.argv[2]))
