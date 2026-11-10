#!/usr/bin/env python3
"""Copy the round-3 study's estimated subject outlines into App/Content/annotations.json.

Usage: python3 -I scripts/import_outlines.py [outlines.json] [annotations.json]

Outlines are in pixels of the Met's 600x502 image, which has a black border
(11 px left/right, 10 px top/bottom). They are mapped to artwork-normalised
coordinates with u=(x-11)/578, v=(y-10)/482, clamped to 0..1.
Only `outline` and `geometrySource` are written; copy is never touched.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def to_artwork(x: float, y: float) -> dict:
    clamp = lambda t: min(max(t, 0.0), 1.0)
    return {"x": round(clamp((x - 11) / 578), 4), "y": round(clamp((y - 10) / 482), 4)}


def main(outlines_path: Path, annotations_path: Path) -> None:
    outlines = json.loads(outlines_path.read_text())["outlines"]
    lib = json.loads(annotations_path.read_text())
    updated = []
    for a in lib["annotations"]:
        if a["id"] not in outlines:
            raise SystemExit(f"no estimated outline for {a['id']}")
        rebuilt = {}
        for k, v in a.items():
            if k in ("outline",):
                continue
            rebuilt[k] = v
            if k == "anchor":
                rebuilt["outline"] = [to_artwork(x, y) for x, y in outlines[a["id"]]]
        rebuilt["geometrySource"] = "met-reference-estimate"
        updated.append(rebuilt)
    lib["annotations"] = updated
    annotations_path.write_text(json.dumps(lib, indent=2, ensure_ascii=False) + "\n")
    print(f"wrote outlines for {len(updated)} subjects")


if __name__ == "__main__":
    args = sys.argv[1:]
    main(Path(args[0]) if args else ROOT / "docs/reference/estimated-outlines.json",
         Path(args[1]) if len(args) > 1 else ROOT / "App/Content/annotations.json")
