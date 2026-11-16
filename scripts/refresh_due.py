#!/usr/bin/env python3
"""Decides whether the weekly re-sign should run now (used by scripts/refresh.sh).

Free signing lasts 7 days. launchd checks every afternoon; this lets an install happen only
between 14:00 and 21:59, and only when the last good install is at least 6 days old. A Mac that
wakes at night (launchd then runs missed jobs) is turned away, and a missed evening retries the
next one. Exit 0 = run, 1 = skip.
    python3 -I scripts/refresh_due.py ~/Library/Logs/Wilderness-last-ok
"""
from __future__ import annotations

import sys
from datetime import datetime, timedelta
from pathlib import Path

WINDOW_HOURS = range(14, 22)          # 2 pm to 9:59 pm
EVERY = timedelta(days=6)


def should_run(now: datetime, last_ok: datetime | None) -> bool:
    if now.hour not in WINDOW_HOURS:
        return False
    return last_ok is None or now - last_ok >= EVERY


def main() -> int:
    stamp = Path(sys.argv[1]).expanduser()
    try:
        last = datetime.fromisoformat(stamp.read_text().strip())
    except (FileNotFoundError, ValueError):
        last = None
    return 0 if should_run(datetime.now(), last) else 1


if __name__ == "__main__":
    sys.exit(main())
