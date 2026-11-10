# Light, Motion, and the Three Experiences: Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn the working projection-mapping prototype into the approved experience. That means:
- **Stillness**, with rare glints;
- **Explore**, with soft subject light and a story-plus-verses second press;
- **Unfold**, the guided five-minute arc;
- a hidden **Settings** list with live tuning;
- the approved type.

**Architecture:**
- **Core first.** Every rule goes into the pure `WildernessCore` package, test-first, before any view
  touches it: modes and the remote, the glint timing, the Unfold timeline, tuning, wall geometry, and the
  content schemas.
- **Thin views.** The tvOS app target only draws those states through the existing `MappedCanvas`
  homography and forwards remote presses.
- **Content as data.** Content is JSON produced by this project and validated by tests that load the
  shipped files.

**Tech Stack:**
- Swift 5.9 and SwiftUI on tvOS 17+, with Swift Testing in `WildernessCore`.
- XCUITest (`XCUIRemote`) for remote flows.
- XcodeGen (`project.yml`).
- Python 3 with Pillow, numpy, and pytest for one offline content script.

**Spec:** `docs/superpowers/specs/2026-11-10-light-and-experiences-design.md`. Read it before starting any
task. Section numbers below (§) refer to it.

## Global Constraints

**Platform and build**
- tvOS deployment target 17.0. No paid-account capabilities: the app is signed with a free Apple ID and
  re-signed daily.
- After editing `project.yml`, run `xcodegen generate`. Never hand-edit `Wilderness.xcodeproj`.

**Tests**
- Pure logic lives in `Packages/WildernessCore` and is written red, then green.
  - Run: `cd Packages/WildernessCore && swift test` (all) or `swift test --filter <TestName>`.
- UI and remote tests run on the 1080p Apple TV simulator:
  `xcodebuild test -project Wilderness.xcodeproj -scheme Wilderness -destination 'platform=tvOS Simulator,name=Apple TV 4K (4th generation) (at 1080p)' -only-testing:WildernessUITests/<Class>/<test> CODE_SIGNING_ALLOWED=NO`
- Pure visual work has no unit test. Its gate is a Simulator screenshot
  (`xcrun simctl io booted screenshot <path>`) that the implementer opens and checks against the stated
  expectation. On-wall checks wait until the Apple TV is paired.

**Light and colour**
- Every visible element is light added to black. Only `Palette.ivory` is used for light and text;
  `Palette.gold` is only for calibration handles.
- Units: 1 canvas unit = 0.05 in on the wall (20 units per inch). The artwork canvas is 1200 × 1000
  units.
- "Strength" = `Palette.ivory` at that opacity over black.
- Defaults (§4):

  | Setting | Default |
  |---|---|
  | Base wash | 0.16 |
  | Explore wash factor | 0.45 |
  | Subject strength | 0.44 |
  | Feather | 2.2 in (44 units) |
  | Glint mean interval | 8 s |
  | Glint minimum gap | 1.5 s |
  | Glint life | 0.8–1.4 s |
  | Glint peak | 0.50–0.85 × ceiling, where the ceiling is opacity 1.0 |
  | Glint core size | 0.06 in, never under half a projector pixel |
  | Glint style | thread (3:1, slides 0.35 in) |

- Timings (§4.2):

  | Moment | Timing |
  |---|---|
  | Cross-fade between subjects | 1.6 s |
  | Old text out | 0.6 s |
  | New text in | 1.0 s, after the light settles |
  | Wake from Stillness | 3 s |
  | Return to Stillness | 6 s |
  | Explore idle | 45 s |
  | Idle timer handed back | after 6 h without input |

**Copy and content**
- Do **not** write or edit wall copy in code tasks. Copy is Track B and needs Matt's approval.
- Code tasks ship today's text plus beats marked `"draft": true`.
- No uppercase evidence labels on the wall. The only references on the wall are each verse's own
  citation.
- Every JSON file the app reads is validated by a test that loads the **shipped** file, as
  `RealContentTests.swift` does now.
- Content load failures render visibly as an error, never as a silent dark wall. Keep the existing
  `ContentLoader` behaviour.

**Git**
- The repository has no commits yet. Task 0 makes the baseline commit, and only once Matt says to commit.
- Commit messages use Conventional Commits and end with the session's attribution line.

## Review Focus

1. **Fast presses during a fade.** Pressing arrows faster than the 1.6 s cross-fade must end on the
   latest subject, with at most two lights drawn: the outgoing one and the incoming one. They must never
   pile up. *Test: Task 7, `rapidMovesEndOnLatestSubject`, plus Task 10's screenshot after 5 quick
   presses.*
2. **Hold Select versus Select.** A 1 s hold opens Settings and must not also toggle the story text.
   *Test: Task 13, `testHoldSelectOpensSettingsWithoutTogglingText`.*
3. **A narrow wall.** With a calibration that leaves under 14 in on both sides, the text goes over the
   lower edge of the tapestry and never off the frame. *Test: Task 4, `bothSidesNarrowFallsBackToLowerEdge`.*
4. **Left on overnight.** After 6 h without a press, the app hands the idle timer back. One press holds it
   again. *Test: Task 7, `awakePolicyReleasesAfterSixHoursAndResetsOnInput`.*
