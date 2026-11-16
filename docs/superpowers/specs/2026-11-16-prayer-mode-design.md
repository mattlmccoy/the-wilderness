# Into the Quiet: a prayer mode (design, 2026-11-16)

## Intent

Matt, 2026-11-16: "it would be very cool if we built in a devotional and prayer mode." Asked about
the moment he'd use it: "I'm alone or with my wife, it's either morning or night, and it should be a
calming peaceful prayerful meditation. Think contemplative prayer. Into the quiet."

This is a way into silence, not a lesson, a tour or something to watch. The wall offers one short
line of scripture, then only light. The phone holds the guidance, so the wall can stay almost
wordless.

## What Matt decided

- **Who and when:** Matt alone or with his wife, in the morning or at night.
- **Words:** one short line of scripture (or a short prayer), then just light.
- **Light during the silence:** on Christ alone, breathing very slowly.
- **Translation:** NIV.
- **Started from the phone,** because the phone can carry richer context than the wall.
- **Shape: lectio divina,** four movements: Read, Reflect, Respond, Rest. The wall stays on Christ's
  light; the phone marks each movement softly and stays dark between them (mockup option C,
  `.superpowers/brainstorm/…/prayer-phone.html`).
- **Length:** picked each time on the phone: 5, 10, 20 or 30 minutes.
- **Accepted defaults** (proposed, Matt said "those assumptions are fine"): a morning set and a night
  set of lines, chosen by time of day; the line changes each day; sound, if on, is the soft bed plus a
  single bowl breath, nothing else.

## Goals

1. A session that someone can start from the sofa in two taps and then forget the phone exists.
2. The wall is calmer during prayer than at any other time.
3. The scripture line is beautiful and readable on the cloth, then gone.
4. Morning and night feel different: morning opens the day, night releases it.

## Non-goals

- No narration or spoken guidance. No journaling, no history, no streaks, no counts.
- No new remote menu item (the phone starts it; see "Remote" below for what the remote does).
- No editing of verses or prayers in the app.

## Anti-goals (would make it a failure even if it works)

- Anything startling: a bowl strike, a sudden light change, a pop-up, a phone buzz or chime.
- Anything playful during prayer: no glints, rare moments, drifting light, sun rays, seasonal hats,
  snow, turkey, candles, dreamcoat, flashlight.
- Text anywhere but on the canvas, in a calm zone (standing rule: there is no room beside the cloth).
- Licensed verse text in the repository, in screenshots, or written by Claude (standing rules).

## Constraints

- **Light only.** The projector can only add light. Black is no light.
- **All text on the canvas,** inside the 2 in margin, in a calm zone, scaled to fit (`CanvasText`,
  `CanvasTextFrame`), never below the sofa-readable floor.
- **NIV through the existing licensed path.** The repo commits public-domain Berean Standard Bible
  wording as the placeholder for each line; `scripts/fetch_verses.py` fetches the NIV at build time
  into git-ignored `App/Content/licensed-verses.json`, as it does for the wall's other verses. The BSB
  placeholder wording must be taken from the BSB's published public-domain text, never written from
  memory. Claude never sees or writes NIV text.
- **No verse screenshots.** Simulator checks of the Read movement and the phone's verse screen are
  done by tests and by protocol checks, not screenshots (memory: wilderness-no-verse-screenshots).
- **Phone ↔ wall protocol** is the existing newline-JSON over TCP (`PhoneCommand`, `WallSnapshot`);
  both apps are always installed together.

## How it works

### Starting (phone)

A new "Into the quiet" entry on the phone (placement in the phone UI is left to the builder, but it
must be reachable in one tap from the main screen). Its screen shows:
- "Morning" or "Evening" (by the wall's clock), the title "Into the quiet".
- Today's line with its reference ("Psalm 4:8 · NIV"), as the wall will show it.
- The four movements in one line each (Read it slowly, twice. Reflect on the word that stays.
  Respond in your own words. Rest in the silence.) — **draft copy, for Matt's approval.**
- Length: 5, 10, 20, 30 minutes (one selected; default 10, remembered on the phone).
- Begin.

### The session (wall and phone together)

Movements and how the chosen length divides between them (**my call**, Rest about half):

| Movement | Share | Wall | Phone |
|---|---|---|---|
| Read | 10% (at least 45 s) | The line on the canvas, large, then fading out over the last ~8 s | The line and reference, then dims |
| Reflect | 20% | Christ's light only, breathing very slowly | Dark; the word "Reflect", "1 of 4"-style progress |
| Respond | 20% | Same | "Respond" |
| Rest | the remainder (~50%) | Same | "Rest" |

- **Entering:** whatever the wall was doing fades out over ~6 s to near-darkness, then Christ's light
  rises. (Explore text, menus, everything clears.)
- **Christ's breath:** one slow cycle every 14 s (**my call**; the wall's resting breath is 12 s and
  "very slowly" means slower). Breath depth gentle: never fully dark, never bright.
