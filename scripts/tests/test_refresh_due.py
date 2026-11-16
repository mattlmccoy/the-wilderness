"""When the weekly re-sign may run (Matt, 2026-11-15): about once a week, only in the
afternoon or evening, never at night, and never more than once a day."""
import sys
from datetime import datetime, timedelta
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
from refresh_due import should_run  # noqa: E402

SUN_6PM = datetime(2026, 11, 15, 18, 0)


def test_runs_in_the_evening_when_a_week_has_passed():
    assert should_run(SUN_6PM, last_ok=SUN_6PM - timedelta(days=6, hours=1))


def test_skips_when_the_last_install_is_recent():
    assert not should_run(SUN_6PM, last_ok=SUN_6PM - timedelta(days=2))


def test_never_runs_at_night_even_when_due():
    for hour in (22, 23, 0, 3, 7, 13):
        assert not should_run(SUN_6PM.replace(hour=hour), last_ok=SUN_6PM - timedelta(days=9)), hour


def test_runs_when_there_is_no_record_yet_in_the_window():
    assert should_run(SUN_6PM, last_ok=None)
    assert not should_run(SUN_6PM.replace(hour=2), last_ok=None)
