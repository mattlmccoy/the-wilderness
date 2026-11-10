# The Wilderness: light, motion, and the three experiences

Design document, 10 November 2026. Covers the visual language and three of the four experiences
in the original brief: **Stillness**, **Explore**, and **Unfold**. Context (the visual essay) and the
iPhone pieces are later, separate projects.

**Source material in the repo:**
- `docs/brief.md`: Matt's original brief, verbatim.
- `docs/studies/light-studies-round3.html`: the interactive round-3 light study Matt reviewed. Open it in a
  browser. It holds the working glint and light code these defaults come from.
- `docs/reference/met-11.53-600x502.jpg`: the reference image the study used.
- `docs/reference/met-11.53-DP-19630-001-4000x3349.jpg`: the Met's public-domain full-resolution scan.
- `docs/reference/estimated-outlines.json`: the study's eight rough subject outlines, with the transform
  into artwork-normalised coordinates.

Legend: decisions marked **(Matt)** were made by Matt in conversation. Decisions marked **(my call)**
were made by Claude and are open to change. Everything else follows from those two.

---

## 1. Intent

A woven reproduction of Moretto da Brescia's *Christ in the Wilderness* (the Met, 11.53) hangs in
Matt and his wife's home. The tapestry is 60 in wide × 50 in tall and hangs from a rod pocket. An XGIMI
Elfin Flip (1080p, 400 lm, lamp, not laser) projects onto it from an Apple TV.

The people in front of it are guests in the house, or Matt and his wife. **What they should feel is
peace (Matt).** The brief's line still holds: make a five-hundred-year-old painting feel quietly alive,
something a guest discovers rather than technology that demands attention.

What that means in practice (Matt):

- **Incredibly subtle and quiet.** Most of the time the effect should be close to invisible.
- **A magical glimmering, as if the tapestry is breathing.** It happens rarely, in places that make
  sense, and it can occasionally catch your eye.
- **The app is opened once and left running** whenever the projector is on.
- **When someone picks up the remote, the details come to life.**

## 2. Physical constraints that shape the design

These come from the room and the hardware, and they are why the design looks the way it does.

| Fact | Consequence |
|---|---|
| The room is somewhat lit (Matt) | A whole-tapestry brightness swell is invisible, because the eye adapts to it. Light must be *spatial*: one place brighter than its neighbours. |
| The projector can't do deep blacks (Matt) | "Black" still adds a faint grey frame of light. Nothing may depend on true darkness. The app can only *add* light. "Dimming" a region means lowering light the app itself added. |
| Masks are estimated from the Met image, not traced from the tapestry | Subject light must be heavily feathered so imprecise edges don't show. **No outline or edge line** until masks are traced from a photo of the real tapestry (Matt: "great if the masking was perfect, but it's just not yet"). |
| About 17 projector pixels per inch on the tapestry at the default calibration (`Calibration.defaultFor`: 864 px tall for 50 in). The real figure depends on the projector's distance. | A natural glint (about 0.06 in) is around one projector pixel. Glints are tuned on the wall, not on a screen. |
| The projector is 10–12 ft from the wall, at a slight angle (Matt). Its throw ratio is 1.2:1, so the full picture is about 100–120 in wide and 56–67 in tall. The tapestry hangs at most 1 in off the wall (Matt). | About **20–30 in of bare wall each side** of the 60 in tapestry. Text goes there (§5.2). The 1 in offset adds no visible parallax at this distance. |
| Free Apple ID, re-signed daily by `scripts/refresh.sh` | No paid-only capabilities: no TestFlight, CloudKit, or push notifications. |

## 3. Goals, non-goals, anti-goals

**Goals**

1. **Stillness** at rest: rare, natural glints across the piece and nothing else on the wall (Matt).
2. **Explore** with the remote: the chosen subject warms softly, the rest of the tapestry quietly
   recedes, and its text appears on the wall beside the tapestry (Matt).
3. **Unfold**: a guided, roughly five-minute sequence through the painting, started from the remote
   (Matt agreed to this split).
4. A calm, consistent design language for light, motion, and type.
5. A hidden **tuning screen**, so strength and glints can be adjusted live on the wall with the remote.
6. Copy rewritten in a voice aimed at peace (Matt).

**Non-goals for this version**

- Context (the visual essay and map of Renaissance Italy). This is a separate later project (Matt).
- iPhone-assisted automatic calibration and the iPhone companion. Later (Matt).
- Narration and audio (my call: the brief marks narration optional, and silence suits peace).
- Outline or edge lines around subjects (Matt, until masks are traced).
- An annotation or mask editor tool. Masks are hand-traced for now (my call).
- Drift transitions (my call). Fade ships. Drift returns only if Fade disappoints on the wall.
- Multiple artworks.

