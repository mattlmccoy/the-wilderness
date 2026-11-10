# The Wilderness

A native tvOS projection-mapping installation for a 60 × 50 in woven tapestry of
Moretto da Brescia's *Christ in the Wilderness*, projected by an XGIMI Elfin Flip (1080p, 400 lm)
driven by an Apple TV.

## Layout

```
project.yml                 XcodeGen spec (run `xcodegen generate` after adding files)
App/                        tvOS app (SwiftUI)
  RootView.swift            remote → ModeMachine; draws the current mode over one LightLayer
  LightLayer.swift          base wash + feathered subject light, with fades
  GlintLayer.swift          rare glints in Stillness
  WallText.swift            title, short line, story and verses on the wall
  ExploreView.swift         Explore's text; ContentLoader (all bundled JSON)
  UnfoldView.swift          Unfold's text and light targets
  SettingsView.swift        hidden Settings list, Tune light, About
  TuningStore.swift         persists tuning on the Apple TV
  Typography.swift          bundled Cormorant Garamond / EB Garamond (App/Fonts, OFL)
  CalibrationView.swift     four-corner calibration with the Siri Remote
  MappedCanvas.swift        draws in artwork coordinates, warps with one homography
  CalibrationStore.swift    persists calibration on the Apple TV
  Palette.swift             colours and artwork dimensions
Packages/WildernessCore/    pure Swift, unit-tested on the Mac
  CoordinateSpaces.swift    typed spaces: Artwork, Projector, Camera, Canvas, Screen
  Homography.swift          4-point solve, inverse, composition, SwiftUI conversion
  Calibration.swift         saved profile, validity, remote corner editing
  CalibrationSession.swift  calibration screen flow: corners → review → save / cancel
  Modes.swift               Stillness / Explore / Unfold / Settings state machine; awake policy
  Unfold.swift              Unfold beats and timeline
  Glints.swift              glint scheduler, seeded random source, glint points
  WallGeometry.swift        pixels per inch, wall beside the tapestry, text column placement
  Tuning.swift              tunable light values and the tuning screen's logic
  LightTiming.swift         fade durations
scripts/
  import_outlines.py        estimated outlines → annotations.json
  make_glints.py            reference image → glints.json (tests in scripts/tests)
docs/                       brief, design spec, build plan, round-3 light study, reference images
```

## Coordinate spaces

| Space | Meaning | Units |
|---|---|---|
| `ArtworkSpace` | the woven image; annotations live here | normalized 0…1 |
| `ProjectorSpace` | the full projector frame | normalized 0…1 |
| `CameraSpace` | an iPhone calibration photo (later) | normalized 0…1 |
| `CanvasSpace` | the SwiftUI layer the artwork is drawn in | points |
| `ScreenSpace` | the full-screen tvOS view | points |

A `Homography<From, To>` can only be applied to points of `From` and composed with matching
spaces, so mixing spaces is a compile error. Calibration stores the tapestry's four corners in
`ProjectorSpace`; the renderer composes `Screen ← Projector ← Artwork ← Canvas` into one matrix.

## Tests

```bash
cd Packages/WildernessCore && swift test
```

```bash
xcodebuild test -project Wilderness.xcodeproj -scheme Wilderness -destination 'platform=tvOS Simulator,name=Apple TV 4K (4th generation) (at 1080p)' CODE_SIGNING_ALLOWED=NO
```

```bash
python3 -m pytest scripts/tests -q
```

`Packages/WildernessCore/test.sh` runs the core tests with only the Command Line Tools installed.

## One-time Mac setup

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
```

## Running on the Apple TV

1. Apple TV: Settings → Remotes and Devices → Remote App and Devices (keep this screen open).
2. Mac: open `Wilderness.xcodeproj`, Window → Devices and Simulators → pair the Apple TV.
3. Select the Wilderness target → Signing & Capabilities → choose your Apple ID team.
4. Pick the Apple TV as the run destination and press Run.

A free Apple ID signs builds for 7 days; a paid developer account ($99/yr) makes them last a year
and allows TestFlight.

## Projector settings (important)

- Turn **off** auto keystone / "auto correction on movement" after setup. The app's calibration does
  the geometric correction; the projector re-warping on its own would silently break alignment.
- Leave digital keystone neutral if possible; the app's homography replaces it.
- Recalibrate if the Apple TV's overscan or output resolution setting changes.

## Remote

| Where | Arrows | Select | Hold Select (1 s) | Play/Pause | ‹ Back |
|---|---|---|---|---|---|
| Stillness | Explore (Christ) | nothing | Settings | Start Unfold | Leave the app |
| Explore | Move to the nearest subject that way | Story and verses on/off (stays open as you move) | Settings | Start Unfold | Stillness |
| Unfold | ← → previous / next beat | nothing | nothing | Pause / resume | Stillness |
| Settings | ↑ ↓ choose | Open (Show painting: on/off) | | | Close |
| Tune light | ↑ ↓ choose · ← → change | Reset (on its row) | | | Back to Settings |
| Calibration | Move the corner | Next corner → review → save | | Coarse / fine | Cancel (first setup: leave the app) |

Settings → **Show painting** projects the painting under everything (debugging only; remembered until
switched off). Explore, Settings and About return to Stillness after 45 s without a press; Tune light,
the alignment pattern and a paused Unfold after 5 min. While the app is open the Apple TV's
screensaver is held off; after 6 h without a press it is allowed to sleep again.

## Content

All of it is data, validated by tests that load the shipped files:

- `App/Content/annotations.json`: each subject's text, evidence class, anchor, outline, and (after the
  copy pass) `more`: one line of story plus Old and New Testament verses. Outlines are rough estimates
  from the Met's reference image (`geometrySource: met-reference-estimate`) until traced on a photo of
  the tapestry.
- `App/Content/unfold.json`: the eight beats of Unfold (draft text until the copy pass).
- `App/Content/glints.json`: where glints may appear; regenerate with
  `python3 -I scripts/make_glints.py docs/reference/met-11.53-600x502.jpg App/Content/glints.json`.
- `App/Content/notices.json`: Bible translation copyright notices (NIV, ESV, NLT), shown in
  Settings → About. A test fails if a quoted translation has no notice.

Wall copy is reviewed and approved line by line by Matt before it ships.

## Visual checks

`UITests/ScreenshotTour.swift` drives the remote and saves screenshots. It skips unless a folder is given:

```bash
TEST_RUNNER_SCREENSHOT_DIR=/path/to/folder xcodebuild test -project Wilderness.xcodeproj -scheme Wilderness -destination 'platform=tvOS Simulator,name=Apple TV 4K (4th generation) (at 1080p)' -only-testing:WildernessUITests/ScreenshotTour CODE_SIGNING_ALLOWED=NO
```

## Refresh (free Apple ID, 7-day signing)

`scripts/refresh.sh` rebuilds and reinstalls daily via launchd (`scripts/com.mattmccoy.wilderness.refresh.plist`).
Not yet enabled: needs `scripts/refresh.conf` (TEAM_ID, DEVICE_ID) and one supervised run.
