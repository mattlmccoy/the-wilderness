"""Tests for the outline tracing tool: saving an outline into annotations.json, and the local
server round trip. Fixture shape copied from the real App/Content/annotations.json (probed
2026-11-10: outline is a list of {"x","y"} in 0..1, geometrySource "met-reference-estimate")."""
import json
import sys
import threading
import urllib.request
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from outline_editor import TRACED, apply_outline, make_server, subjects  # noqa: E402

TRI = [{"x": 0.1, "y": 0.1}, {"x": 0.2, "y": 0.1}, {"x": 0.15, "y": 0.2}]


def doc():
    a = lambda i: {"id": i, "title": i.title(), "short": "s", "extended": "", "references": [],
                   "evidence": "documented", "anchor": {"x": 0.5, "y": 0.5}, "outline": TRI,
                   "textSide": "left", "geometrySource": "met-reference-estimate", "more": None}
    return {"artworkAspect": 1.2, "annotations": [a("christ"), a("lion")]}


def test_saving_replaces_only_that_outline_and_marks_it_traced():
    before = doc()
    new = [{"x": 0.123456, "y": 0.5}, {"x": 0.9, "y": 0.5}, {"x": 0.5, "y": 0.987654}]
    after = apply_outline(before, "lion", new)
    lion = after["annotations"][1]
    assert lion["outline"] == [{"x": 0.1235, "y": 0.5}, {"x": 0.9, "y": 0.5}, {"x": 0.5, "y": 0.9877}]
    assert lion["geometrySource"] == TRACED
    assert after["annotations"][0] == before["annotations"][0]
    assert {k: v for k, v in lion.items() if k not in ("outline", "geometrySource")} == \
        {k: v for k, v in before["annotations"][1].items() if k not in ("outline", "geometrySource")}
    assert before["annotations"][1]["outline"] == TRI   # input not mutated


@pytest.mark.parametrize("points, why", [
    (TRI[:2], "3"),
    ([{"x": 0.1, "y": 0.1}, {"x": 1.2, "y": 0.1}, {"x": 0.1, "y": 0.2}], "0"),
    ([{"x": 0.1}, {"x": 0.2, "y": 0.1}, {"x": 0.1, "y": 0.2}], "x and y"),
])
def test_bad_outlines_are_refused_with_a_reason(points, why):
    with pytest.raises(ValueError, match=why):
        apply_outline(doc(), "lion", points)


def test_unknown_subject_is_refused():
    with pytest.raises(ValueError, match="no subject"):
        apply_outline(doc(), "unicorn", TRI)


def test_subjects_lists_what_the_page_needs():
    assert subjects(doc())[1] == {"id": "lion", "title": "Lion", "outline": TRI,
                                  "source": "met-reference-estimate"}


@pytest.fixture
def server(tmp_path):
    content = tmp_path / "Content"; content.mkdir()
    (content / "annotations.json").write_text(json.dumps(doc()))
    (content / "painting.jpg").write_bytes(b"\xff\xd8fake")
    page = tmp_path / "page.html"; page.write_text("<html>tool</html>")
    srv = make_server(content, page, port=0, notes=tmp_path / "notes" / "regions.json")
    threading.Thread(target=srv.serve_forever, kwargs={"poll_interval": 0.05}, daemon=True).start()
    yield f"http://127.0.0.1:{srv.server_address[1]}", content
    srv.shutdown()


def get(url):
    with urllib.request.urlopen(url) as r:
        return r.status, r.read()


def post(url, body):
    req = urllib.request.Request(url, data=json.dumps(body).encode(), method="POST",
                                 headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, json.loads(r.read())
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read())


def test_server_serves_page_painting_and_subjects(server):
    base, _ = server
    assert get(base + "/") == (200, b"<html>tool</html>")
    assert get(base + "/painting.jpg") == (200, b"\xff\xd8fake")
    status, body = get(base + "/subjects")
    assert status == 200 and [s["id"] for s in json.loads(body)] == ["christ", "lion"]


