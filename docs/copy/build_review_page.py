#!/usr/bin/env python3
"""Builds the copy review page (HTML) from docs/copy/draft.json.

Usage: python3 -I docs/copy/build_review_page.py docs/copy/draft.json out.html
Every line gets an id (e.g. christ.short, beat3.v1) so Matt can comment on it by name.
"""
import html
import json
import sys

CONNECTION = {"inScripture": "The New Testament makes this link itself",
              "christianReading": "A traditional Christian reading"}


def words(s: str) -> int:
    return len(s.split())


def line(id_: str, cls: str, text: str, limit: int | None = None) -> str:
    n = words(text)
    over = limit is not None and n > limit
    count = f'<span class="count{" over" if over else ""}">{n}{"/" + str(limit) if limit else ""} words</span>'
    return (f'<div class="line {cls}" id="{id_}"><span class="lid">{id_}</span>'
            f'<p>{html.escape(text)}</p>{count}</div>')


def verse(id_: str, v: dict) -> str:
    return (f'<div class="line verse" id="{id_}"><span class="lid">{id_}</span>'
            f'<p>{html.escape(v["text"])}</p>'
            f'<p class="cite">{html.escape(v["ref"])} · {v["translation"]}'
            f'<span class="count{" over" if words(v["text"]) > 20 else ""}">{words(v["text"])}/20 words</span></p></div>')


def block(key: str, item: dict, kind: str) -> str:
    out = [f'<article class="item" id="{key}"><header><h3>{html.escape(item["title"])}</h3>'
           f'<span class="kind">{kind}</span></header>']
    out.append(line(f"{key}.short", "short", item["short"], 15))
    m = item.get("more")
    if m:
        out.append(line(f"{key}.story", "story", m["story"], 25))
        for i, v in enumerate(sorted(m["verses"], key=lambda v: v["testament"] != "old"), 1):
            out.append(verse(f"{key}.v{i}", v))
        out.append(f'<p class="conn">{CONNECTION[m["connection"]]}</p>')
    if item.get("note"):
        out.append(f'<p class="note"><b>For Matt:</b> {html.escape(item["note"])}</p>')
    out.append("</article>")
    return "\n".join(out)


def main(src: str, dst: str) -> None:
    d = json.load(open(src))
    subjects = "\n".join(block(s["id"], s, "Explore") for s in d["subjects"])
    beats = "\n".join(block(b["id"], b, f'Unfold · beat {i}') for i, b in enumerate(d["beats"], 1))
    page = open(__file__.replace("build_review_page.py", "review_template.html")).read()
    page = page.replace("{{SUBJECTS}}", subjects).replace("{{BEATS}}", beats)
    page = page.replace("{{DRAFT}}", html.escape(d["draft"])).replace("{{NOTES}}", "\n".join(
        f"<li>{html.escape(n)}</li>" for n in d["notes"]))
    open(dst, "w").write(page)
    print(f"wrote {dst}")


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
