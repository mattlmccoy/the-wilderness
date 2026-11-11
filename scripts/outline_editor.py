#!/usr/bin/env python3
"""Trace each figure's outline on the painting, mark new regions, and leave notes, in a browser.

Run from the Wilderness folder:
    python3 -I scripts/outline_editor.py        # then open http://127.0.0.1:8765

The page (scripts/outline_editor.html) shows App/Content/painting.jpg with every figure's
outline (gold) and every region you have added (teal, dashed).

Figures: pick one, drag its points, click an edge to add one, Option-click a point to remove
it, then Save. Save checks the shape and writes only that figure's "outline" (and marks its
"geometrySource" as traced) in App/Content/annotations.json; everything else is unchanged.
A figure also has a notes box; its notes are saved to notes/regions.json, never to
annotations.json.

New regions: press "New region", click points around the area (click the first point or
press Return to close), give it a name and notes, then Save. Edit its points the same way as
a figure's. "Delete region" removes it. Regions and all notes live only in
notes/regions.json at the repo root:

    {"regions": [{"id": "olive-tree", "name": "Olive tree", "notes": "...",
                  "outline": [{"x": 0.6, "y": 0.6}, ...], "kind": "new"},
                 {"id": "lion", "name": "Lion", "notes": "...", "kind": "figure"}]}

That file is for the developer to read and write content from. It sits outside App/, so the
app never bundles it. Points are fractions 0..1 of the painting, the same as the app uses.
"""
from __future__ import annotations

import copy
import json
import re
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from typing import Optional

TRACED = "traced-by-matt"
PORT = 8765
MAX_NOTES = 4000


def clean_points(points: list) -> list[dict]:
    """Check an outline (at least 3 points, numeric x/y on the painting) and round it to 4 dp."""
    if not isinstance(points, list) or len(points) < 3:
        raise ValueError("an outline needs at least 3 points")
    clean = []
    for p in points:
        if not isinstance(p, dict) or not all(isinstance(p.get(k), (int, float)) for k in ("x", "y")):
            raise ValueError("every point needs numeric x and y")
        if not (0 <= p["x"] <= 1 and 0 <= p["y"] <= 1):
            raise ValueError("points must lie on the painting (0 to 1)")
        clean.append({"x": round(p["x"], 4), "y": round(p["y"], 4)})
    return clean


def apply_outline(doc: dict, subject_id: str, points: list) -> dict:
    """Return a copy of the annotations document with one figure's outline replaced."""
    clean = clean_points(points)
    out = copy.deepcopy(doc)
    for a in out["annotations"]:
        if a["id"] == subject_id:
            a["outline"] = clean
            a["geometrySource"] = TRACED
            return out
    raise ValueError(f"no subject called {subject_id!r}")


def _clean_notes(text) -> str:
    if not isinstance(text, str):
        raise ValueError("notes must be text")
    if len(text) > MAX_NOTES:
        raise ValueError(f"notes are limited to {MAX_NOTES} characters")
    return text


