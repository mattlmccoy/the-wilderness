#!/usr/bin/env python3
"""Paste licensed Bible wording (NIV, ESV, NLT) into the app, one verse at a time.

Usage (in Terminal, from the Wilderness folder):
    python3 -I scripts/paste_verses.py

For each verse still showing the free placeholder (BSB), it shows the reference and the
placeholder phrase. Type NIV, ESV or NLT, then paste the same phrase from your Bible.
Press Enter on an empty line to skip a verse for now. Progress is saved after every answer,
so you can stop and run it again later. At the end it asks once for each translation's
copyright notice, shown in the app under Settings → About.

Your pasted text goes only into App/Content/licensed-verses.json and notices.json.
"""
import json
import sys
from pathlib import Path

TRANSLATIONS = {"NIV", "ESV", "NLT"}


def placeholder_refs(content: Path) -> list[tuple[str, str]]:
    ann = json.loads((content / "annotations.json").read_text())["annotations"]
    beats = json.loads((content / "unfold.json").read_text())["beats"]
    seen, out = set(), []
    for item in ann + beats:
        for v in (item.get("more") or {}).get("verses", []):
            if v["translation"] == "BSB" and v["ref"] not in seen:
                seen.add(v["ref"])
                out.append((v["ref"], v["text"]))
    return out


def run(content: Path, ask=input, say=print) -> None:
    lic_path, not_path = content / "licensed-verses.json", content / "notices.json"
    licensed = json.loads(lic_path.read_text()) if lic_path.exists() else {"verses": []}
    notices = json.loads(not_path.read_text())

    def save() -> None:
        lic_path.write_text(json.dumps(licensed, indent=2, ensure_ascii=False) + "\n")
        not_path.write_text(json.dumps(notices, indent=2, ensure_ascii=False) + "\n")

    done = {e["ref"] for e in licensed["verses"] if e["text"].strip()}
    todo = [(r, p) for r, p in placeholder_refs(content) if r not in done]
    say(f"{len(todo)} verse(s) still use the free placeholder.\n")
    for ref, placeholder in todo:
        say(f"\n{ref}\n  placeholder: {placeholder}")
        tr = ask("  Translation (NIV, ESV, NLT), or Enter to skip: ").strip().upper()
        while tr and tr not in TRANSLATIONS:
            tr = ask("  Please type NIV, ESV or NLT, or Enter to skip: ").strip().upper()
        if not tr:
            continue
        text = ask(f"  Paste the same phrase from the {tr}, then press Enter: ").strip()
        if not text:
            continue
        licensed["verses"] = [e for e in licensed["verses"] if e["ref"] != ref]
        licensed["verses"].append({"ref": ref, "translation": tr, "text": text})
        save()

    used = sorted({e["translation"] for e in licensed["verses"] if e["text"].strip()})
    for tr in used:
        if notices["notices"].get(tr):
            continue
        say(f"\nThe {tr} needs its copyright notice in the app (Settings → About).")
        say("  Copy it from the publisher's permissions page or the front of your Bible.")
        n = ask(f"  Paste the {tr} notice, then press Enter (or Enter to do it later): ").strip()
        if n:
            notices["notices"][tr] = n
            save()
    save()
    say("\nSaved. Rebuild the app to see it: launchctl kickstart gui/$(id -u)/com.mattmccoy.wilderness.refresh")


if __name__ == "__main__":
    run(Path(__file__).resolve().parent.parent / "App/Content")
    sys.exit(0)
