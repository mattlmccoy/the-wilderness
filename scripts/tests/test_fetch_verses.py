"""Tests for the nightly licensed-verse fetch. A fake API serves public-domain stand-ins
(fixtures/standin_verses.json), so no licensed text or network is involved."""
import json
import sys
from datetime import date
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from fetch_verses import FetchError, passage_id, refresh, wall_excerpts  # noqa: E402
from verse_align import align, normalize  # noqa: E402

FIX = json.loads((Path(__file__).parent / "fixtures/standin_verses.json").read_text())
IDS = {"NIV": "niv-id", "NLT": "nlt-id"}
# Copyright lines as API.Bible returns them in data.copyright (probed 2026-11-10).
COPYRIGHT = {"niv-id": "NIV notice", "nlt-id": "NLT notice"}
TODAY = date(2026, 11, 10)


def verse(ref, tr="BSB"):
    return {"ref": ref, "text": FIX[ref]["excerpt"] if tr == "BSB" else "Douay text",
            "translation": tr, "testament": "old", "connection": "inScripture"}


@pytest.fixture
def content(tmp_path):
    c = tmp_path / "Content"; c.mkdir()
    (c / "annotations.json").write_text(json.dumps({"annotations": [
        {"id": "jesus", "more": {"verses": [verse("Genesis 3:15"), verse("Psalm 91:11")]}},
        {"id": "basilisk", "more": {"verses": [verse("Psalm 90:13", "DRA")]}},
        {"id": "plain"}]}))
    (c / "unfold.json").write_text(json.dumps({"beats": [
        {"id": "b1", "more": {"verses": [verse("Genesis 2:9"), verse("Genesis 3:15")]}}]}))
    (c / "notices.json").write_text(json.dumps({"notices": {"DRA": "keep me"}}))
    return c


@pytest.fixture
def sources(tmp_path):
    p = tmp_path / "verse-sources.json"
    p.write_text(json.dumps({r: {"BSB": FIX[r]["BSB"]} for r in FIX}))
    return p


def fake_api(standin="ENGWEBP", calls=None, fail=False):
    def fetch(bible_id, pid):
        if calls is not None:
            calls.append((bible_id, pid))
        if fail:
            raise FetchError("network down")
        ref = next(r for r in FIX if passage_id(r) == pid)
        return {"content": "\n  " + FIX[ref][standin] + " ", "copyright": COPYRIGHT[bible_id]}
    return fetch


def run(content, sources, choices=None, **kw):
    return refresh(content, sources, choices or {"default": "NIV", "verses": {}},
                   IDS, kw.pop("fetch", fake_api()), kw.pop("today", TODAY))


def saved(content):
    return json.loads((content / "licensed-verses.json").read_text())


def test_passage_ids_use_api_bible_book_codes():
    assert passage_id("1 Peter 2:24") == "1PE.2.24"
    assert passage_id("Psalm 91:13") == "PSA.91.13"
    assert passage_id("Genesis 3:15") == "GEN.3.15"
    with pytest.raises(ValueError):
        passage_id("Hezekiah 1:1")


def test_each_wall_verse_gets_the_matching_clause_once(content, sources):
    calls = []
    run(content, sources, fetch=fake_api(calls=calls))
    got = {v["ref"]: v for v in saved(content)["verses"]}
    assert set(got) == {"Genesis 3:15", "Psalm 91:11", "Genesis 2:9"}  # Douay-Rheims untouched
    assert sorted(calls) == sorted({("niv-id", passage_id(r)) for r in got})
    want, _ = align(FIX["Genesis 3:15"]["excerpt"], FIX["Genesis 3:15"]["BSB"], FIX["Genesis 3:15"]["ENGWEBP"])
    assert got["Genesis 3:15"] == {"ref": "Genesis 3:15", "translation": "NIV", "text": want, "match": "clause"}
    assert saved(content)["fetchedAt"] == "2026-11-10"


def test_a_verse_can_be_switched_to_the_nlt(content, sources):
    calls = []
    run(content, sources, {"default": "NIV", "verses": {"Psalm 91:11": {"translation": "NLT"}}},
        fetch=fake_api(calls=calls))
    got = {v["ref"]: v for v in saved(content)["verses"]}
    assert got["Psalm 91:11"]["translation"] == "NLT"
    assert ("nlt-id", "PSA.91.11") in calls


def test_a_verse_can_be_set_to_show_in_full(content, sources):
    run(content, sources, {"default": "NIV", "verses": {"Genesis 3:15": {"full": True}}})
    got = {v["ref"]: v for v in saved(content)["verses"]}
    assert got["Genesis 3:15"]["text"] == normalize(FIX["Genesis 3:15"]["ENGWEBP"])
    assert got["Genesis 3:15"]["match"] == "full"


