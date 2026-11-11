"""Tests for scripts/make_maps.py: Natural Earth lines cut to a view and simplified."""
from __future__ import annotations

import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import make_maps as mm  # noqa: E402

BOX = (0.0, 0.0, 10.0, 10.0)


def test_line_wholly_inside_is_kept():
    assert mm.clip_line([(1, 1), (2, 2), (3, 3)], BOX) == [[(1, 1), (2, 2), (3, 3)]]


def test_line_leaving_the_view_is_split_and_keeps_one_point_past_the_edge():
    line = [(1, 1), (5, 5), (12, 5), (15, 5), (14, 6), (8, 6), (7, 7)]
    assert mm.clip_line(line, BOX) == [[(1, 1), (5, 5), (12, 5)], [(14, 6), (8, 6), (7, 7)]]


def test_line_wholly_outside_is_dropped():
    assert mm.clip_line([(20, 20), (30, 30)], BOX) == []


def test_simplify_keeps_ends_and_drops_points_within_tolerance():
    line = [(0, 0), (1, 0.001), (2, 0), (3, 2), (4, 0)]
    assert mm.simplify(line, 0.01) == [(0, 0), (2, 0), (3, 2), (4, 0)]


def test_simplify_leaves_two_point_lines_alone():
    assert mm.simplify([(0, 0), (5, 5)], 1) == [(0, 0), (5, 5)]


def _feature(name: str, geom_type: str, coords) -> dict:
    return {"properties": {"name": name}, "geometry": {"type": geom_type, "coordinates": coords}}


def test_build_view_picks_named_features_and_marks_whole_lakes_closed():
    layers = {
        "lakes": [_feature("Garda", "Polygon", [[(1, 1), (2, 1), (2, 2), (1, 1)]]),
                  _feature("Elsewhere", "Polygon", [[(50, 50), (51, 50), (51, 51), (50, 50)]])],
        "rivers": [_feature("Po", "LineString", [(0.5, 5), (5, 5), (11, 5)]),
                   _feature("Not wanted", "LineString", [(1, 1), (2, 2)])],
        "coast": [_feature("", "LineString", [(9, 0.5), (9, 9)])],
    }
    view = {"id": "t", "bbox": BOX, "tolerance": 0.0,
            "layers": [{"kind": "lake", "layer": "lakes", "names": ["Garda"]},
                       {"kind": "river", "layer": "rivers", "names": ["Po"]},
                       {"kind": "coast", "layer": "coast"}],
            "places": [{"name": "Here", "lat": 5, "lon": 5, "home": True}],
            "labels": [], "route": None}
    m = mm.build_view(view, layers)
    assert m["id"] == "t" and m["bbox"] == {"minLon": 0.0, "minLat": 0.0, "maxLon": 10.0, "maxLat": 10.0}
    kinds = [(l["kind"], l["closed"]) for l in m["lines"]]
    assert kinds == [("lake", True), ("river", False), ("coast", False)]
    assert m["lines"][1]["points"] == [[0.5, 5], [5, 5], [11, 5]]
    assert m["places"] == [{"name": "Here", "lat": 5, "lon": 5, "home": True}]


def test_points_are_rounded_to_four_places():
    layers = {"coast": [_feature("", "LineString", [(1.123456, 2.987654), (3, 3)])]}
    view = {"id": "t", "bbox": BOX, "tolerance": 0.0, "layers": [{"kind": "coast", "layer": "coast"}],
            "places": [], "labels": [], "route": None}
    assert mm.build_view(view, layers)["lines"][0]["points"][0] == [1.1235, 2.9877]


# The shipped file, built from the real downloads (data-contract: check reality, not belief).
MAPS = Path(__file__).resolve().parent.parent.parent / "App/Content/maps.json"


@pytest.mark.skipif(not MAPS.exists(), reason="maps.json not generated yet")
def test_shipped_maps_hold_the_real_water_and_places():
    doc = json.loads(MAPS.read_text())
    maps = {m["id"]: m for m in doc["maps"]}
    assert set(maps) == {"lombardy", "judea", "mediterranean"}
    assert "public domain" in doc["source"].lower()
    lom = maps["lombardy"]
    assert {l["name"] for l in lom["lines"]} >= {"Lago di Garda", "Po"}
    assert [p["name"] for p in lom["places"] if p["home"]] == ["Brescia"]
    jud = maps["judea"]
    assert {l["name"] for l in jud["lines"]} >= {"Dead Sea", "Jordan"}
    assert any(p["name"] == "Jerusalem" for p in jud["places"])
    med = maps["mediterranean"]
    assert med["route"] == ["Brescia", "Jerusalem"]
    assert sum(len(l["points"]) for l in med["lines"]) > 300
    for m in doc["maps"]:
        b = m["bbox"]
        for p in m["places"]:
            assert b["minLon"] <= p["lon"] <= b["maxLon"] and b["minLat"] <= p["lat"] <= b["maxLat"], p
    assert MAPS.stat().st_size < 400_000


def test_lake_centerlines_are_not_drawn_as_rivers():
    river = _feature("Jordan", "LineString", [(1, 1), (2, 2)])
    centre = _feature("Jordan", "LineString", [(3, 3), (4, 4)])
    river["properties"]["featurecla"] = "River"
    centre["properties"]["featurecla"] = "Lake Centerline"
    view = {"id": "t", "bbox": BOX, "tolerance": 0.0,
            "layers": [{"kind": "river", "layer": "rivers", "names": ["Jordan"]}],
            "places": [], "labels": [], "route": None}
    lines = mm.build_view(view, {"rivers": [river, centre]})["lines"]
    assert [l["points"] for l in lines] == [[[1, 1], [2, 2]]]
