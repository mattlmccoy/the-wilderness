"""Tests for picking, from a licensed verse, the clause that matches the excerpt shown on the wall.

The licensed NIV/NLT text is never used here. Stand-ins are real public-domain translations
(WEB, KJV, BBE) captured from bible.helloao.org into fixtures/standin_verses.json, so the tests
exercise real wording differences between translations without touching licensed text.
"""
import json
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from verse_align import align, normalize, CONFIDENT  # noqa: E402

FIX = json.loads((Path(__file__).parent / "fixtures/standin_verses.json").read_text())
STANDINS = ("ENGWEBP", "eng_kjv", "eng_bbe")


def pick(ref: str, tr: str):
    row = FIX[ref]
    return align(row["excerpt"], row["BSB"], row[tr])


def test_normalize_collapses_api_line_breaks_and_indentation():
    # API.Bible returns poetry with newlines, indentation and padding (probed 2026-11-10:
    # PSA.91.13 had 2 newlines, 2 leading spaces, 3 double spaces).
    assert normalize("  You will tread on the lion\n    and the cobra;\n  you will trample. ") == \
        "You will tread on the lion and the cobra; you will trample."


def test_picks_the_matching_clause_not_the_rest_of_the_verse():
    text, score = pick("Genesis 3:15", "ENGWEBP")
    assert text == "He will bruise your head, and you will bruise his heel."
    assert score >= CONFIDENT


def test_whole_verse_excerpt_returns_whole_verse():
    row = FIX["Psalm 91:11"]
    text, _ = pick("Psalm 91:11", "ENGWEBP")
    assert text == normalize(row["ENGWEBP"])


def test_ellipsis_parts_that_turn_out_adjacent_are_joined_without_a_gap():
    text, score = pick("Luke 9:58", "ENGWEBP")
    assert text == "The foxes have holes and the birds of the sky have nests, but the Son of Man has no place to lay his head."
    assert score >= CONFIDENT


def test_first_letter_is_capitalised_for_a_mid_sentence_clause():
    text, _ = pick("Genesis 3:15", "eng_kjv")
    assert text == "It shall bruise thy head, and thou shalt bruise his heel."


def test_unrelated_text_is_not_confident():
    _, score = align(FIX["Genesis 3:15"]["excerpt"], FIX["Genesis 3:15"]["BSB"], FIX["John 1:3"]["ENGWEBP"])
    assert score < CONFIDENT


@pytest.mark.parametrize("ref", sorted(FIX))
@pytest.mark.parametrize("tr", STANDINS)
def test_every_pick_is_unaltered_wording_from_the_source(ref, tr):
    """The publisher's words are never changed: each piece is a contiguous run of the source,
    apart from a capitalised first letter and an ellipsis between non-adjacent pieces."""
    text, _ = pick(ref, tr)
    source = normalize(FIX[ref][tr])
    for piece in text.split("… "):
        assert piece, f"{ref} {tr}: empty piece"
        assert piece in source or (piece[0].lower() + piece[1:]) in source, f"{ref} {tr}: {piece!r}"


def test_paragraph_marks_are_not_shown():
    # The captured KJV Isaiah 53:4 begins with a pilcrow layout mark.
    text, _ = pick("Isaiah 53:4", "eng_kjv")
    assert not text.startswith("¶")
    assert text.startswith("Surely he hath borne")