def test_an_unsure_match_falls_back_to_the_whole_verse_and_is_reported(content, sources):
    # Basic English Isaiah-style paraphrase: Psalm 91:11 matches at only 0.20 (see the align review).
    report = run(content, sources, fetch=fake_api("eng_bbe"))
    got = {v["ref"]: v for v in saved(content)["verses"]}
    assert got["Psalm 91:11"]["text"] == normalize(FIX["Psalm 91:11"]["eng_bbe"])
    assert got["Psalm 91:11"]["match"] == "whole-unsure"
    assert "Psalm 91:11" in report


def test_copyright_notices_are_saved_for_each_translation_shown(content, sources):
    run(content, sources, {"default": "NIV", "verses": {"Psalm 91:11": {"translation": "NLT"}}})
    notices = json.loads((content / "notices.json").read_text())["notices"]
    assert notices == {"DRA": "keep me", "NIV": "NIV notice", "NLT": "NLT notice"}


def test_report_never_contains_verse_wording(content, sources):
    report = run(content, sources)
    for v in saved(content)["verses"]:
        assert v["text"] not in report
    assert "3 verses" in report


def test_failed_fetch_keeps_recent_verses(content, sources):
    run(content, sources, today=date(2026, 11, 1))
    before = (content / "licensed-verses.json").read_text()
    report = run(content, sources, fetch=fake_api(fail=True))
    assert (content / "licensed-verses.json").read_text() == before
    assert "kept" in report and "network down" in report


def test_failed_fetch_drops_verses_older_than_30_days(content, sources):
    # API.Bible: cached content must be refreshed at least once every 30 days.
    run(content, sources, today=date(2026, 10, 1))
    report = run(content, sources, fetch=fake_api(fail=True))
    assert saved(content)["verses"] == []
    assert "30 days" in report


def test_missing_keys_still_leaves_a_valid_empty_file(content, sources):
    report = refresh(content, sources, {"default": "NIV", "verses": {}}, {}, fake_api(), TODAY)
    assert saved(content)["verses"] == []
    assert "not set" in report


@pytest.mark.skipif(not Path("/usr/bin/python3").exists(), reason="no system Python")
def test_script_loads_isolated_under_the_system_python_launchd_uses():
    # refresh.sh runs `python3 -I`; under launchd that is Apple's /usr/bin/python3 (3.9.6 here).
    # -I leaves the script's folder off sys.path, and 3.9 rejects `X | None` annotations.
    import subprocess
    script = Path(__file__).resolve().parent.parent / "fetch_verses.py"
    r = subprocess.run(["/usr/bin/python3", "-I", "-c",
                        f"import runpy; runpy.run_path({str(script)!r}, run_name='loaded')"],
                       capture_output=True, text=True)
    assert r.returncode == 0, r.stderr


# Into the Quiet (docs/superpowers/specs/2026-11-16-prayer-mode-design.md)

def test_prayer_books_have_codes():
    assert passage_id("Lamentations 3:23") == "LAM.3.23"
    assert passage_id("Philippians 4:7") == "PHP.4.7"


def test_prayer_lines_are_fetched_like_wall_verses(content, sources):
    (content / "prayer.json").write_text(json.dumps({
        "morning": [{"ref": "Psalm 42:1", "text": FIX["Psalm 42:1"]["excerpt"]}],
        "evening": [{"ref": "John 7:37", "text": FIX["John 7:37"]["excerpt"]}]}))
    ex = wall_excerpts(content)   # neither is a figure's or a beat's verse in this fixture
    assert ex["Psalm 42:1"] == FIX["Psalm 42:1"]["excerpt"] and "John 7:37" in ex
    run(content, sources)
    assert {"Psalm 42:1", "John 7:37"} <= {v["ref"] for v in saved(content)["verses"]}


def test_no_prayer_file_is_fine(content):
    assert "Genesis 3:15" in wall_excerpts(content)


def test_every_reference_in_the_real_content_has_a_book_code():
    # 2026-11-16: a figure's 1 Kings verse stopped every fetch (no book code). Check them all.
    real = Path(__file__).resolve().parent.parent.parent / "App/Content"
    for ref in wall_excerpts(real):
        passage_id(ref)


def test_all_sixty_six_books_have_codes():
    assert passage_id("1 Kings 17:6") == "1KI.17.6"
    assert passage_id("Song of Solomon 2:11") == "SNG.2.11"
    assert passage_id("Revelation 22:5") == "REV.22.5"


def test_every_reference_in_the_real_content_has_a_bsb_source():
    # The NIV clause is found by aligning against the full BSB verse (docs/copy/verse-sources.json).
    root = Path(__file__).resolve().parent.parent.parent
    sources = json.loads((root / "docs/copy/verse-sources.json").read_text())
    missing = [r for r in wall_excerpts(root / "App/Content") if "BSB" not in sources.get(r, {})]
    assert missing == []
