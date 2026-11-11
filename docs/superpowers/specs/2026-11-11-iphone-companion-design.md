# iPhone companion — design and plan (approved by Matt, 2026-11-11)

## Intent
The phone is Matt's (and his wife's) **hand on the piece**: direct, quiet, never the main event. Guests keep
the Siri Remote, which keeps working exactly as now. Free Apple ID signing means guests cannot install it.

## Phase 1 (this plan)
1. **The painting**: painting full-width with Matt's traced outlines faint; tap a figure → the wall goes
   straight to it in Explore. Buttons: Unfold, Context, Play/Pause, Back.
2. **Read along**: whatever the wall shows, larger on the phone (title, short line, story, verses with
   citations), following the wall live. Licensed verse text comes only from the Apple TV's copy.
3. **Settings** (⚙︎): sliders for light on figures, edge line, background wash, glint brightness/size;
   switches for sound and show painting. Changes appear on the wall live and are saved on the Apple TV.

Out of scope: guest installs, accounts, internet, multiple Apple TVs, widgets, Watch. Phase 2 (later):
camera-assisted calibration.

## How (my calls)
- Same Xcode project (XcodeGen), new iOS target `WildernessPhone`, sharing `WildernessCore`.
- Local network only: the Apple TV advertises Bonjour `_wilderness._tcp` (Network.framework `NWListener`);
  the phone browses (`NWBrowser`) and connects. Messages are newline-delimited JSON.
- Protocol and all decisions live in the core package and are unit-tested:
  - `PhoneCommand` (phone → TV): `go(.explore(id))`, `go(.unfold)`, `go(.context)`, `playPause`, `back`,
    `setTuning(Tuning)`, `setSound(Bool)`, `setShowPainting(Bool)`, `hello`.
  - `WallSnapshot` (TV → phone): wayfinding header, title, short, story, verses (text + citation), the
    selected subject id, tuning, sound, showPainting.
  - `LineFramer`: splits a byte stream into messages (partial reads, several per read).
  - `ModeMachine` gains `AppInput.go(Destination)` so the phone can jump straight to a figure/mode.
- The phone bundles painting.jpg and annotations.json (outlines, ids) — no licensed text in its bundle.
- tvOS Info.plist: `NSBonjourServices`; iOS: `NSBonjourServices` + `NSLocalNetworkUsageDescription`.

## Tasks (red-green each)
1. Core `AppInput.go`: tests (from rest/menu/explore/context/unfold → target; during intro → target;
   while calibrating/tuning → ignored), then implement.
2. Core protocol: Codable round-trip tests for every command; `LineFramer` tests (split, partial, many).
3. Core `WallSnapshot.make(mode:content…)`: tests for explore (expanded and not), unfold beat, context
   page, rest/menu (no text).
4. tvOS `CompanionServer` + wiring (commands → machine/tuning/sound/painting; snapshot on every change).
   Not unit-testable (network glue): verified by task 6.
5. iOS app: `CompanionClient`, PaintingView (hit-test taps with outlines — pure function in core, tested),
   ReadAlongView, SettingsView.
6. End-to-end on simulators: tvOS app + iPhone app running together; a phone UI test taps Christ and sees
   "Jesus Christ" come back from the TV (proves the round trip); screenshots of both.
7. Install on Matt's iPhone when it is reachable; refresh.sh re-signs it nightly when reachable.

## Review focus
Connection drops and reconnects (TV restarts, phone sleeps); commands arriving during the intro or
calibration; tuning from the phone and the remote at the same time (last write wins, both stay in sync).
