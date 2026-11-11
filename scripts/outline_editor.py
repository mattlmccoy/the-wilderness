#!/usr/bin/env python3
"""Trace each figure's outline on the painting, in a browser, and save it into the app.

Run from the Wilderness folder:
    python3 -I scripts/outline_editor.py        # then open http://127.0.0.1:8765

The page (scripts/outline_editor.html) shows App/Content/painting.jpg with every figure's
outline. Pick a figure, drag its points, click an edge to add one, Option-click a point to
remove it, then Save. Save checks the shape and writes only that figure's "outline" (and marks
its "geometrySource" as traced) in App/Content/annotations.json; everything else is unchanged.
Points are fractions 0..1 of the painting, the same as the app uses.
"""
from __future__ import annotations

import copy
import json
import sys
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

TRACED = "traced-by-matt"
PORT = 8765


def apply_outline(doc: dict, subject_id: str, points: list) -> dict:
    """Return a copy of the annotations document with one figure's outline replaced."""
    if not isinstance(points, list) or len(points) < 3:
        raise ValueError("an outline needs at least 3 points")
    clean = []
    for p in points:
        if not isinstance(p, dict) or not all(isinstance(p.get(k), (int, float)) for k in ("x", "y")):
            raise ValueError("every point needs numeric x and y")
        if not (0 <= p["x"] <= 1 and 0 <= p["y"] <= 1):
            raise ValueError("points must lie on the painting (0 to 1)")
        clean.append({"x": round(p["x"], 4), "y": round(p["y"], 4)})
    out = copy.deepcopy(doc)
    for a in out["annotations"]:
        if a["id"] == subject_id:
            a["outline"] = clean
            a["geometrySource"] = TRACED
            return out
    raise ValueError(f"no subject called {subject_id!r}")


def subjects(doc: dict) -> list[dict]:
    return [{"id": a["id"], "title": a["title"], "outline": a.get("outline") or [],
             "source": a.get("geometrySource", "")} for a in doc["annotations"]]


def make_server(content: Path, page: Path, port: int = PORT) -> ThreadingHTTPServer:
    ann_path = content / "annotations.json"

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
            else:
                self._json(404, {"error": "not found"})

        def do_POST(self):
            if self.path != "/outline":
                return self._json(404, {"error": "not found"})
            try:
                body = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
                doc = apply_outline(json.loads(ann_path.read_text()), body.get("id"), body.get("points"))
            except (ValueError, json.JSONDecodeError) as e:
                return self._json(400, {"error": str(e)})
            ann_path.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n")
            self._json(200, {"saved": body["id"], "points": len(body["points"])})

    return ThreadingHTTPServer(("127.0.0.1", port), Handler)


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    srv = make_server(root / "App/Content", root / "scripts/outline_editor.html")
    print(f"Outline editor: http://127.0.0.1:{srv.server_address[1]}  (Ctrl-C to stop)")
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