**Anti-goals: it fails, even if it works, if...**

- It looks like a screensaver, a TV app, or a museum kiosk on the wall.
- Glints look like sparkle effects: too big, too frequent, too regular, or a colour the projector's
  light wouldn't make (Matt's round-1 and round-2 feedback).
- A rough mask edge is visible.
- Any "unknown" state renders as healthy. Content that fails to load must be visibly an error, never a
  silent dark wall. This already holds and must be kept.
- It reads like a lecture. It should settle people, not argue with them.

## 4. The light model

Everything the app draws is light added to the tapestry.

**Units (my call):**
- "Strength" means a fraction of the projector's full output, drawn as `Palette.ivory` at that opacity over
  black (sRGB, as SwiftUI composites it).
- The study's exposure model existed only to imitate a lit room on a phone screen. It is not carried over.
- Every value here is a starting point that is tuned on the wall.

The layers, from bottom to top:

1. **Base wash.** An optional faint, even, warm wash over the whole tapestry.
   - **Default 0: the background is completely black, for as much contrast as possible (Matt,
     after the first wall test).** It stays in Tune light for experiments.
   - **(my call)** Its only job is to give Explore something to take away. When a subject is selected,
     the wash drops to 45% of its level elsewhere, so the rest "recedes" even though the projector
     can't go darker than black.
   - Tunable. 0 turns it off.
2. **Subject light.** The selected subject's mask, filled with warm ivory light.
   - Feathered by about **2.2 in** on the wall (44 canvas units; 1 canvas unit ≈ 0.05 in).
   - Strength 0.44 by default, tunable.
   - The feather must be large enough that the estimated masks never show an edge.