5. **Bad content.** If `unfold.json` names a subject that doesn't exist, or `glints.json` is empty, the
   content must fail to load with a message, not play a broken sequence or show no glints silently.
   *Test: Task 2, `unknownSubjectInUnfoldIsRejected`, and Task 3, `emptyGlintFileIsRejected`.*

---

## Track A: Code

### Task 0: Baseline commit (only with Matt's go-ahead)

**Files:** everything currently in `~/Developer/Wilderness`. `.gitignore` already excludes build output
and `refresh.conf`.

- [ ] **Step 1:** Confirm with Matt that committing is OK. Do not proceed without his yes.
- [ ] **Step 2:** Check the baseline is green:
  - `cd Packages/WildernessCore && swift test`: 35 tests pass.
  - The `CalibrationFlowUITests` command: 2 tests pass.
- [ ] **Step 3:**
  ```bash
  git add -A && git commit -m "chore: baseline prototype, calibration flow, icon, design docs"
  ```

### Task 1: Content schema for "more", and outlines filled from the estimates

**Files:**
- Modify: `Packages/WildernessCore/Sources/WildernessCore/Annotation.swift`
- Create: `scripts/import_outlines.py`
- Modify: `App/Content/annotations.json` (the `outline` and `geometrySource` fields only; no copy)
- Test: `Packages/WildernessCore/Tests/WildernessCoreTests/AnnotationTests.swift`, `RealContentTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum Testament: String, Codable, Sendable { case old, new }
  public enum Translation: String, Codable, Sendable, CaseIterable { case niv = "NIV", esv = "ESV", nlt = "NLT", dra = "DRA" }
  public enum Connection: String, Codable, Sendable { case inScripture, christianReading }
  public struct Verse: Codable, Equatable, Sendable { public var ref: String; public var text: String; public var testament: Testament; public var translation: Translation }
  public struct More: Codable, Equatable, Sendable { public var story: String; public var verses: [Verse]; public var connection: Connection; public var draft: Bool }
  // Annotation gains:  public var more: More?   (nil until the copy pass)
  public enum WordLimits { public static let short = 15, story = 25, verse = 20 }
  ```
  - `AnnotationLibrary.decode` additionally rejects:
    - a `more` with an empty story
    - a `more` with no verses
    - any verse with an empty `ref` or `text`
  - It does not enforce word limits. Those are shipped-file tests, so drafts can still load.

- [ ] **Step 1: Write the failing tests** in `AnnotationTests.swift`:
  - `decodesMoreWithVerses`: JSON with one annotation whose `more` has two verses, one `old`/`NIV` and one
    `new`/`ESV`. It decodes, and `more?.verses.map(\.testament) == [.old, .new]`.
  - `moreWithoutVersesIsRejected`: the same, with `"verses": []`. `decode` throws.
  - `annotationWithoutMoreStillDecodes`: today's shape, with no `more` key. It decodes, and `more == nil`.
- [ ] **Step 2:** Run `swift test --filter AnnotationTests`. Expected: compile failure, because `More` is
  undefined.
- [ ] **Step 3:** Add the types and `more` to `Annotation`, plus the validation above.
- [ ] **Step 4:** Run `swift test --filter AnnotationTests`. Expected: PASS.
- [ ] **Step 5: Write the failing shipped-file tests** in `RealContentTests.swift`:
  - `everyShippedSubjectHasAnOutline`: every annotation has a non-nil `outline` with at least 6 points.
  - `shippedShortLinesRespectTheWordLimit`: every `short` is at most `WordLimits.short` words, counted by
    whitespace.
  - `shippedMoreRespectsWordLimits`: for each annotation whose `more` is non-nil and `draft == false`:
    - the story is at most 25 words
    - each verse is at most 20 words
- [ ] **Step 6:** Run `swift test --filter RealContentTests`. Expected: `everyShippedSubjectHasAnOutline`
  fails.
- [ ] **Step 7:** Write `scripts/import_outlines.py`.
  - Input: `docs/reference/estimated-outlines.json`.
  - Map each point with `u=(x-11)/578, v=(y-10)/482`, rounded to 4 decimals and clamped to 0…1.
  - Write the result into the matching annotation's `outline` in `App/Content/annotations.json`.
  - Set `geometrySource` to `"met-reference-estimate"`.
  - Preserve key order and the 2-space indent.
  - Run it once.
- [ ] **Step 8:** Run `swift test`. Expected: all pass. If `shippedShortLinesRespectTheWordLimit` fails,
  stop and report the line to Matt. Do not edit copy.
- [ ] **Step 9:** Commit with the message `feat(content): verse schema and estimated subject outlines`.

### Task 2: Unfold script schema, timeline, and the draft `unfold.json`

**Files:**
- Create: `Packages/WildernessCore/Sources/WildernessCore/Unfold.swift`
- Create: `App/Content/unfold.json`
- Test: `Packages/WildernessCore/Tests/WildernessCoreTests/UnfoldTests.swift`, `RealContentTests.swift`

