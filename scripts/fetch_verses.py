#!/usr/bin/env python3
"""Fetch the licensed wording (NIV, NLT) for every verse on the wall from API.Bible.

Run nightly by refresh.sh before each build, or by hand from the Wilderness folder:
    python3 -I scripts/fetch_verses.py          # fetch, print a summary (no verse text)
    python3 -I scripts/fetch_verses.py --show   # print what each verse now says

For each verse still written against the free BSB placeholder, it downloads the verse in the
chosen translation and keeps the clause that matches the wall's excerpt (see verse_align.py).
The result goes to App/Content/licensed-verses.json, which git ignores, and each publisher's
copyright line goes to App/Content/notices.json (shown under Settings → About).

Choices live in scripts/verse-choices.json:
    {"default": "NIV", "verses": {"Psalm 91:11": {"translation": "NLT"}, "Genesis 2:9": {"full": true}}}

API.Bible requires cached text to be refreshed at least every 30 days. If a fetch fails, the
previous verses are kept while they are under 30 days old, then dropped back to the placeholder.
Needs in scripts/refresh.conf: APIBIBLE_KEY, NIV_BIBLE_ID, NLT_BIBLE_ID.
"""
from __future__ import annotations

import json
import subprocess
import sys
from datetime import date
from pathlib import Path
from typing import Callable, Dict

# `python3 -I` leaves this folder off the import path.
sys.path.insert(0, str(Path(__file__).resolve().parent))
from verse_align import CONFIDENT, align, normalize  # noqa: E402

MAX_AGE_DAYS = 30
API = "https://rest.api.bible/v1/bibles/{bible}/passages/{pid}?content-type=text&include-notes=false" \
      "&include-titles=false&include-chapter-numbers=false&include-verse-numbers=false&include-verse-spans=false"
BOOKS = {"Genesis": "GEN", "Exodus": "EXO", "Deuteronomy": "DEU", "Psalm": "PSA", "Psalms": "PSA",
         "Isaiah": "ISA", "Daniel": "DAN", "Matthew": "MAT", "Mark": "MRK", "Luke": "LUK", "John": "JHN",
         "Romans": "ROM", "Galatians": "GAL", "Lamentations": "LAM", "Philippians": "PHP", "Hebrews": "HEB", "1 Peter": "1PE", "Revelation": "REV"}

Fetch = Callable[[str, str], Dict]


class FetchError(Exception):
    """A verse could not be fetched (network, auth, or an unexpected response)."""


def passage_id(ref: str) -> str:
    """'1 Peter 2:24' -> '1PE.2.24' (API.Bible / USFM book codes)."""
    book, cv = ref.rsplit(" ", 1)
    if book not in BOOKS:
        raise ValueError(f"no API.Bible book code for {book!r}")
    chapter, verse = cv.split(":")
    return f"{BOOKS[book]}.{chapter}.{verse}"


def wall_excerpts(content: Path) -> dict[str, str]:
    """Every verse on the wall still written against the BSB placeholder: ref -> excerpt.
    Includes the prayer lines in prayer.json."""
    items = json.loads((content / "annotations.json").read_text())["annotations"] + \
        json.loads((content / "unfold.json").read_text())["beats"]
    out: dict[str, str] = {}
    for item in items:
        for v in (item.get("more") or {}).get("verses", []):
            if v["translation"] == "BSB":
                out.setdefault(v["ref"], v["text"])
    # Into the Quiet: the morning and evening prayer lines (BSB clauses).
    prayer = content / "prayer.json"
    if prayer.exists():
        data = json.loads(prayer.read_text())
        for line in data.get("morning", []) + data.get("evening", []):
            out.setdefault(line["ref"], line["text"])
    return out


def _write(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + "\n")


def _fetch_all(excerpts, sources, choices, bible_ids, fetch):
    verses, notices, unsure = [], {}, []
    for ref, excerpt in excerpts.items():
        pick = choices.get("verses", {}).get(ref, {})
        tr = pick.get("translation", choices.get("default", "NIV"))
        if tr not in bible_ids:
            raise FetchError(f"{tr} Bible ID not set")
        data = fetch(bible_ids[tr], passage_id(ref))
        whole = normalize(data.get("content") or "")
        if not whole:
            raise FetchError(f"empty response for {ref}")
        if pick.get("full"):
            text, match = whole, "full"
        else:
            text, score = align(excerpt, sources[ref]["BSB"], whole)
            match = "clause" if score >= CONFIDENT else "whole-unsure"
            if match == "whole-unsure":
                text = whole
                unsure.append(ref)
        verses.append({"ref": ref, "translation": tr, "text": text, "match": match})
        notices[tr] = normalize(data.get("copyright") or "")
    return verses, notices, unsure