def test_server_save_writes_the_file(server):
    base, content = server
    new = [{"x": 0.3, "y": 0.3}, {"x": 0.4, "y": 0.3}, {"x": 0.35, "y": 0.4}, {"x": 0.3, "y": 0.4}]
    status, body = post(base + "/outline", {"id": "christ", "points": new})
    assert status == 200 and body["saved"] == "christ" and body["points"] == 4
    saved = json.loads((content / "annotations.json").read_text())
    assert saved["annotations"][0]["outline"] == new
    assert saved["annotations"][0]["geometrySource"] == TRACED


def test_server_refuses_a_bad_save_and_leaves_the_file_alone(server):
    base, content = server
    before = (content / "annotations.json").read_text()
    status, body = post(base + "/outline", {"id": "christ", "points": TRI[:2]})
    assert status == 400 and "3" in body["error"]
    assert (content / "annotations.json").read_text() == before


# --- Matt's own regions and notes (notes/regions.json; never shipped, never in annotations.json)
import outline_editor as oe  # noqa: E402

SQUARE = [{"x": 0.6, "y": 0.6}, {"x": 0.7, "y": 0.6}, {"x": 0.7, "y": 0.7}, {"x": 0.6, "y": 0.7}]


def notes_doc():
    return {"regions": []}


def test_new_region_gets_a_slug_id_and_rounded_points():
    out = oe.upsert_region(notes_doc(), doc(), {"name": "Olive Tree!", "notes": "glow at dusk",
                                                "points": [{"x": 0.123456, "y": 0.5}] + SQUARE[1:]})
    assert out["regions"] == [{"id": "olive-tree", "name": "Olive Tree!", "notes": "glow at dusk",
                               "outline": [{"x": 0.1235, "y": 0.5}] + SQUARE[1:], "kind": "new"}]


def test_new_region_ids_are_unique_and_never_shadow_a_figure():
    first = oe.upsert_region(notes_doc(), doc(), {"name": "Olive tree", "notes": "", "points": SQUARE})
    second = oe.upsert_region(first, doc(), {"name": "olive  TREE", "notes": "", "points": SQUARE})
    assert [r["id"] for r in second["regions"]] == ["olive-tree", "olive-tree-2"]
    lion = oe.upsert_region(notes_doc(), doc(), {"name": "Lion", "notes": "", "points": SQUARE})
    assert lion["regions"][0]["id"] == "lion-2"
    odd = oe.upsert_region(notes_doc(), doc(), {"name": "★★", "notes": "", "points": SQUARE})
    assert odd["regions"][0]["id"] == "region"


def test_saving_with_an_id_updates_that_region_in_place():
    made = oe.upsert_region(notes_doc(), doc(), {"name": "Rock", "notes": "a", "points": SQUARE})
    again = oe.upsert_region(made, doc(), {"id": "rock", "name": "Big rock", "notes": "b", "points": TRI})
    assert again["regions"] == [{"id": "rock", "name": "Big rock", "notes": "b", "outline": TRI, "kind": "new"}]
    assert made["regions"][0]["name"] == "Rock"   # input not mutated


@pytest.mark.parametrize("payload, why", [
    ({"name": "  ", "notes": "", "points": SQUARE}, "name"),
    ({"name": "Rock", "notes": "", "points": TRI[:2]}, "3"),
    ({"name": "Rock", "notes": "", "points": [{"x": -0.1, "y": 0}] + TRI[1:]}, "0"),
    ({"name": "Rock", "notes": "x" * 4001, "points": SQUARE}, "4000"),
    ({"name": "Rock", "notes": 7, "points": SQUARE}, "notes"),
    ({"id": "nope", "name": "Rock", "notes": "", "points": SQUARE}, "no region"),
])
def test_bad_regions_are_refused_with_a_reason(payload, why):
    with pytest.raises(ValueError, match=why):
        oe.upsert_region(notes_doc(), doc(), payload)


def test_deleting_removes_only_that_new_region():
    made = oe.upsert_region(notes_doc(), doc(), {"name": "Rock", "notes": "", "points": SQUARE})
    made = oe.upsert_region(made, doc(), {"name": "Cloud", "notes": "", "points": SQUARE})
    out = oe.delete_region(made, "rock")
    assert [r["id"] for r in out["regions"]] == ["cloud"]
    assert len(made["regions"]) == 2   # input not mutated