**Interfaces:**
- Consumes: `More`, `TextSide`, and `AnnotationLibrary` (Task 1).
- Produces:
  ```swift
  public struct UnfoldBeat: Codable, Equatable, Sendable {
      public var id: String; public var duration: Double
      public var light: [[String]]      // steps in order; each step lights these targets together; "whole" = whole tapestry
      public var textSide: TextSide; public var title: String; public var short: String
      public var more: More?; public var draft: Bool
  }
  public struct UnfoldScript: Sendable {
      public var beats: [UnfoldBeat]
      public static func decode(_ data: Data, library: AnnotationLibrary) throws -> UnfoldScript
      public func advance(_ p: UnfoldPlayback, by dt: Double) -> UnfoldPlayback?   // nil = finished
      public func next(_ p: UnfoldPlayback) -> UnfoldPlayback?                     // nil past the last beat
      public func previous(_ p: UnfoldPlayback) -> UnfoldPlayback                  // beat 0 restarts beat 0
      public func step(_ p: UnfoldPlayback) -> Int    // index into beats[p.beat].light; steps split the duration evenly
  }
  public struct UnfoldPlayback: Equatable, Sendable { public var beat: Int; public var elapsed: Double; public var paused: Bool
      public static let start = UnfoldPlayback(beat: 0, elapsed: 0, paused: false) }
  ```
  - `decode` throws when:
    - a target is neither `"whole"` nor an annotation id
    - any `duration` is ≤ 0
    - any `light` is empty
    - the total duration is outside 240…360 s
  - `advance` with `paused == true` returns the same playback.

- [ ] **Step 1: Write the failing tests** in `UnfoldTests.swift`. Use a 3-beat inline script (durations
  10, 20, 30; beat 1 has `light` `[["christ"],["angels"]]`) and the 3-annotation library from
  `ExploreStateTests`:
  - `advanceCarriesOverflowIntoTheNextBeat`: `advance(start, by: 12)` → `beat == 1`, `elapsed == 2`.
  - `advanceWhilePausedDoesNothing`.
  - `advancePastTheEndFinishes`: `advance(.init(beat: 2, elapsed: 29, paused: false), by: 5) == nil`.
  - `stepsSplitTheBeatEvenly`: in beat 1, `elapsed` 9.9 → step 0, and 10.1 → step 1.
  - `previousOnFirstBeatRestartsIt`, and `nextOnLastBeatFinishes`.
  - `unknownSubjectInUnfoldIsRejected`: `light` `[["unicorn"]]` → `decode` throws. (Review Focus 5)
  - `totalDurationMustBeAboutFiveMinutes`: a 3-beat script with a total of 60 s → throws. For the tests
    above, use a helper that bypasses only the total check (`UnfoldScript(beats:)`).
- [ ] **Step 2:** Run `swift test --filter UnfoldTests`. Expected: compile failure.
- [ ] **Step 3:** Implement `Unfold.swift`.
- [ ] **Step 4:** Run `swift test --filter UnfoldTests`. Expected: PASS.
- [ ] **Step 5:** Write `App/Content/unfold.json` with the eight beats of §5.3.
  - Ids: `eden`, `serpent`, `forty-years`, `forty-days`, `fed`, `peaceable`, `lion-dragon`, `rest-of-story`.
  - Each beat has `duration` 35 and `"draft": true`.
  - `light`:

    | Beat | `light` |
    |---|---|
    | `eden` | `[["whole"],["stag","fox","bear","lion"]]` |
    | `serpent` | `[["basilisk"]]` |
    | `forty-years` | `[["whole"]]` |
    | `forty-days` | `[["christ"]]` |
    | `fed` | `[["angels"]]` |
    | `peaceable` | `[["stag"],["fox"],["bear"],["lion"]]` |
    | `lion-dragon` | `[["lion"],["basilisk"]]` |
    | `rest-of-story` | `[["fragment"],["whole"]]` |

  - `title` = the §5.3 beat name, and `short` = `"Draft: <beat name>"`.
  - `more` is null. `textSide` is `left` for whole-piece beats; otherwise use the subject's `textSide`.
- [ ] **Step 6:** In `RealContentTests.swift`, add `shippedUnfoldDecodesAgainstShippedAnnotations`.
  Run it. Expected: PASS.
- [ ] **Step 7:** Commit with the message `feat(unfold): beat schema, timeline, draft arc`.

### Task 3: Glint scheduler, seeded random source, and `glints.json`

**Files:**
- Create: `Packages/WildernessCore/Sources/WildernessCore/Glints.swift`
- Create: `scripts/make_glints.py`, `scripts/tests/test_make_glints.py`, `App/Content/glints.json`
- Test: `Packages/WildernessCore/Tests/WildernessCoreTests/GlintTests.swift`, `RealContentTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct SplitMix64: RandomNumberGenerator, Sendable { public init(seed: UInt64); public mutating func next() -> UInt64 }
  public enum GlintStyle: String, Codable, Sendable { case thread, pinpoint }
  public struct GlintParams: Equatable, Sendable { public var meanInterval = 8.0; public var minGap = 1.5
      public var life: ClosedRange<Double> = 0.8...1.4; public var peak: ClosedRange<Double> = 0.5...0.85; public init() }
  public struct Glint: Equatable, Sendable { public var point: Point<ArtworkSpace>; public var start: Double
      public var life: Double; public var peak: Double; public var direction: Double  // +1 or -1, slide direction
      public func progress(at t: Double) -> Double        // 0...1 inside life, else outside
      public func intensity(at t: Double) -> Double }     // peak * sin²(π·progress), 0 outside life
  public struct GlintScheduler<R: RandomNumberGenerator> {
      public var params: GlintParams
      public init(points: [Point<ArtworkSpace>], params: GlintParams, rng: R, now: Double)
      public mutating func active(at now: Double) -> Glint?     // the one live glint, if any; schedules the next
      public mutating func fireNow(at now: Double) }            // used by the tuning screen
  public struct GlintPoints: Codable, Sendable { public var source: String; public var points: [Point<ArtworkSpace>]
      public static func decode(_ data: Data) throws -> GlintPoints }  // throws if empty or outside 0...1
  ```
  - Scheduling: the next start = the current glint's end + max(`minGap`, an exponential sample with mean
    `meanInterval`). The first glint is scheduled the same way, from `now`.