- **Movement changes:** a single bowl breath (the existing struck-less bowl bloom, Christ's note) if
  sound is on; otherwise silent. The phone's label cross-fades. No haptics during the session.
- **The rest of the wall is still:** no breathing elsewhere, glints, drift, moments, passing light,
  seasonal touches, turkey, candles, dreamcoat. Day-light warmth and level still apply.
- **Sound:** if on, the bed plays softly (lower than at rest); if off, silence. Prayer mode does not
  change the sound setting.

### Ending

- At the end of Rest, the phone shows a closing line (**draft, for Matt's approval**: "Amen. Go in
  peace." in the morning; "Amen. Sleep in peace." at night) for ~20 s, then returns to its main
  screen.
- **Morning:** Christ's light eases back to the wall at rest.
- **Night:** the light fades out slowly (~30 s) and the wall lets the Apple TV sleep (as wind-down
  does), so you can simply stay sitting.
- **End early:** an End button on the phone (fades as above); **any press on the remote** also ends it,
  as with Be still (**my call**).

### Rulings after the builder check (my calls, marked for Matt)

- **Which ending, by the clock.** Morning lines and the "Morning" label: 04:00–14:59; "Evening"
  lines: 15:00–03:59. But the *sleep* ending (fade to dark, let the TV sleep) only happens from 21:00
  to 03:59. Any other session ends by easing back to the wall at rest. A 4 pm session never blacks
  out the wall.
- **After a night fade.** The wall stays dark until the next press on the remote or phone (then it
  wakes to rest), or until wind-down's normal morning wake at 05:00. Prayer overrides wind-down while
  it runs; when it ends, wind-down applies again as normal (e.g. a 04:30 session ends into wind-down's
  sleep until 05:00).
- **Lines that are too long.** I choose each line's clause from the public-domain BSB text (Matt
  reviews the list); the fetch keeps the matching NIV clause. If a fetched NIV line still doesn't fit
  its zone at the floor size, that reference is skipped in the rotation (the next one is used) and the
  fetch summary says so. It never blocks the nightly build, and the wall never shows a BSB line
  labelled NIV.
- **Approval.** Code and content are built together. Matt approves the verse lists and the phone copy
  before anything is installed; changing a reference after that costs one re-fetch.
- **The phone during a session.** The Apple TV owns all the timing; the phone only displays. The phone
  keeps its screen on (black, dim) for the session, so the closing line is seen. If it locks or drops
  anyway, the session carries on; on reconnect it shows the current movement, or the closing line if
  the session ended in the last minute. A second phone sees the same and can end it.

### Morning, night and the daily line

- **Morning:** 04:00–14:59 on the wall's clock; **night:** 15:00–03:59 (**my call**; "evening" label).
- A morning list and a night list of verse references; one line per day, chosen deterministically
  from the date so it changes daily and both people see the same line.
- **Draft lists for Matt's approval (references only; I have not written any verse text):**
  - Morning: Psalm 5:3, Psalm 143:8, Lamentations 3:23, Psalm 46:10, Isaiah 40:31, Psalm 90:14,
    Psalm 118:24, Psalm 59:16, Isaiah 26:3, Psalm 62:1, Psalm 27:4, Psalm 16:11, John 14:27,
    Matthew 11:28.
  - Night: Psalm 4:8, Psalm 91:1, Psalm 121:4, Psalm 139:12, Psalm 63:6, Psalm 23:2, Psalm 131:2,
    Philippians 4:7, Psalm 62:5, Psalm 116:7, Isaiah 30:15, Psalm 42:8, 1 Peter 5:7, Psalm 3:5.
- A line may be part of a verse (a clause), as the wall already does; the fetch keeps the matching
  clause (`verse_align.py`). Lines longer than fits the zone at the floor size are flagged by a test.

### Remote

The remote can't start prayer mode. While it runs, any press ends it (fading as above). Menu and
Settings are unchanged.

### Status and parity

- The phone's status line shows "Into the quiet · Rest" while it runs; the TV snapshot carries the
  movement and progress, so a second phone (Matt's wife's) sees the same state and can end it.
- Parity note: this is a deliberate phone-only start, like the flashlight; documented in the README.

## Left to the builder

- Where "Into the quiet" sits on the phone's main screen; the phone's exact visual styling within the
  existing palette and type.
- Protocol shapes (e.g. `PhoneCommand.pray(minutes:)`, `endPrayer`, snapshot fields) and the mode
  machine's representation (a new `Mode` case vs. a flag like Be still).
- Which calm zone the line uses (largest calm zone away from Christ is the obvious choice).
- How the fetch script learns the new references (e.g. a `prayer.json` it reads beside annotations
  and unfold) and adding missing book codes (Lamentations, Philippians…).
- Test design, as usual test-first for every piece of logic.

## Verification

- Core tests: movement timing for each length, morning/night boundary, daily rotation, ending
  behaviour, quiet-wall rules (what is off), protocol round-trips.
- Content test: every reference has a BSB placeholder and fits its zone at the floor size.
- Simulator: film a 5-minute session with the painting off, from the Reflect movement on (no verse
  on screen). Screenshot the phone only on its dark movement screens and the closing line; its start
  screen and the Read movement show the verse, so those are checked by tests, never by screenshot.
- Real wall: Matt tries a morning and a night session.