def test_deleting_an_unknown_region_or_a_figure_is_refused():
    with pytest.raises(ValueError, match="no region"):
        oe.delete_region(notes_doc(), "rock")
    noted = oe.set_figure_notes(notes_doc(), doc(), "lion", "roar")
    with pytest.raises(ValueError, match="no region"):
        oe.delete_region(noted, "lion")


def test_figure_notes_attach_to_an_existing_figure_without_an_outline():
    out = oe.set_figure_notes(notes_doc(), doc(), "lion", "mane catches the light")
    assert out["regions"] == [{"id": "lion", "name": "Lion", "notes": "mane catches the light", "kind": "figure"}]
    again = oe.set_figure_notes(out, doc(), "lion", "changed")
    assert again["regions"] == [{"id": "lion", "name": "Lion", "notes": "changed", "kind": "figure"}]
    assert out["regions"][0]["notes"] == "mane catches the light"   # input not mutated


def test_clearing_figure_notes_drops_the_entry():
    out = oe.set_figure_notes(notes_doc(), doc(), "lion", "roar")
    assert oe.set_figure_notes(out, doc(), "lion", "   ")["regions"] == []


@pytest.mark.parametrize("fid, text, why", [
    ("unicorn", "hi", "no figure"),
    ("lion", "x" * 4001, "4000"),
    ("lion", None, "notes"),
])
def test_bad_figure_notes_are_refused(fid, text, why):
    with pytest.raises(ValueError, match=why):
        oe.set_figure_notes(notes_doc(), doc(), fid, text)


def test_regions_are_empty_until_something_is_saved(server, tmp_path):
    base, _ = server
    assert not (tmp_path / "notes" / "regions.json").exists()
    status, body = get(base + "/regions")
    assert status == 200 and json.loads(body) == {"regions": []}


def test_notes_endpoints_write_only_the_notes_file(server, tmp_path):
    base, content = server
    notes = tmp_path / "notes" / "regions.json"
    ann_before = (content / "annotations.json").read_bytes()

    status, body = post(base + "/region", {"name": "Olive tree", "notes": "warm glow — ‘dusk’", "points": SQUARE})
    assert status == 200 and body["saved"] == "olive-tree"
    status, body = post(base + "/figure-notes", {"id": "lion", "notes": "mane"})
    assert status == 200 and body["saved"] == "lion"
    status, body = post(base + "/region", {"id": "olive-tree", "name": "Olive", "notes": "", "points": TRI})
    assert status == 200 and body["saved"] == "olive-tree"

    text = notes.read_text(encoding="utf-8")
    assert text.endswith("}\n") and "\n  \"regions\"" in text   # pretty, trailing newline
    saved = json.loads(text)
    assert [(r["id"], r["kind"]) for r in saved["regions"]] == [("olive-tree", "new"), ("lion", "figure")]
    assert saved["regions"][0]["outline"] == TRI
    status, body = get(base + "/regions")
    assert json.loads(body) == saved

    status, body = post(base + "/region/delete", {"id": "olive-tree"})
    assert status == 200 and body["deleted"] == "olive-tree"
    assert [r["id"] for r in json.loads(notes.read_text())["regions"]] == ["lion"]
    assert (content / "annotations.json").read_bytes() == ann_before


def test_notes_text_is_written_as_readable_unicode(server, tmp_path):
    base, _ = server
    post(base + "/figure-notes", {"id": "lion", "notes": "‘dusk’ — glow"})
    assert "‘dusk’ — glow" in (tmp_path / "notes" / "regions.json").read_text(encoding="utf-8")


@pytest.mark.parametrize("path, body, why", [
    ("/region", {"name": "", "notes": "", "points": SQUARE}, "name"),
    ("/region", {"name": "Rock", "notes": "", "points": TRI[:2]}, "3"),
    ("/region/delete", {"id": "nope"}, "no region"),
    ("/figure-notes", {"id": "unicorn", "notes": "hi"}, "no figure"),
    ("/figure-notes", ["not", "an", "object"], "object"),
])
def test_bad_notes_requests_are_refused_and_write_nothing(server, tmp_path, path, body, why):
    base, content = server
    ann_before = (content / "annotations.json").read_bytes()
    status, reply = post(base + path, body)
    assert status == 400 and why in reply["error"]
    assert not (tmp_path / "notes" / "regions.json").exists()
    assert (content / "annotations.json").read_bytes() == ann_before