- [ ] **Step 1: Write the failing tests** in `GlintTests.swift`. Use a seeded `SplitMix64(seed: 7)` and
  50 points:
  - `neverTwoAtOnce`: sample `active(at:)` every 0.05 s over 3,600 s. Each new glint's `start` is at
    least the previous `start + life + minGap`.
  - `meanIntervalIsAboutEightSeconds`: over 20,000 s, the mean gap between starts is within 7.2…10.6 s.
    (The mean includes `life` and `minGap`; this range is wide on purpose.)
  - `intensityIsZeroAtEdgesAndPeaksInTheMiddle`: for a glint with `peak` 0.8, the intensity is 0 at the
    start and at the end, and 0.8 ± 1e-9 at the midpoint.
  - `glintsComeOnlyFromTheGivenPoints`.
  - `noPointsMeansNoGlints`.
  - `emptyGlintFileIsRejected`: `GlintPoints.decode` of `{"source":"x","points":[]}` throws. (Review
    Focus 5)
- [ ] **Step 2:** Run `swift test --filter GlintTests`. Expected: compile failure.
- [ ] **Step 3:** Implement `Glints.swift`. Sample the exponential as `-mean * log(1 - u)` with `u` in
  [0, 1).
- [ ] **Step 4:** Run `swift test --filter GlintTests`. Expected: PASS.
- [ ] **Step 5: Write the failing Python test** `scripts/tests/test_make_glints.py`, against
  `select_catch_points(lum: np.ndarray) -> list[tuple[int, int]]`:
  - On a 40×40 array of 0.2 with five isolated 1.0 pixels, it returns exactly those five, because the
    minimum of 40 is capped by the candidates.
  - On a flat array, it returns `[]`.
- [ ] **Step 6:** Run `python3 -m pytest scripts/tests -q`. Expected: FAIL (module not found).
- [ ] **Step 7:** Implement `scripts/make_glints.py`, per §4.1:
  - Candidates: luminance above the 60th percentile and above the local 7×7 mean.
  - Keep the top 6% by (luminance − local mean), with a minimum of 40 or all candidates if fewer.
  - CLI: `make_glints.py <image> <out.json>`.
    - Crop 11 px from the left and right and 10 px from the top and bottom of the 600×502 image.
    - Normalise to 0…1 and round to 4 decimals.
    - Write `{"source": "<image filename>", "points": [[u,v], …]}`.
- [ ] **Step 8:** Run `python3 -m pytest scripts/tests -q` (PASS). Then run
  `python3 -I scripts/make_glints.py docs/reference/met-11.53-600x502.jpg App/Content/glints.json` and
  print the point count. Expected: 40 or more.
- [ ] **Step 9:** Add `shippedGlintPointsDecode` to `RealContentTests.swift`. Run `swift test`.
  Expected: all pass.
- [ ] **Step 10:** Commit with the message `feat(glints): scheduler, seeded rng, catch-point script and data`.

### Task 4: Wall geometry and the text column

**Files:**
- Create: `Packages/WildernessCore/Sources/WildernessCore/WallGeometry.swift`
- Test: `Packages/WildernessCore/Tests/WildernessCoreTests/WallGeometryTests.swift`

**Interfaces:**
- Consumes: `Calibration` (existing), `TextSide`.
- Produces:
  ```swift
  public enum WallGeometry {
      public static func pixelsPerInch(_ c: Calibration, artworkWidthInches: Double = 60) -> Double
      public static func wallInches(_ c: Calibration, side: TextSide, artworkWidthInches: Double = 60) -> Double }
  public enum ColumnPosition: Equatable, Sendable { case beside(TextSide), overLowerEdge }
  public struct ColumnPlacement: Equatable, Sendable { public var position: ColumnPosition; public var widthInches: Double }
  public enum TextColumnLayout {
      public static let maxWidth = 19.0, minWidth = 14.0, gap = 3.0, margin = 1.0
      public static func place(preferred: TextSide, calibration: Calibration) -> ColumnPlacement }
  ```
  - `pixelsPerInch`: the mean of the top and bottom edge lengths in output pixels, ÷ 60.
  - `wallInches(.left)`: `min(c[0].x, c[3].x) * width` px ÷ ppi.
  - `wallInches(.right)`: `(1 - max(c[1].x, c[2].x)) * width` px ÷ ppi.
  - Width on a side = `min(maxWidth, wall - gap - margin)`. Use the preferred side if the width there is
    at least `minWidth`, otherwise the other side, otherwise `.overLowerEdge` with `maxWidth`.

