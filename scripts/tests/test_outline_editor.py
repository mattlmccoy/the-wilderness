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
    srv = make_server(content, page, port=0)
    threading.Thread(target=srv.serve_forever, daemon=True).start()
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
