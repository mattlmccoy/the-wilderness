# Into the Quiet: Implementation Plan

> Executed inline (superpowers:executing-plans), test-first. Spec:
> docs/superpowers/specs/2026-11-16-prayer-mode-design.md (approved by Matt, 2026-11-16).

**Goal:** a lectio-divina prayer session started from the phone: one NIV line on the canvas, then only
Christ's light breathing every 14 s through Read, Reflect, Respond, Rest.

**Architecture:** pure session logic in WildernessCore (`Prayer`, `PrayerContent`, `PrayerSession`),
driven by `ModeMachine` like Be still; the wall draws a `PrayerLayer` and silences everything else;
the phone starts/ends it over the existing protocol and shows the movement from the snapshot.

## Global constraints (from the spec)
- Light only; the line sits on the canvas in the reading zone, scaled to fit.
- NIV only through `fetch_verses.py` → git-ignored `licensed-verses.json`; committed placeholders are
  BSB clauses taken from bereanbible.com/bsb.txt. Claude never writes or screenshots NIV text.
- Morning lines 04:00–14:59, evening 15:00–03:59; sleep ending only 21:00–03:59.
- Read 10% (≥ 45 s), Reflect 20%, Respond 20%, Rest the remainder; lengths 5/10/20/30 min.
- During prayer: no glints, drift, moments, sun rays, seasons, turkey, candles, dreamcoat, flashlight.
- Any remote press ends it. Phone End ends it. The TV owns all timing.
- A line whose shown text exceeds `Prayer.maxLineCharacters` (100) is skipped in the rotation.

## Review focus
1. A 4 pm session must end into rest, never dark.
2. A press on the remote mid-session ends it cleanly (no menu opened by that press).
3. Snapshot from a wall built before this change still decodes on the phone (optional fields).
4. A missing or empty `licensed-verses.json` shows BSB lines labelled BSB, never "NIV".
5. Every committed prayer reference has a BSB source verse, so the NIV fetch can align it.

### Task 1: Core prayer logic (Prayer.swift, PrayerTests.swift)
Tests first: period by hour (3:59 evening, 4:00 morning, 14:59 morning, 15:00 evening); sleep ending
(20:59 no, 21:00 yes, 03:59 yes, 04:00 no); schedule for 5/10/20/30 min (Read ≥ 45 s, shares sum to
the total, order); `PrayerSession.movement(at:)` boundaries and `isFinished`; daily line rotation
(deterministic by date, same for a whole day, changes the next day, skips over-long lines, applies
licensed text, falls back to BSB with the BSB label); `PrayerContent` decodes `App/Content/prayer.json`
and every ref there has a BSB source in `docs/copy/verse-sources.json`.

### Task 2: Mode machine, protocol, snapshot
Tests first: `startPrayer` / `endPrayer`; tick moves through movements and ends at the right time; the
ending goes to rest by day and to `afterPrayerDark` (until any press, or the given wake time) at night;
any remote press ends a session and is used up; `PhoneCommand.pray(minutes:)` and `.endPrayer`
round-trip; snapshot carries `prayer` (movement, index, of, minutes, line, ref, label, closing) and
`prayerToday`; status line reads "Into the quiet · Rest"; old snapshots decode.

### Task 3: Content and the NIV fetch
`App/Content/prayer.json` (14 morning, 14 evening, BSB clauses); `docs/copy/verse-sources.json` gains
the 28 full BSB verses; `fetch_verses.py` reads prayer lines too and gains LAM and PHP book codes.
Pytest first for both.

### Task 4: The wall
`PrayerLayer`: the line (fade in 4 s, out over the last 8 s of Read) in the reading zone, Christ's glow
breathing every 14 s (never dark, never bright); everything else quiet; bed lowered; a bowl breath
(Christ's note) at each movement change; night ending fades over 30 s and lets the TV sleep. Verified in
the simulator from Reflect on (no verse on screen).

### Task 5: The phone
A header button opens "Into the quiet": period, line + reference (from `prayerToday`), the four movement
lines, 5/10/20/30 (remembered), Begin. During: black screen, the movement name, "n of 4", End; idle timer
off. After: the closing line. Status line shows the session. Screenshots only of dark/closing screens.

### Task 6: Verify and finish
Core, Python, TV UI and phone UI suites; a simulator clip of a 5-minute session from Reflect on;
README section; commit; ask Matt before install.
