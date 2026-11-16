# Thanksgiving, season switches, a phone that mirrors the wall (Matt, 2026-11-16)

Matt: "Not all the modes appear on the phone app. Also the phone should reflect what's happening on
the tv. Thanksgiving mode should run this week and then through Thanksgiving day. These modes should
be able to be forced on or off in settings though. Like a seasons mode." Turkey idea: his wife's, a
turkey running on the far hill, then through the foreground, in and off the canvas.

Rules as before: light only, no text off the canvas, TDD for logic, simulator checks for UI,
nothing pushed or installed without Matt's word.

## Core (WildernessCore, test-first)
1. [x] `ChurchCalendar.thanksgiving(y)`: US Thanksgiving, the fourth Thursday of November.
2. [x] Thanksgiving season: from 10 days before (the Monday of the week before) through Thanksgiving
   Day. 2026: 16–26 Nov. (Ruling: "this week and then through Thanksgiving day", asked on Mon 16 Nov.)
3. [x] Season switches: `SeasonMode` (advent, christmas, lent, easter, thanksgiving) and
   `SeasonSwitch` (auto, on, off) per mode in `Tuning.seasonSwitches`; old profiles decode as auto.
   `Seasons.effects(at:tuning:)` applies them: off removes that season; on forces it any day.
   The master "Seasons" toggle off = every auto season off; a forced-on season still shows.
   Forced on (my calls): Advent shows this week's candles, or all four outside Advent; Lent shows
   its real day, or day 1; Easter's dawn sweeps at any hour; Christmas adds the star.
4. [x] `Turkey`: a 16 s run, hill path (small, ~7 s), a beat out of sight, foreground path (big,
   in from one edge and off the other). Every 10 min at rest; every 90 s when forced on, so it can
   be shown off. Paths live in delights.json (`turkey`), so they can be moved like the hats.
5. [x] Snapshot extras for the phone: `still` (Be still running, figure n of m), `dreamcoat`,
   `seasons` (what the wall is showing now), `demo`.
6. [x] Phone commands: `beStill(Bool)`, `dreamcoat(Bool)`.

## Wall
7. [x] Draw the turkey (painterly, like the hats): fan tail, wattle, running legs.
8. [x] Tune light screen: one row per season, ← → cycles auto / on / off.
9. [x] Answer the new phone commands; send the extras.

## Phone
10. [x] Mode row: Unfold, Context, Be still, Dreamcoat; the running one lit gold.
11. [x] A status line under the title: what the wall is doing now (e.g. "Be still · 3 of 13",
    "Dreamcoat", "Thanksgiving").
12. [x] Settings → Through the year: Seasons, Light follows the day, and Auto / On / Off per season.

## Verify
13. [x] Core suite, TV UI suite; simulator capture of the turkey; phone simulator against the TV
    simulator (direct mode) for the mode row, status line and switches.

## Changes after review (Matt, 2026-11-16)
- Hill turkey too small: hillSize 0.022 → 0.06; foreground 0.12 → 0.2.
- Dreamcoat is an Easter egg, not a mode: off the phone's mode row; hold the title for it.
- Found while checking: seasons drew over the Settings text (now hidden on settings screens); snow
  fell in diagonal rows (Scatter hash); hats/turkey overlaps added up as light (drawn as layers);
  two phone UI tests expected "The Painter", stale since the Context pages were reordered on 11 Nov.