- [ ] **Step 1: Write the failing tests:**
  - `defaultCalibrationGivesAbout17PixelsPerInch`: `defaultFor(1.2, 1920×1080)` → 17.28 ± 0.01.
  - `defaultCalibrationLeavesRoomBeside`: `place(.right, default)` → `.beside(.right)`, width 19.
  - `narrowPreferredSideUsesTheOtherSide`: corners with x 0.30…0.95 at 1080p, preferred `.right` →
    `.beside(.left)`.
  - `bothSidesNarrowFallsBackToLowerEdge`: corners with x 0.05…0.95 → `.overLowerEdge`. (Review Focus 3)
  - `widthShrinksToFitTheWall`: a case where the right wall is exactly 18 in → width 14.
- [ ] **Step 2:** Run `swift test --filter WallGeometryTests`. Expected: compile failure.
- [ ] **Step 3:** Implement `WallGeometry.swift`.
- [ ] **Step 4:** Run `swift test --filter WallGeometryTests`. Expected: PASS.
- [ ] **Step 5:** Commit with the message `feat(layout): wall geometry and adaptive text column`.

### Task 5: Tuning values and the tuning session

**Files:**
- Create: `Packages/WildernessCore/Sources/WildernessCore/Tuning.swift`
- Test: `Packages/WildernessCore/Tests/WildernessCoreTests/TuningTests.swift`

**Interfaces:**
- Consumes: `GlintStyle`, `GlintParams`, `NudgeDirection`.
- Produces:
  ```swift
  public struct Tuning: Codable, Equatable, Sendable {
      public var subjectStrength = 0.44, baseWash = 0.16, exploreWashFactor = 0.45
      public var glintMeanInterval = 8.0, glintBrightness = 1.0, glintSizeInches = 0.06
      public var glintStyle: GlintStyle = .thread
      public static let defaults = Tuning(); public static let storageKey = "tuning.v1"
      public var glintParams: GlintParams }   // meanInterval from glintMeanInterval, rest default
  public enum TuningRow: Int, CaseIterable, Sendable { case subjectStrength, baseWash, glintFrequency, glintBrightness, glintSize, glintStyle, resetDefaults }
  public struct TuningSession: Sendable {
      public private(set) var tuning: Tuning; public private(set) var row: TuningRow
      public init(tuning: Tuning)
      public mutating func handle(_ d: NudgeDirection)   // up/down: row; left/right: change value
      public mutating func select()                      // on .resetDefaults: tuning = .defaults
      public var rowLabel: String }                      // e.g. "Glints · now and then"
  ```
  - Ranges and steps:

    | Row | Change | Range |
    |---|---|---|
    | strength | ±0.02 | 0…1 |
    | wash | ±0.01 | 0…0.5 |
    | frequency | cycles 16 → 8 → 4 s ("rare" / "now and then" / "often"); right = more often | stops at the ends |
    | brightness | ±0.05 | 0.2…1 |
    | size | ±0.01 in | 0.02…0.2 |
    | style | left or right toggles | |

  - Values are clamped, never wrapped (except style).

- [ ] **Step 1: Write the failing tests:**
  - `defaultsMatchTheSpec`, which asserts every value in the Global Constraints table.
  - `rightRaisesStrengthAndClampsAtOne`.
  - `frequencyStepsRareNowAndThenOften`: from 8, right → 4; right again → 4; left twice → 16.
  - `resetRestoresDefaults`.
  - `tuningRoundTripsThroughJSON`.
- [ ] **Step 2:** Run `swift test --filter TuningTests`. Expected: compile failure.
- [ ] **Step 3:** Implement `Tuning.swift`.
- [ ] **Step 4:** Run `swift test --filter TuningTests`. Expected: PASS.
- [ ] **Step 5:** Commit with the message `feat(tuning): tunable light values and remote tuning session`.

### Task 6: Mode machine and the remote map

**Files:**
- Create: `Packages/WildernessCore/Sources/WildernessCore/Modes.swift`
- Test: `Packages/WildernessCore/Tests/WildernessCoreTests/ModeTests.swift`

**Interfaces:**
- Consumes:
  - `ExploreState.handle` (existing; Explore movement and persistent expansion)
  - `UnfoldScript` and `UnfoldPlayback` (Task 2)
  - `AnnotationLibrary`
- Produces:
  ```swift
  public enum SettingsItem: Int, CaseIterable, Sendable { case calibrate, tune, pattern, about }
  public enum Mode: Equatable, Sendable {
      case stillness, explore(id: String, expanded: Bool), unfold(UnfoldPlayback)
      case settings(focus: SettingsItem), calibrating, tuning, pattern, about }
  public enum AppInput: Sendable { case move(NudgeDirection), select, holdSelect, playPause, back }
  public enum ModeEffect: Equatable, Sendable { case exitApp }
  public struct ModeMachine: Sendable {
      public static let exploreIdleTimeout = 45.0
      public private(set) var mode: Mode; public private(set) var lastInputAt: Double
      public init(calibrated: Bool, now: Double)          // .calibrating when not calibrated, else .stillness
      public mutating func handle(_ input: AppInput, now: Double, library: AnnotationLibrary, script: UnfoldScript) -> ModeEffect?
      public mutating func tick(now: Double, dt: Double, script: UnfoldScript)  // Explore idle → stillness; Unfold advance; finish → stillness
      public mutating func finishCalibration() }           // .calibrating → .stillness
  ```
  - Behaviour is exactly the §5.5 table. Also:
    - In `.calibrating` and `.tuning`, `handle` only updates `lastInputAt`, except that Back in `.tuning`
      returns to `.settings(focus: .tune)`. The app routes those presses to `CalibrationSession` and
      `TuningSession`.
    - Back from `.pattern` or `.about` returns to `.settings` with that item focused.
    - Back from `.settings` → `.stillness`.
    - Back in `.stillness` returns `.exitApp`.
  - Every `handle` call sets `lastInputAt = now`.