3. **Glints** (Stillness only, and also behind Explore if the builder finds it doesn't distract;
   builder's call after a wall test).
4. **Text**, drawn as light on the bare wall beside the tapestry.

Colour: everything is drawn in the warm light of `Palette.ivory`, never saturated (Matt: no unnatural
sparkle; brief: no neon or glow). Glints are the same ivory, not white or gold.

### 4.1 Glints

Settled in round 3 (Matt):

- They appear **anywhere on the piece where light could plausibly catch**, not tied to subjects.
  Examples: feather edges on the angels, robe folds, the white bird, leaves against the sky.
- They are **rare**: one at a time, never two at once.

Parameters from the round-3 study, all tunable:

| Parameter | Default |
|---|---|
| Timing | Random (Poisson); mean interval **8 s** ("now and then"); minimum gap 1.5 s after the previous one ends |
| Life | 0.8–1.4 s, random |
| Envelope | sin²: rises and falls smoothly, with no hard on/off |
| Peak brightness | random 0.50–0.85 of the glint ceiling. The ceiling is full-opacity ivory at the core pixel (my call): glints are tiny, so they need full output to register. |
| Size | core about **0.06 in**, never under half a projector pixel |
| Style | **"Along a thread"** (my call; Matt has not yet chosen between the two): stretched about 3:1 along the weave and sliding about 0.35 in across its life, as if light ran along one thread. The alternative is **"Pinpoint"**, a single soft point. Both stay in the tuning screen. |

**Where glints can appear.** Candidate points are precomputed offline, not at runtime (my call):
- A script reads the reference image.
- It keeps pixels with luminance above the 60th percentile that are also brighter than their local
  7×7 mean, i.e. edges and highlights.
- It keeps the top 6% of those, with a minimum of 40 points.
- It writes the result to `App/Content/glints.json` in artwork-normalised coordinates.

The same script is re-run on the tapestry photo once Matt provides it. The shipped file is checked by a
test, in the same way `annotations.json` is: it must be valid, non-empty, and inside the 0…1 range.

### 4.2 Transitions (Fade)

- **Moving between subjects in Explore:** the old subject's light fades out as the new one's fades in.
  - Cross-fade about **1.6 s**, ease-in-out.
  - The old text fades out in 0.6 s. The new text fades in over 1.0 s after the light has mostly
    settled.
- **Waking from Stillness:** the base wash and the first subject rise over about **3 s**. This should be
  slow enough to feel like the room changing, not a switch.
- **Returning to Stillness:** everything falls over about **6 s**.
- All durations are tunable constants in one place. None are user-facing settings.

## 5. The three experiences and the remote

### 5.1 Stillness (default, at rest)

What the app shows when launched and whenever no one is using it.
- Only glints, at the rhythm above, plus the base wash if it is turned on.
- No text, no interface, nothing that changes on a schedule a person could notice.
- **(my call)** While the app is in the foreground it keeps the Apple TV from starting its screensaver
  or sleeping (`isIdleTimerDisabled`). Otherwise the tvOS screensaver would replace the projection after
  a few minutes. Pressing the TV button leaves the app as usual, and normal Apple TV use is unaffected.
- **Safeguard (my call):** after **6 hours with no remote input**, the app hands the idle timer back, so the
  Apple TV can sleep under its own settings. This covers a projector switched off for the night with the
  app still open. The next remote press resets the 6 hours.

### 5.2 Explore

- **Entering:** any arrow from Stillness. It starts on Christ.
- **Arrows:** move to the nearest subject in that direction, by position on the tapestry. This already
  exists in `SpatialNavigator`.
- **Select:** shows or hides the story line and verses (§7). **Once shown, they stay shown as you move
  between subjects, until Select is pressed again (Matt).** The persistence is already built and tested.
- **‹ Back:** returns to Stillness.
- **Idle timeout:** no input for **45 s** returns to Stillness.

Text sits on the bare wall beside the tapestry, on the side given by each subject's `textSide`. It is
drawn through the same homography as the tapestry, so it lies flat on the wall.

**Column width adapts (my call).** The available wall is computed from the saved calibration: the
distance from the tapestry's edge to the edge of the projected frame.
- The column is at most 19 in wide, with a 2 in gap and a 0.5 in margin at the frame edge.
- It narrows to fit the wall that is actually there, down to 10 in. **Matt's wall is 87 in wide, which
  leaves 13.5 in each side of the centred tapestry, so the column is about 11 in there (Matt chose
  this, option A, after the first wall test).**
- Below 10 in on the preferred side, the text uses the other side.
- If both sides are below 10 in, it sits over the lower edge of the tapestry.

### 5.3 Unfold

A guided sequence of about five minutes that follows **the arc of the Bible's story through the picture
(Matt)**: from Eden, through Israel's forty years and the prophets, to Christ, showing how the earlier
scripture points to him. Each beat lights part of the tapestry and pairs an Old Testament passage with the
New Testament one it points to.

The beat list below is the **draft structure (my call)**. The final beats and every word are settled with
Matt in the copy pass (§7).

| # | Beat | Light | Scripture (draft pairing) |
|---|---|---|---|
| 1 | Eden: creatures at peace | whole tapestry rises, then the beasts softly | Genesis 2:19 → Mark 1:13 ("with the wild beasts") |
| 2 | The serpent and the promise | basilisk | Genesis 3:15 |
| 3 | Forty years in the wilderness | the whole landscape, no subject | Deuteronomy 8:2–3 |
| 4 | Forty days | Christ | Matthew 4:1–4, where he answers with Deuteronomy 8:3 |
| 5 | Fed in the wilderness | angels | 1 Kings 19:5–8 (Elijah) → Mark 1:13 / Matthew 4:11 |
| 6 | The peaceable kingdom | stag → fox → bear → lion | Isaiah 11:6–9 |
| 7 | The lion and the dragon | lion, then basilisk | Psalm 91:11–13, which Satan quotes in Matthew 4:6 |
| 8 | The rest of the story | the cherubs at the left (`fragment`), then the whole piece | the canvas was cut from a larger work of Christ's life; the story continues past the frame |

- **Timing:** each beat lasts about 35 s. Light settles first, then text appears. Beat 6 steps through its
  four animals at about 8 s each.
- **Data:** the beat list (subjects, text, durations) lives in data (`App/Content/unfold.json`), not code.
- **Subjects with several parts:** the angels and the cherubs are lit as one region each (builder's call).
- **Text side:** for whole-piece beats, text goes on the left (my call).
- **Remote:**
  - **Play/Pause** starts Unfold from Stillness or Explore (from the beginning), and pauses or resumes it.
  - **← / →** go to the previous or next beat.
  - **‹ Back** stops it and returns to Stillness.
  - **Select** does nothing (my call: avoids accidental skips).
- **End:** when it ends, it falls into Stillness.

### 5.4 Settings (hidden)

- **Opening:** hold Select for 1 s from Stillness or Explore. This is already how calibration opens.
- **What it shows:** a small, plain list on the wall: **Calibrate**, **Tune light**, **Alignment pattern**,
  **Show painting** (debug: projects the painting under everything, on/off, remembered), **About**. About holds the Bible translations' copyright notices and the Met image credit.
  Focus moves with up and down, Select opens an item, and ‹ Back closes the list.
- **(my call)** The alignment pattern moves here from Play/Pause, which Unfold now needs.

- **Calibrate:** the flow already built: Select through four corners, review, Select saves, ‹ cancels.
- **Tune light:** live adjustment while looking at the wall.
  - Settings: subject strength, base wash, glint frequency (Rare 16 s / Now and then 8 s / Often 4 s),
    glint brightness, glint size, glint style.
  - Up and down choose a setting, left and right change it.
  - While tuning, a glint fires every 2 s and Christ is lit, so changes are visible immediately.
  - Values persist on the Apple TV like the calibration does, and a "Reset to defaults" row is included.
- **Alignment pattern:** shows the registration test pattern until ‹ Back.

### 5.5 Full remote map

| Where | Arrows | Select | Hold Select | Play/Pause | ‹ Back |
|---|---|---|---|---|---|
| Stillness | Explore (Christ) | (nothing) | Settings | Start Unfold | Leave app (tvOS) |
| Explore | Move subject | Story and verses on/off (persists) | Settings | Start Unfold | Stillness |
| Unfold | ← → beat | (nothing) | (nothing) | Pause / resume | Stillness |
| Settings | Move focus / change value | Open / confirm | n/a | n/a | Close / back up a level |
| Calibration | Move corner | Next corner → review → save | n/a | Coarse/fine | Cancel (first setup: leave app) |

## 6. Design language

### 6.1 Type (my call; shown in the round-3 mockup)

- **Faces:** Cormorant Garamond for titles and EB Garamond for text. Both are SIL Open Font License, so
  they can be bundled in the app.
- **No uppercase eyebrow labels.** The current "DOCUMENTED / A LIKELY READING" line is removed from the
  wall (my call; it reads like a museum label). Evidence stays in the data and is carried by the wording
  of the copy instead (§7).
- **Hierarchy:**
  - The title, about 40 canvas units, roughly 2 in tall on the wall.
  - The short line, 22, italic.
  - The story line, 19, with generous leading.
  - Verses, 20, set apart with space above (my call; no quotation-mark ornaments or rules). Old
    Testament first, then New.
  - Each verse's citation, 13, small caps or tracked, at reduced opacity. These are the only references on
    the wall (§7).
- **Line length:** the column is at most about 380 canvas units (roughly 19 in), narrower where the wall
  is narrower (§5.2), and left-aligned.
- **Text as light:** ivory at reduced opacity, so it reads as projected light on the wall and fades
  naturally as the room gets brighter.

### 6.2 Motion

Slow, eased, never bouncy. Only one thing moves at a time where possible. There is no constant motion
other than the rare glint.

### 6.3 Colour

`Palette` as it is now (ivory, gold, stone), drawn from the painting. Gold is reserved for calibration
handles, never used on the art.

## 7. Copy

**The standard (Matt): every word counts.** It has to be intentional and must not sound like AI or LLM
writing. The copy is the hardest part of this project and gets its own track and review.

- **Audience and aim:** guests or Matt and his wife; the aim is peace (Matt).
- **Voice (my call; Matt will shape it in the copy pass):**
  - Short, slow, and plain.
  - Concrete nouns and verbs: say what is in the picture and what the text says.
  - No commentary on top of the scripture: the verse carries the meaning.
  - Honest, but light: where a connection is a Christian reading rather than something the Gospel itself
    says, the wording says so plainly.
- **What a subject shows** (Matt: both, leaning into the verses):
  1. **First press, the short line:** at most about 15 words.
  2. **Second press, "more":**
     - **One line of story:** at most about 25 words.
     - **An Old Testament passage.**
     - **The New Testament passage it points to**, showing the arc of the Bible's story toward Christ.
     - Each verse is a short excerpt (at most about 20 words), with its citation in small type beneath.
- **Translations (Matt):**
  - **Modern translations across the board:** NLT, NIV, and ESV.
    - (my call) Each verse uses whichever of the three reads most clearly and faithfully for that passage.
    - The citation names it, for example "Deuteronomy 8:3 · NIV".
  - **Older versions where they explain the picture:** where Moretto's choices come from the Bible he
    knew, the Latin Vulgate, the verse is quoted from the Douay-Rheims, its English translation. The
    clearest case is the basilisk: Psalm 90:13 in the Vulgate (91:13 in modern numbering) names an asp
    and a basilisk, while modern translations say cobra or serpent. The wording makes the reason visible,
    for example "the Bible Moretto read".
  - **Permissions:** NIV, ESV, and NLT may be quoted without written permission well within their limits
    (around 500 verses, never a whole book; this app uses about 40). Two conditions apply:
    - Each quotation carries its abbreviation.
    - The full copyright notices appear in the app. They go in Settings → About (§5.4), not on the art.
    - The builder confirms each publisher's current terms (Biblica, Crossway, Tyndale) before the copy
      ships. Douay-Rheims is public domain.
- **Two kinds of connection, kept distinct in the data and the wording:**
  - **In scripture:** the New Testament itself quotes or names the Old Testament text. For example, Jesus
    answers with Deuteronomy 8:3, and Satan quotes Psalm 91.
  - **Christian reading:** the connection is a traditional interpretation, such as Genesis 3:15 read as a
    promise about Christ, or Isaiah 11 and the beasts.
- **Off the wall:** references beyond each verse's own citation, the Met catalogue facts, and the evidence
  class stay in the data and the README.
- **Painting versus weaving:** text about "the canvas" needs rewording for a woven reproduction, or the
  difference becomes part of the story. Settled in the copy pass.

**Process (my call):**
1. Claude drafts the eight subjects and the eight Unfold beats.
   - Sources: `docs/brief.md` and the existing facts in `annotations.json`.
   - Every verse is checked word for word against the published text of its translation.
2. Every draft goes through an anti-AI-writing pass before Matt sees it. It removes:
   - "not X but Y" constructions
   - rhetorical questions
   - triplets used for rhythm
   - inflated words such as "testament", "tapestry of", "whisper", "timeless"
   - a sentence explaining what the verse just said
3. Matt reviews line by line, reading the lines on the wall where possible. **Nothing in the new copy
   ships without his approval.**
4. The code is built and tested with today's copy and clearly marked draft beats. Changing copy needs no
   code change.
5. The length limits above become tests on the shipped files.

## 8. Content and data

- **`annotations.json`:** existing fields stay. One new field, `more`:
  - `story`: one line.
  - `verses`: a list of `{ref, text, testament: old|new, translation}`.
  - `connection`: `inScripture` or `christianReading`.
- The app shows `more` on the second press. The old `extended` text stays in the data for the README and
  is no longer projected.
  - `outline` polygons get filled in, first from the Met reference image (as estimated in the mockups,
    mapped with the 11/10 px border crop), later from the tapestry photo.
  - `geometrySource` records which.
- **`glints.json`:** new; candidate points (§4.1).
- **`unfold.json`:** new; the beats (§5.3), each with its light targets, timing, and the same `more`-style
  story and verses.
- **Tuning values:** persisted locally, versioned, with defaults in code.

Every external data shape the code reads is a file this project produces. Each gets a test that loads the
*shipped* file, as `RealContentTests` already does for annotations.

## 9. Constraints for the builder

- **Already in place:** native tvOS, SwiftUI, and `MappedCanvas` (one homography warps the whole artwork
  layer).
- **Rendering technology** (SwiftUI `Canvas` with `TimelineView`, Core Animation, or Metal) is the
  builder's call. It must hold 60 fps on an Apple TV 4K without heating up when left running for hours.
- **Pure logic goes in `WildernessCore` and is written test-first** (red, then green). That covers:
  - the mode state machine
  - the glint scheduler, using an injectable random source and clock
  - the Unfold timeline
  - the idle timeout
  - tuning persistence
- **Visual work:** each change is verified with a Simulator screenshot, then on the wall.
- **Normal Apple TV use must be unaffected.** No new hardware, no paid account.
- **Changes stay small and reviewable.** No new framework layers or placeholder screens.

## 10. Left to the builder

- Rendering technology and how masks are rasterised and feathered.
- Exact easing curves within the stated durations.
- Whether glints continue faintly behind Explore (decide after a wall test).
- File and type names, module boundaries inside the app target.
- How the Settings list is drawn, as long as it is minimal, on the wall, and only visible while open.

## 11. Waiting on Matt

1. **The Apple TV pairing**, for any on-wall testing.
2. **A straight-on photo of the tapestry**, for traced masks and re-computed glint points. The design
   ships with the estimated outlines in `docs/reference/estimated-outlines.json` until then.

## 12. Answered questions

1. **Wall beside the tapestry:** the projector is 10–12 ft away, giving about 20–30 in each side (§2 and
   §5.2).
2. **The second press:** both a line of story and scripture, leaning into the verses, with Old Testament
   passages that point to Christ (§7). Unfold follows the same arc (§5.3).
3. **Translations:** NLT, NIV, and ESV across the board, plus the Douay-Rheims (the Vulgate in
   English) where it explains what Moretto painted (§7).
