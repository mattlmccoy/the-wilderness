#!/usr/bin/env python3
"""Find calm, dark places on the painting to set wall text, and write App/Content/textzones.json.

Usage (from the Wilderness folder):
    python3 -I scripts/make_text_zones.py App/Content/painting.jpg App/Content/textzones.json

Matt's wall has no room beside the tapestry, so text sits on the painting. A projector only adds
light, so ivory text reads best where the painting is dark and calm (little fine detail). This
scores every card-sized window by darkness and calm, and keeps the best windows that don't overlap.
The app then picks, per figure, the best zone that doesn't cover that figure.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np

CARD_W = 0.34      # about 20 in of the 60 in tapestry
CARD_H = 0.24      # about 12 in: a title, a line, a short story
COUNT = 8
STEP = 0.02


def quietness(a: np.ndarray) -> float:
    """0…1, higher = better for light text: dark (60%) and calm (40%)."""
    dark = 1.0 - float(a.mean())
    busy = float(np.abs(np.diff(a, axis=1)).mean() + np.abs(np.diff(a, axis=0)).mean())
    calm = max(0.0, 1.0 - busy * 4)
    return 0.6 * dark + 0.4 * calm


def overlaps(a: dict, b: dict) -> bool:
    return not (a["x"] + a["w"] <= b["x"] or b["x"] + b["w"] <= a["x"] or
                a["y"] + a["h"] <= b["y"] or b["y"] + b["h"] <= a["y"])


def find_zones(img: np.ndarray, card_w: float = CARD_W, card_h: float = CARD_H,
               count: int = COUNT, step: float = STEP) -> list[dict]:
    """Best non-overlapping card windows, best first. `img` is luminance 0…1."""
    h, w = img.shape
    cands = []
    y = 0.0
    while y + card_h <= 1 + 1e-9:
        x = 0.0
        while x + card_w <= 1 + 1e-9:
            win = img[int(y * h):int((y + card_h) * h), int(x * w):int((x + card_w) * w)]
            if win.size:
                cands.append({"x": round(x, 3), "y": round(y, 3), "w": card_w, "h": card_h,
                              "score": round(quietness(win), 4)})
            x += step
        y += step
    cands.sort(key=lambda z: z["score"], reverse=True)
    chosen: list[dict] = []
    for c in cands:
        if all(not overlaps(c, z) for z in chosen):
            chosen.append(c)
            if len(chosen) == count:
                break
    return chosen


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__)
        return 2
    from PIL import Image
    img = np.asarray(Image.open(argv[1]).convert("L"), dtype=float) / 255.0
    zones = find_zones(img)
    Path(argv[2]).write_text(json.dumps({"source": "scripts/make_text_zones.py", "zones": zones}, indent=1) + "\n")
    for z in zones:
        print(z)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