- [ ] **Step 1: Write the failing tests.** Use the 3-annotation library and the 3-beat script helper from
  Task 2:
  - `arrowFromStillnessExploresChrist`.
  - `selectInStillnessDoesNothing`.
  - `playPauseFromStillnessAndExploreStartsUnfoldAtTheBeginning`.
  - `playPauseInUnfoldPausesAndResumes`, and `leftRightStepBeats`.
  - `backFromUnfoldExploreAndSettingsReturnsToStillness`.
  - `backInStillnessExitsTheApp`.
  - `holdSelectOpensSettingsFromStillnessAndExploreButNotUnfold`.
  - `settingsFocusMovesAndSelectOpensEachItem`: each of the four items opens `.calibrating` / `.tuning` /
    `.pattern` / `.about`.
  - `backFromTuningReturnsToSettingsOnTune`.
  - `exploreReturnsToStillnessAfter45SecondsIdle`: no tick at 44.9 s; a tick at 45.1 s → `.stillness`.
  - `unfoldThatFinishesFallsIntoStillness`.
  - `rapidMovesEndOnLatestSubject`: five moves 0.1 s apart → the subject reached by the fifth. (Review
    Focus 1, logic half)
  - `uncalibratedStartsCalibratingAndFinishGoesToStillness`.
- [ ] **Step 2:** Run `swift test --filter ModeTests`. Expected: compile failure.
- [ ] **Step 3:** Implement `Modes.swift`. Delegate Explore moves and Select to `ExploreState.handle`.
- [ ] **Step 4:** Run `swift test`. Expected: all pass.
- [ ] **Step 5:** Commit with the message `feat(modes): stillness/explore/unfold/settings state machine`.

### Task 7: Awake policy

**Files:**
- Modify: `Packages/WildernessCore/Sources/WildernessCore/Modes.swift`
- Test: `ModeTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum AwakePolicy {
      public static let releaseAfter = 6.0 * 3600
      public static func keepAwake(lastInputAt: Double, now: Double) -> Bool }  // now - lastInputAt < releaseAfter
  ```

- [ ] **Step 1:** Write `awakePolicyReleasesAfterSixHoursAndResetsOnInput`. Cases:
  - At 5 h 59 m → true.
  - At 6 h 1 m → false.
  - After `ModeMachine.handle` at 6 h 1 m, `keepAwake(lastInputAt: machine.lastInputAt, now: 6h1m)` →
    true. (Review Focus 4)
- [ ] **Step 2:** Run it. Expected: compile failure.
- [ ] **Step 3:** Implement it.
- [ ] **Step 4:** Run it. Expected: PASS.
- [ ] **Step 5:** Commit with the message `feat(modes): hand the idle timer back after 6 h without input`.

### Task 8: Fonts and typography

