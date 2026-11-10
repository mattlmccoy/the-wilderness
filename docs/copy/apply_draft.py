#!/usr/bin/env python3
"""Copy wall text from docs/copy/draft.json into the app's content files.

Usage: python3 -I docs/copy/apply_draft.py
Changes only title, short and more (story + verses) in App/Content/annotations.json
and App/Content/unfold.json, matched by id (subjects by annotation id, beats in order).
Geometry, timing, light and text side are left alone.
"""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
draft = json.loads((ROOT / "docs/copy/draft.json").read_text())


def text_fields(item: dict) -> dict:
    m = dict(item["more"])
    return {"title": item["title"], "short": item["short"], "more": m}


ann_path = ROOT / "App/Content/annotations.json"
ann = json.loads(ann_path.read_text())
by_id = {s["id"]: s for s in draft["subjects"]}
for a in ann["annotations"]:
    if a["id"] not in by_id:
        raise SystemExit(f"draft has no subject {a['id']}")
    a.update(text_fields(by_id[a["id"]]))
ann_path.write_text(json.dumps(ann, indent=2, ensure_ascii=False) + "\n")

unf_path = ROOT / "App/Content/unfold.json"
unf = json.loads(unf_path.read_text())
if len(unf["beats"]) != len(draft["beats"]):
    raise SystemExit("draft and unfold.json have different numbers of beats")
for beat, d in zip(unf["beats"], draft["beats"]):
    beat.update(text_fields(d))
    beat["draft"] = d["more"]["draft"]
unf_path.write_text(json.dumps(unf, indent=2, ensure_ascii=False) + "\n")
print(f"applied {draft['draft']}: {len(ann['annotations'])} subjects, {len(unf['beats'])} beats")
