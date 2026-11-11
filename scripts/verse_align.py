"""Pick, from a licensed verse, the clause that matches the excerpt shown on the wall.

The wall shows a short excerpt of a verse (written against the public-domain BSB). The licensed
translation (NIV, NLT) words it differently, so the same clause has to be found in its text
without anyone retyping it. The match is deterministic:

1. Split the licensed verse into clauses at punctuation.
2. Score each clause: +1 for each word it shares with the excerpt, -1 for each word it shares
   only with the parts of the BSB verse the excerpt leaves out, and a small bonus when the
   clause sits at the same relative place in the verse as the excerpt does in the BSB.
3. Take the contiguous run of clauses with the highest total.

The publisher's wording is never altered: the result is an exact run of their text, trimmed of
edge punctuation, with only the first letter capitalised. Pieces of an excerpt split by "…" are
matched separately and rejoined with "… " unless they turn out to be next to each other.
"""
import re

CONFIDENT = 0.5  # share of the excerpt's key words that the picked clause must contain

_STOP = set("""
a an and the of to in on for that this is are was were be been will shall with as at by from
but or so all his her their its him them he she it they you your yours thee thy thou ye i me my
we us our has have hath had not no who whom which what unto upon into there then than said
let do did does o
""".split())
_BOUNDARY = re.compile(r"[,;:.!?][\"”’']*(?:\s+|(?=[“‘\"]))|—")
_EDGE_LEAD = " ¶“\"‘'—,;:"
_EDGE_TRAIL = " ,;:—“”‘’\"'"


def normalize(text: str) -> str:
    """Collapse the API's line breaks, indentation and padding to single spaces."""
    return " ".join(text.split())


def _stem(word: str) -> str:
    for suffix in ("ing", "ed", "es", "s"):
        if word.endswith(suffix) and len(word) > len(suffix) + 2:
            return word[: -len(suffix)]
    return word


def _keys(text: str) -> list[str]:
    words = re.findall(r"[a-z]+", text.lower().replace("’", "'"))
    return [_stem(w) for w in words if w not in _STOP]


def _units(text: str) -> list[tuple[int, int]]:
    spans, start = [], 0
    for m in _BOUNDARY.finditer(text):
        if m.end() > start:
            spans.append((start, m.end()))
            start = m.end()
    if start < len(text):
        spans.append((start, len(text)))
    return spans


def _locate(part: str, verse: str) -> tuple[int, int] | None:
    """Character span of the excerpt piece inside the BSB verse, ignoring case and punctuation."""
    words = re.findall(r"[A-Za-z]+", part)
    if not words:
        return None
    m = re.search(r"[^A-Za-z]+".join(map(re.escape, words)), verse, re.IGNORECASE)
    return (m.start(), m.end()) if m else None


def _best_run(scores: list[float]) -> tuple[int, int]:
    best, best_i, best_j = scores[0], 0, 0
    run, run_i = 0.0, 0
    for j, s in enumerate(scores):
        if run <= 0:
            run, run_i = s, j
        else:
            run += s
        if run > best or (run == best and j - run_i < best_j - best_i):
            best, best_i, best_j = run, run_i, j
    return best_i, best_j


def _align_part(part: str, span: tuple[float, float], outside: set[str], text: str,
                units: list[tuple[int, int]]) -> tuple[int, int, float]:
    inside = set(_keys(part))
    lo, hi = span
    scores = []
    for a, b in units:
        keys = _keys(text[a:b])
        evidence = sum(k in inside for k in keys) - sum(k in outside for k in keys)
        mid = (a + b) / 2 / len(text)
        scores.append(evidence + (0.5 if lo - 0.05 <= mid <= hi + 0.05 else -0.5))
    i, j = _best_run(scores)
    picked = set(_keys(text[units[i][0]:units[j][1]]))
    recall = len(inside & picked) / len(inside) if inside else 0.0
    return i, j, recall


def _clean(piece: str) -> str:
    return piece.strip().lstrip(_EDGE_LEAD).rstrip(_EDGE_TRAIL)


def align(excerpt: str, bsb_verse: str, licensed_verse: str) -> tuple[str, float]:
    """Return (the matching wording from licensed_verse, confidence 0..1)."""
    text = normalize(licensed_verse)
    units = _units(text)
    if not units:
        return "", 0.0
    bsb = normalize(bsb_verse)
    parts = [p.strip() for p in excerpt.split("…") if p.strip()]
    spots = [_locate(p, bsb) for p in parts]
    # Words in the BSB outside the whole quoted stretch (first piece to last) count against a
    # clause; words skipped by an "…" inside the stretch do not.
    if all(spots):
        quoted = bsb[spots[0][0]:spots[-1][1]]
        outside = set(_keys(bsb[:spots[0][0]] + " " + bsb[spots[-1][1]:])) - set(_keys(quoted))
    else:
        outside = set(_keys(bsb)) - set(_keys(excerpt))
    n = len(bsb) or 1
    found = sorted(_align_part(p, (s[0] / n, s[1] / n) if s else (0.0, 1.0), outside, text, units)
                   for p, s in zip(parts, spots))
    merged: list[list[int]] = []
    for i, j, _ in found:
        if merged and i <= merged[-1][1] + 1:
            merged[-1][1] = max(merged[-1][1], j)
        else:
            merged.append([i, j])
    pieces = [_clean(text[units[i][0]:units[j][1]]) for i, j in merged]
    first = pieces[0]
    pieces[0] = first[:1].upper() + first[1:]
    return "… ".join(pieces), min(r for _, _, r in found)
