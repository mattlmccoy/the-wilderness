#!/usr/bin/env python3
"""Build a self-contained page for placing the Christmas hats and the star by hand.

    python3 scripts/make_placer.py            # writes build/placer/index.html

The page embeds the Met's full-resolution image, the figure outlines and the current
App/Content/delights.json. Drag to place; "Copy JSON" gives the new delights.json. The hat and
star drawing here mirrors App/DelightsLayer.swift, so what you place is what the wall draws.
"""
from __future__ import annotations

import base64
import io
import json
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PAINTING = ROOT / "docs/reference/met-11.53-DP-19630-001-4000x3349.jpg"
OUT = ROOT / "build/placer/index.html"


def painting_data_uri(width: int = 2400) -> str:
    im = Image.open(PAINTING).convert("RGB")
    im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=84)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()


def outlines() -> dict[str, list[list[float]]]:
    lib = json.loads((ROOT / "App/Content/annotations.json").read_text())
    return {a["id"]: [[p["x"], p["y"]] for p in a.get("outline") or []] for a in lib["annotations"]}


def build() -> str:
    delights = json.loads((ROOT / "App/Content/delights.json").read_text())
    template = (ROOT / "scripts/placer_template.html").read_text()
    return (template.replace("__PAINTING__", painting_data_uri())
                    .replace("__OUTLINES__", json.dumps(outlines()))
                    .replace("__DELIGHTS__", json.dumps(delights)))


if __name__ == "__main__":
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(build())
    print(OUT)