def refresh(content: Path, sources_path: Path, choices: dict, bible_ids: dict[str, str],
            fetch: Fetch, today: date) -> str:
    """Fetch and save the licensed verses. Returns a summary that never contains verse text."""
    lic_path = content / "licensed-verses.json"
    excerpts = wall_excerpts(content)
    try:
        if not bible_ids:
            raise FetchError("API.Bible key or Bible IDs not set in scripts/refresh.conf")
        sources = json.loads(sources_path.read_text())
        verses, used, unsure = _fetch_all(excerpts, sources, choices, bible_ids, fetch)
    except FetchError as e:
        return _keep_or_drop(lic_path, today, str(e))
    _write(lic_path, {"fetchedAt": today.isoformat(), "verses": verses})
    not_path = content / "notices.json"
    notices = json.loads(not_path.read_text())
    notices["notices"].update({tr: n for tr, n in used.items() if n})
    _write(not_path, notices)
    counts = {}
    for v in verses:
        counts[v["translation"]] = counts.get(v["translation"], 0) + 1
    summary = ", ".join(f"{n} {tr}" for tr, n in sorted(counts.items()))
    line = f"OK: {len(verses)} verses fetched ({summary})."
    if unsure:
        line += f" Shown whole because the clause match was unsure: {', '.join(unsure)}."
    return line


def _keep_or_drop(lic_path: Path, today: date, why: str) -> str:
    previous = json.loads(lic_path.read_text()) if lic_path.exists() else {"verses": []}
    fetched = previous.get("fetchedAt")
    age = (today - date.fromisoformat(fetched)).days if fetched else None
    if previous.get("verses") and age is not None and age < MAX_AGE_DAYS:
        return f"WARN: verse fetch failed ({why}); kept verses from {fetched} ({age} days old)."
    _write(lic_path, {"verses": []})
    if previous.get("verses"):
        return f"WARN: verse fetch failed ({why}); verses were over 30 days old, so the placeholders show."
    return f"WARN: verse fetch failed ({why}); placeholders show."


def curl_fetch(key: str) -> Fetch:
    """Real API.Bible request. curl reads the key from stdin, so it never appears in `ps`."""
    def fetch(bible_id: str, pid: str) -> dict:
        config = f'header = "api-key: {key}"\nurl = "{API.format(bible=bible_id, pid=pid)}"\n' \
                 'silent\nshow-error\nfail\nmax-time = 30\n'
        r = subprocess.run(["curl", "-K", "-"], input=config, capture_output=True, text=True)
        if r.returncode != 0:
            raise FetchError(f"{pid}: {r.stderr.strip() or 'curl failed'}")
        try:
            return json.loads(r.stdout)["data"]
        except (json.JSONDecodeError, KeyError) as e:
            raise FetchError(f"{pid}: unexpected response ({type(e).__name__})") from e
    return fetch


def _read_conf(path: Path) -> dict[str, str]:
    conf = {}
    if path.exists():
        for line in path.read_text().splitlines():
            if "=" in line and not line.lstrip().startswith("#"):
                k, v = line.split("=", 1)
                conf[k.strip()] = v.strip().strip('"')
    return conf


def main(argv: list[str]) -> int:
    root = Path(__file__).resolve().parent.parent
    content = root / "App/Content"
    if "--show" in argv:
        data = json.loads((content / "licensed-verses.json").read_text())
        for v in data.get("verses", []):
            print(f"{v['ref']} ({v['translation']}, {v['match']}): {v['text']}")
        return 0
    conf = _read_conf(root / "scripts/refresh.conf")
    ids = {tr: conf[f"{tr}_BIBLE_ID"] for tr in ("NIV", "NLT") if conf.get(f"{tr}_BIBLE_ID")}
    key = conf.get("APIBIBLE_KEY", "")
    choices = json.loads((root / "scripts/verse-choices.json").read_text())
    report = refresh(content, root / "docs/copy/verse-sources.json", choices,
                     ids if key else {}, curl_fetch(key), date.today())
    print(report)
    return 0 if report.startswith("OK") else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
