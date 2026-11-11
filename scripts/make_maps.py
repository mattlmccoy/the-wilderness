#!/usr/bin/env python3
"""Build App/Content/maps.json: three real maps for Context, from Natural Earth (public domain).

Usage (from the Wilderness folder):
    python3 -I scripts/make_maps.py assets-staging/maps App/Content/maps.json

The first argument holds the Natural Earth 1:10m GeoJSON downloads (github.com/nvkelso/
natural-earth-vector, geojson/): ne_10m_coastline, ne_10m_lakes, ne_10m_lakes_europe,
ne_10m_rivers_lake_centerlines, ne_10m_rivers_europe. Each view keeps only the named water it
needs, cut to its box and simplified, so the app ships a few hundred kB of lines, not 30 MB.

Place coordinates are from Wikipedia's coordinate data (en.wikipedia.org, prop=coordinates),
looked up 2026-11-11; they are listed beside each place.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

SOURCE = ("Coastlines, lakes and rivers: Natural Earth 1:10m (public domain). "
          "Places: Wikipedia coordinates.")

LAYER_FILES = {
    "coast": "ne_10m_coastline",
    "lakes": "ne_10m_lakes",
    "lakes_europe": "ne_10m_lakes_europe",
    "rivers": "ne_10m_rivers_lake_centerlines",
    "rivers_europe": "ne_10m_rivers_europe",
}

# (minLon, minLat, maxLon, maxLat)
VIEWS = [
    {
        "id": "lombardy",
        "bbox": (8.8, 44.85, 12.6, 46.2),
        "tolerance": 0.003,
        "layers": [
            {"kind": "coast", "layer": "coast"},
            {"kind": "lake", "layer": "lakes", "names": ["Lago di Garda"]},
            {"kind": "lake", "layer": "lakes_europe", "names": ["Lago di Como", "Lago d' Iseo"]},
            {"kind": "river", "layer": "rivers", "names": ["Po", "Adige", "Mincio"]},
            {"kind": "river", "layer": "rivers_europe", "names": ["Oglio"]},
        ],
        "places": [
            {"name": "Milan", "lat": 45.4669, "lon": 9.19, "home": False},        # en.wikipedia Milan
            {"name": "Brescia", "lat": 45.5417, "lon": 10.2167, "home": True},    # en.wikipedia Brescia
            {"name": "Venice", "lat": 45.4375, "lon": 12.3358, "home": False},    # en.wikipedia Venice
        ],
        "labels": [{"text": "Lake Garda", "lat": 45.8, "lon": 11.08}, {"text": "Po", "lat": 45.08, "lon": 10.6}],
        "route": None,
    },
    {
        "id": "judea",
        "bbox": (35.05, 31.3, 35.75, 32.05),
        "tolerance": 0.001,
        "layers": [
            {"kind": "lake", "layer": "lakes", "names": ["Dead Sea"]},
            {"kind": "river", "layer": "rivers", "names": ["Jordan"]},
        ],
        "places": [
            {"name": "Jerusalem", "lat": 31.7789, "lon": 35.2256, "home": False},                 # en.wikipedia Jerusalem
            {"name": "Jericho", "lat": 31.8561, "lon": 35.46, "home": False},                     # en.wikipedia Jericho
            {"name": "Mount of Temptation", "lat": 31.8747, "lon": 35.4322, "home": True},        # Monastery of the Temptation
            {"name": "Baptism site", "lat": 31.8383, "lon": 35.5392, "home": False},              # Qasr al-Yahud
        ],
        "labels": [{"text": "Judean Desert", "lat": 31.62, "lon": 35.28},
                   {"text": "Dead Sea", "lat": 31.55, "lon": 35.5},
                   {"text": "Jordan", "lat": 31.98, "lon": 35.6}],
        "route": None,
    },
    {
        "id": "mediterranean",
        "bbox": (6.5, 29.5, 38.5, 47.0),
        "tolerance": 0.04,
        "layers": [{"kind": "coast", "layer": "coast"}],
        "places": [
            {"name": "Brescia", "lat": 45.5417, "lon": 10.2167, "home": True},
            {"name": "Jerusalem", "lat": 31.7789, "lon": 35.2256, "home": False},
        ],
        "labels": [],
        "route": ["Brescia", "Jerusalem"],
    },
]


def _inside(p, box) -> bool:
    return box[0] <= p[0] <= box[2] and box[1] <= p[1] <= box[3]


def clip_line(points: list, box) -> list[list]:
    """Pieces of a polyline that lie in the box. Each piece keeps one point past the edge on
    either side, so lines run off the map instead of stopping short of it."""
    pts = [tuple(p[:2]) for p in points]
    pieces: list[list] = []
    current: list = []
    for i, p in enumerate(pts):
        prev_in = i > 0 and _inside(pts[i - 1], box)
        next_in = i + 1 < len(pts) and _inside(pts[i + 1], box)
        if _inside(p, box) or prev_in or next_in:
            current.append(p)
        elif current:
            pieces.append(current)
            current = []
        if current and not _inside(p, box) and prev_in and not next_in:
            pieces.append(current)
            current = []
    if current:
        pieces.append(current)
    return [c for c in pieces if len(c) >= 2]


def simplify(points: list, tol: float) -> list:
    """Douglas-Peucker: drop points closer than `tol` to the line through their neighbours."""
    if len(points) < 3 or tol <= 0:
        return list(points)
    (x0, y0), (x1, y1) = points[0], points[-1]
    dx, dy = x1 - x0, y1 - y0
    norm = (dx * dx + dy * dy) ** 0.5
    best, idx = -1.0, 0
    for i in range(1, len(points) - 1):
        px, py = points[i]
        d = abs(dy * px - dx * py + x1 * y0 - y1 * x0) / norm if norm else ((px - x0) ** 2 + (py - y0) ** 2) ** 0.5
        if d > best:
            best, idx = d, i
    if best <= tol:
        return [points[0], points[-1]]
    return simplify(points[: idx + 1], tol)[:-1] + simplify(points[idx:], tol)


def _rings(geometry: dict) -> list:
    t, c = geometry["type"], geometry["coordinates"]
    if t == "LineString":
        return [c]
    if t in ("MultiLineString", "Polygon"):
        return c
    if t == "MultiPolygon":
        return [ring for poly in c for ring in poly]
    return []


def build_view(view: dict, layers: dict) -> dict:
    box = view["bbox"]
    lines = []
    for spec in view["layers"]:
        wanted = spec.get("names")
        for feature in layers.get(spec["layer"], []):
            name = feature["properties"].get("name") or ""
            if wanted is not None and name not in wanted:
                continue
            if feature["properties"].get("featurecla") == "Lake Centerline":
                continue  # a line drawn through a lake, not water anyone would see
            for ring in _rings(feature["geometry"]):
                ring = [tuple(p[:2]) for p in ring]
                whole = spec["kind"] == "lake" and all(_inside(p, box) for p in ring)
                for piece in ([ring] if whole else clip_line(ring, box)):
                    pts = simplify(piece, view["tolerance"])
                    if len(pts) >= 2:
                        lines.append({"kind": spec["kind"], "name": name, "closed": whole,
                                      "points": [[round(x, 4), round(y, 4)] for x, y in pts]})
    return {
        "id": view["id"],
        "bbox": {"minLon": box[0], "minLat": box[1], "maxLon": box[2], "maxLat": box[3]},
        "lines": lines,
        "places": view["places"],
        "labels": view["labels"],
        "route": view["route"],
    }


def main(argv: list[str]) -> int:
    if len(argv) != 3:
        print(__doc__)
        return 2
    src, out = Path(argv[1]), Path(argv[2])
    layers = {k: json.loads((src / f"{v}.geojson").read_text())["features"] for k, v in LAYER_FILES.items()}
    doc = {"source": SOURCE, "maps": [build_view(v, layers) for v in VIEWS]}
    out.write_text(json.dumps(doc, separators=(",", ":"), ensure_ascii=False) + "\n")
    for m in doc["maps"]:
        print(f"{m['id']}: {len(m['lines'])} lines, {sum(len(l['points']) for l in m['lines'])} points")
    print(f"wrote {out} ({out.stat().st_size} bytes)")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
