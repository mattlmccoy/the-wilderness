# The Wilderness

A native tvOS projection-mapping installation for a 60 × 50 in woven tapestry of
Moretto da Brescia's *Christ in the Wilderness*, projected by an XGIMI Elfin Flip (1080p, 400 lm)
driven by an Apple TV.

## Layout

```
project.yml                 XcodeGen spec (run `xcodegen generate` after adding files)
App/                        tvOS app (SwiftUI)
  RootView.swift            artwork mode ⇄ calibration mode
  CalibrationView.swift     four-corner calibration with the Siri Remote
  MappedCanvas.swift        draws in artwork coordinates, warps with one homography
  CalibrationStore.swift    persists calibration on the Apple TV
  Palette.swift             colours and artwork dimensions
Packages/WildernessCore/    pure Swift, unit-tested on the Mac
  CoordinateSpaces.swift    typed spaces: Artwork, Projector, Camera, Canvas, Screen
  Homography.swift          4-point solve, inverse, composition, SwiftUI conversion
  Calibration.swift         saved profile, validity, remote corner editing
  CalibrationSession.swift  calibration screen flow: corners → review → save / cancel
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
Packages/WildernessCore/test.sh
```

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

Dark wall: **arrows** wake Explore on Christ · **Play/Pause** registration pattern ·
**hold Select (1 s)** calibration · **Menu** returns to the Apple TV home screen.
Explore: **arrows** move the light to the nearest detail that way · **Select** shows or hides the longer text (it stays open as you move between details) · **‹ Back** back to dark.
Calibration: **arrows** move the selected corner · **Select** next corner; after the fourth, a review step where **Select** saves and **‹ Back** returns to adjusting · **Play/Pause** coarse/fine · **‹ Back** while adjusting cancels (on first setup it leaves the app).

## Content

`App/Content/annotations.json` holds every detail's text, evidence label, and position.
Positions are currently estimated from the Met's reference image (`geometrySource: met-reference-estimate`);
outlines are empty until traced on a photo of the tapestry. A test validates the shipped file and checks every
detail is reachable with the remote.

Evidence labels: Documented · Christian tradition · A likely reading · Conjecture.

## Refresh (free Apple ID, 7-day signing)

`scripts/refresh.sh` rebuilds and reinstalls daily via launchd (`scripts/com.mattmccoy.wilderness.refresh.plist`).
Not yet enabled: needs `scripts/refresh.conf` (TEAM_ID, DEVICE_ID) and one supervised run.