**Files:**
- Create: `App/Fonts/` (Cormorant Garamond Regular and Italic, EB Garamond Regular and Italic, plus each
  family's `OFL.txt`)
- Create: `App/Typography.swift`
- Modify: `App/WildernessApp.swift`

**Interfaces:**
- Produces:
  ```swift
  enum Typography {
      static func registerBundledFonts()             // CTFontManagerRegisterFontsForURL for each .ttf in App/Fonts
      static func title(_ size: CGFloat) -> Font     // Cormorant Garamond
      static func text(_ size: CGFloat, italic: Bool = false) -> Font  // EB Garamond
  }
  ```
  - Sizes in canvas units (§6.1): title 40; short 22 italic; story 19; verse 20; citation 13 (tracked 1.5,
    opacity 0.55).

- [ ] **Step 1:** Ask Matt's permission to download the two families from Google Fonts. State the file
  names, the source, and the sizes. Do not download without it.
- [ ] **Step 2:** Add the fonts and `Typography.swift`, and call `registerBundledFonts()` in
  `WildernessApp.init`.
- [ ] **Step 3: Verification (not unit-testable: font rendering).**
  - Build, run in the Simulator, and screenshot Explore on Christ.
  - Expected: the title is visibly Cormorant (high contrast, small x-height) and not the system serif.
  - Log a registration error, if any. Expected: none.
- [ ] **Step 4:** Commit with the message `feat(type): bundle Cormorant and EB Garamond (OFL)`.

### Task 9: Light layer (base wash and feathered subject light)

**Files:**
- Create: `App/LightLayer.swift`
- Modify: `App/ExploreView.swift` (remove `lightPool`)

**Interfaces:**
- Consumes: `Annotation.outline` (Task 1), `Tuning` (Task 5), and `Mode` (Task 6).
- Produces:
  ```swift
  struct LightLayer: View {   // drawn inside MappedCanvas, in canvas units
      let library: AnnotationLibrary; let tuning: Tuning
      let targets: Set<String>   // annotation ids and/or "whole"; empty = stillness
      let exploring: Bool }      // true → wash × exploreWashFactor outside targets
  ```
  - The wash covers the canvas at `baseWash`, times `exploreWashFactor` while exploring.
  - Each target outline is filled at `subjectStrength` and feathered by 44 units.
  - `"whole"` raises the wash to `subjectStrength × 0.5` (my call: whole-piece beats are gentler than one
    subject).
  - Changes animate with ease-in-out:
    - 1.6 s between targets
    - 3 s from empty to non-empty
    - 6 s back to empty
  - Rendering approach is the builder's call. Rasterise each feathered mask once and cache it; don't
    re-blur every frame.

- [ ] **Step 1: Verification (not unit-testable: visual).**
  - Take Simulator screenshots of Explore on Christ, angels, and basilisk.
  - Expected: soft light that follows each subject's shape, with no hard edge visible at 100% zoom, and
    the rest of the tapestry area slightly darker than in Stillness.
- [ ] **Step 2: Verification (Review Focus 1, visual half).**
  - Press right five times quickly via XCUIRemote in a throwaway UI test, then screenshot.
  - Expected: at most two lit regions.
- [ ] **Step 3: Performance check.**
  - Leave the Explore screen running in the Simulator for 2 min with the Xcode debug gauge open.
  - Expected: no steady CPU climb. On-device check later.
- [ ] **Step 4:** Commit with the message `feat(light): feathered subject light and base wash`.

### Task 10: Glint layer

**Files:**
- Create: `App/GlintLayer.swift`

**Interfaces:**
- Consumes: `GlintScheduler`, `GlintPoints`, `Tuning.glintParams`, and `WallGeometry.pixelsPerInch`
  (Tasks 3–5).
- Produces:
  ```swift
  struct GlintLayer: View {   // inside MappedCanvas
      let points: GlintPoints; let tuning: Tuning; let calibration: Calibration
      let demo: Bool }        // tuning screen: fireNow every 2 s
  ```
  - Drawn with `TimelineView(.animation)` and `Canvas`.
  - Core radius = max(`glintSizeInches`, half a projector pixel ÷ ppi) × 20 units. Peak opacity =
    `intensity × glintBrightness`.
  - **Thread style:** an ellipse scaled 3:1 horizontally, sliding `direction × (progress − 0.5) × 0.35 in`.
  - **Pinpoint style:** a radial gradient with radius 2.2 × core.
  - The scheduler is seeded from the system clock.

- [ ] **Step 1: Verification (not unit-testable: visual).**
  - Launch with `-glintDemo YES` (a debug-only launch argument that sets `demo`), then take a burst of 10
    screenshots 0.2 s apart.
  - Expected: one ivory glint visible in some frames, never two, with nothing else lit.
- [ ] **Step 2:** Commit with the message `feat(glints): draw rare glints in Stillness`.

### Task 11: Wall text (Explore and Unfold)

**Files:**
- Create: `App/WallText.swift`
- Modify: `App/ExploreView.swift` (remove the old `text(for:)` and `evidenceLabel`)

**Interfaces:**
- Consumes: `Typography` (Task 8), `TextColumnLayout` (Task 4), and `More` (Task 1).
- Produces:
  ```swift
  struct WallText: View {   // inside MappedCanvas
      let title: String; let short: String; let more: More?; let fallbackExtended: String?
      let expanded: Bool; let placement: ColumnPlacement; let anchorY: Double }  // anchorY 0...1 in artwork
  ```
  - Order: title, short, and then when expanded:
    - the story
    - verses (Old Testament first), each followed by `"<ref> · <translation.rawValue>"`
  - If `more == nil` and `fallbackExtended != nil`, the expanded state shows the extended text in the
    story style. This is temporary until the copy pass.
  - Placement:
    - `.beside`: next to the tapestry with a 3 in (60 units) gap, column width `widthInches × 20`.
    - `.overLowerEdge`: inside the canvas, at the bottom, inset 1 in.
  - Fades: out 0.6 s, in 1.0 s, starting after the light has had 1.0 s to settle.

- [ ] **Step 1: Verification (not unit-testable: visual).** Take Simulator screenshots of:
  - Christ, collapsed and expanded.
  - The basilisk expanded, with a temporary local edit adding a sample `more` with two verses. Revert it
    afterwards.
  - Expected: no uppercase label, verses under the story, citations small, and nothing off the frame.
- [ ] **Step 2:** Run a forced narrow calibration via `-calibration.v1` with a JSON whose corners span
  x 0.05…0.95, and screenshot. Expected: the text sits over the lower edge of the tapestry.
- [ ] **Step 3:** Commit with the message `feat(text): wall text with story, verses, adaptive column`.

### Task 12: Unfold view

**Files:**
- Create: `App/UnfoldView.swift`

**Interfaces:**
- Consumes:
  - `UnfoldScript.step` and `UnfoldPlayback` (Task 2)
  - `LightLayer` (Task 9)
  - `WallText` (Task 11)
- Produces: `struct UnfoldView: View { let script: UnfoldScript; let playback: UnfoldPlayback; let library: AnnotationLibrary; let tuning: Tuning; let calibration: Calibration }`
  - The view feeds `LightLayer` with the targets of `step(playback)`.
  - It shows `WallText` for the beat, expanded when `more` is present.
  - Pausing freezes both. A small "Paused" line (citation style) sits under the text while paused.

- [ ] **Step 1: Verification (not unit-testable: visual).**
  - Start Unfold and take screenshots at 2 s, 40 s, and 75 s.
  - Expected:
    - 2 s: beat 1, whole wash rising.
    - 40 s: beat 2, basilisk lit.
    - 75 s: beat 3, whole tapestry.
- [ ] **Step 2:** Commit with the message `feat(unfold): play the arc on the wall`.

### Task 13: Root wiring, Settings, tuning screen, About

**Files:**
- Modify: `App/RootView.swift` (replace the `calibrating`, `showPattern`, and `explore` `@State` with one
  `ModeMachine`)
- Create: `App/SettingsView.swift`, `App/TuningStore.swift`
- Create: `App/Content/notices.json` (`{"notices": {}}` until Track B fills it)
- Create: `UITests/ExperienceFlowUITests.swift`

**Interfaces:**
- Consumes: Tasks 2–12, and `CalibrationView` / `CalibrationSession` (existing).
- Produces:
  - `TuningStore: ObservableObject` (`@Published tuning`, persisted under `Tuning.storageKey`, decode
    failure → defaults, logged).
  - `SettingsView` (list, tuning rows, pattern, About).
  - `RootView` behaviour:
    - A 1 s `Timer` calls `machine.tick`, and sets `UIApplication.shared.isIdleTimerDisabled =
      AwakePolicy.keepAwake(...)`.
    - `onExitCommand` is nil only in `.stillness`, so tvOS can leave the app.
    - `GlintLayer` is drawn only in `.stillness`, and in `.tuning` with `demo: true`.
    - `LightLayer` targets:
      - `.explore`: its id.
      - `.unfold`: from `UnfoldView`.
      - `.tuning`: `["christ"]`.
      - Otherwise empty.
    - `onLongPressGesture(minimumDuration: 1)` sends `.holdSelect`.
    - Remote presses go to `CalibrationSession` or `TuningSession` while in those modes.
  - About lists `notices.json` entries and the line "Image: The Metropolitan Museum of Art, 11.53,
    public domain".
  - If any shipped verse uses NIV, ESV, or NLT, About must have its notice (test below).
- **Accessibility labels for the UI tests:**
  - The Settings rows' visible text is "Calibrate", "Tune light", "Alignment pattern", and "About".
  - The Explore title is the annotation title, and the story text is accessible.

- [ ] **Step 1: Write the failing UI tests** in `ExperienceFlowUITests.swift`. Launch with a saved default
  calibration passed via `-calibration.v1`, as an old-style plist data literal: the hex of the JSON from
  `Calibration.defaultFor`, written as `<7b22…>`. The tests encode it at runtime:
  - `testArrowWakesExploreOnChrist`: press right → `staticTexts["Christ"]` exists.
  - `testSelectTogglesStoryAndItPersistsAcrossSubjects`: right, select → the extended/story text exists;
    then up → the angels' expanded text exists.
  - `testHoldSelectOpensSettingsWithoutTogglingText`: in Explore, hold Select for 1.2 s
    (`XCUIRemote.shared.press(.select, forDuration: 1.2)`) → "Calibrate" exists. Then Back, Back → no
    story text is visible. (Review Focus 2)
  - `testPlayPauseStartsUnfold`: play/pause → `staticTexts["Eden: creatures at peace"]` exists.
  - `testBackReturnsToStillness`: right, then Back → "Christ" no longer exists, and the app is still in
    the foreground.
- [ ] **Step 2:** Run them. Expected: FAIL, because these elements don't exist in today's `RootView`.
- [ ] **Step 3:** Implement the wiring, `SettingsView`, and `TuningStore`.
- [ ] **Step 4:** Run `ExperienceFlowUITests` and `CalibrationFlowUITests`. Expected: all pass.
- [ ] **Step 5:** Add `shippedVersesHaveTheirTranslationNotice` to `RealContentTests` (reads
  `notices.json`). Run `swift test`. Expected: PASS.
- [ ] **Step 6: Verification.** Take screenshots of Settings, the Tune light screen (expect a demo glint
  every 2 s and Christ lit), and About.
- [ ] **Step 7:** Commit with the message `feat(app): mode wiring, settings, live tuning, about`.

### Task 14: README and final check

**Files:**
- Modify: `README.md` (the Remote section becomes the §5.5 table; add Content: `glints.json`,
  `unfold.json`, `notices.json`, `scripts/`)

- [ ] **Step 1:** Update the README.
- [ ] **Step 2:** Run `swift test`, the full UI test suite, and `python3 -m pytest scripts/tests -q`.
  Expected: all pass. Report the counts.
- [ ] **Step 3:** Commit with the message `docs: remote map and content files`.

---

## Track B: Copy (Matt's approval gate; runs alongside Track A after Task 2)

These are writing tasks, not code. Their gate is Matt's line-by-line review, not a test. The shipped-file
tests from Tasks 1 and 13 enforce the word limits and notices.

- **B1. Subject copy.** Draft `short` and `more` for all eight subjects to §7.
  - Verify every verse word for word against its translation's published text.
  - Choose NIV, ESV, or NLT per verse by clarity, and use DRA only where it explains the painting.
  - Run the anti-AI-writing pass (§7 list), then hand the drafts to Matt.
  - On approval, set `draft: false`.
- **B2. Unfold copy.** Same process for the eight beats, replacing the `"Draft: …"` text.
- **B3. Notices.** Fetch the current permission terms and the exact copyright notice text from Biblica
  (NIV), Crossway (ESV), and Tyndale (NLT). Put them in `App/Content/notices.json` verbatim. Report any
  term that the app's use would break.
