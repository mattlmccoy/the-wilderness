import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from paste_verses import run  # noqa: E402

# Dummy wording only: no real licensed Bible text in tests.


def make_content(tmp: Path) -> Path:
    v = lambda ref, tr="BSB": {"ref": ref, "text": "placeholder " + ref, "testament": "old", "translation": tr}
    more = lambda *vs: {"story": "s", "verses": list(vs), "connection": "inScripture", "draft": True}
    (tmp / "annotations.json").write_text(json.dumps({"artworkAspect": 1.2, "annotations": [
        {"id": "a", "more": more(v("Isaiah 53:4"), v("Psalm 90:13", "DRA"))},
        {"id": "b", "more": more(v("Isaiah 53:4"))}]}))
    (tmp / "unfold.json").write_text(json.dumps({"beats": [{"id": "x", "more": more(v("John 1:3"))}]}))
    (tmp / "notices.json").write_text(json.dumps({"notices": {}}))
    return tmp


def answers(*xs):
    it = iter(xs)
    return lambda _prompt="": next(it)


def test_pastes_each_placeholder_reference_once_and_skips_public_domain_latin(tmp_path):
    d = make_content(tmp_path)
    run(d, ask=answers("niv", "dummy one", "", "dummy notice"), say=lambda *_: None)
    saved = json.loads((d / "licensed-verses.json").read_text())["verses"]
    assert saved == [{"ref": "Isaiah 53:4", "translation": "NIV", "text": "dummy one"}]
    assert json.loads((d / "notices.json").read_text())["notices"] == {"NIV": "dummy notice"}


def test_resumes_without_asking_again_for_pasted_verses(tmp_path):
    d = make_content(tmp_path)
    run(d, ask=answers("esv", "dummy", "", "n"), say=lambda *_: None)
    asked = []
    run(d, ask=lambda p="": asked.append(p) or "", say=lambda *_: None)
    assert len(asked) == 1  # only John 1:3 is still open