def _slug(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-") or "region"


def upsert_region(notes_doc: dict, annotations_doc: dict, payload: dict) -> dict:
    """Return a copy of the notes document with one of Matt's own regions added or updated.

    Without an "id" the region is new and gets a slug of its name, made unique against the
    other regions and every figure id. With an "id" it must name an existing new region.
    """
    name = payload.get("name")
    if not isinstance(name, str) or not name.strip():
        raise ValueError("a region needs a name")
    region = {"id": payload.get("id"), "name": name.strip(), "notes": _clean_notes(payload.get("notes", "")),
              "outline": clean_points(payload.get("points")), "kind": "new"}
    out = copy.deepcopy(notes_doc)
    regions = out.setdefault("regions", [])
    if region["id"] is not None:
        for i, r in enumerate(regions):
            if r.get("id") == region["id"] and r.get("kind") == "new":
                regions[i] = region
                return out
        raise ValueError(f"no region called {region['id']!r}")
    taken = {r.get("id") for r in regions} | {a["id"] for a in annotations_doc["annotations"]}
    base = slug = _slug(region["name"])
    n = 2
    while slug in taken:
        slug, n = f"{base}-{n}", n + 1
    region["id"] = slug
    regions.append(region)
    return out


def delete_region(notes_doc: dict, region_id: str) -> dict:
    """Return a copy of the notes document without one of Matt's own (kind "new") regions."""
    out = copy.deepcopy(notes_doc)
    keep = [r for r in out.get("regions", []) if not (r.get("id") == region_id and r.get("kind") == "new")]
    if len(keep) == len(out.get("regions", [])):
        raise ValueError(f"no region called {region_id!r}")
    out["regions"] = keep
    return out


def set_figure_notes(notes_doc: dict, annotations_doc: dict, figure_id: str, text) -> dict:
    """Return a copy of the notes document with notes attached to an existing figure.

    The figure's outline stays in annotations.json; blank notes remove the entry.
    """
    text = _clean_notes(text)
    titles = {a["id"]: a["title"] for a in annotations_doc["annotations"]}
    if figure_id not in titles:
        raise ValueError(f"no figure called {figure_id!r}")
    out = copy.deepcopy(notes_doc)
    regions = [r for r in out.get("regions", []) if not (r.get("id") == figure_id and r.get("kind") == "figure")]
    if text.strip():
        entry = {"id": figure_id, "name": titles[figure_id], "notes": text, "kind": "figure"}
        old = [i for i, r in enumerate(out.get("regions", [])) if r.get("id") == figure_id and r.get("kind") == "figure"]
        regions.insert(old[0] if old else len(regions), entry)
    out["regions"] = regions
    return out


def read_notes(path: Path) -> dict:
    """The notes document, or an empty one if nothing has been saved yet."""
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else {"regions": []}


def write_notes(path: Path, notes_doc: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(notes_doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def subjects(doc: dict) -> list[dict]:
    return [{"id": a["id"], "title": a["title"], "outline": a.get("outline") or [],
             "source": a.get("geometrySource", "")} for a in doc["annotations"]]


def make_server(content: Path, page: Path, port: int = PORT,
                notes: Optional[Path] = None) -> ThreadingHTTPServer:
    """Serve the tracer. Outlines go to content/annotations.json; region notes go to `notes`
    (default: notes/regions.json beside App/, outside anything the app bundles)."""
    ann_path = content / "annotations.json"
    notes_path = notes if notes is not None else content.parent.parent / "notes" / "regions.json"

    class Handler(BaseHTTPRequestHandler):
        def log_message(self, *args):  # keep the terminal quiet
            pass

        def _send(self, status: int, body: bytes, kind: str) -> None:
            self.send_response(status)
            self.send_header("Content-Type", kind)
            self.send_header("Content-Length", str(len(body)))
            self.send_header("Cache-Control", "no-store")
            self.end_headers()
            self.wfile.write(body)

        def _json(self, status: int, data) -> None:
            self._send(status, json.dumps(data).encode(), "application/json")

        def do_GET(self):
            if self.path in ("/", "/index.html"):
                self._send(200, page.read_bytes(), "text/html; charset=utf-8")
            elif self.path == "/painting.jpg":
                self._send(200, (content / "painting.jpg").read_bytes(), "image/jpeg")
            elif self.path == "/subjects":
                self._json(200, subjects(json.loads(ann_path.read_text())))
            elif self.path == "/regions":
                self._json(200, read_notes(notes_path))
            else:
                self._json(404, {"error": "not found"})

        def do_POST(self):
            if self.path not in ("/outline", "/region", "/region/delete", "/figure-notes"):
                return self._json(404, {"error": "not found"})
            try:
                body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
                if not isinstance(body, dict):
                    raise ValueError("send a JSON object")
                if self.path == "/outline":
                    doc = apply_outline(json.loads(ann_path.read_text()), body.get("id"), body.get("points"))
                    ann_path.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n")
                    return self._json(200, {"saved": body["id"], "points": len(body["points"])})
                ann = json.loads(ann_path.read_text())
                notes_doc = read_notes(notes_path)
                if self.path == "/region":
                    out = upsert_region(notes_doc, ann, body)
                    reply = {"saved": out["regions"][-1]["id"] if body.get("id") is None else body["id"]}
                elif self.path == "/region/delete":
                    out = delete_region(notes_doc, body.get("id"))
                    reply = {"deleted": body["id"]}
                else:
                    out = set_figure_notes(notes_doc, ann, body.get("id"), body.get("notes", ""))
                    reply = {"saved": body["id"]}
            except (ValueError, json.JSONDecodeError) as e:
                return self._json(400, {"error": str(e)})
            write_notes(notes_path, out)
            self._json(200, reply)

    return ThreadingHTTPServer(("127.0.0.1", port), Handler)


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    srv = make_server(root / "App/Content", root / "scripts/outline_editor.html",
                      notes=root / "notes" / "regions.json")
    print(f"Outline editor: http://127.0.0.1:{srv.server_address[1]}  (Ctrl-C to stop)")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
