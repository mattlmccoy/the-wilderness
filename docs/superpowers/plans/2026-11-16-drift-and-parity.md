# Drifting light and full parity (Matt, 2026-11-16)

Matt: "When in the be still or idle mode, the light should drift between subjects slowly and
gracefully. Also yes make sure there's full parity between the apps."

## Drift (core first, test-first)
1. [x] `Drift.tour(library)`: a walk over the figures that always steps to the nearest one not yet
   visited, starting at Christ, so the light travels across the painting instead of jumping.
2. [x] `Drift.weights(at:path:dwell:fade:loops:)`: per-subject light 0…1. Holds on one subject,
   then cross-fades to the next over `fade` seconds (smoothstep), centred on each boundary.
   Weights sum to 1 while running; no step bigger than a slow fade; a finished walk fades out.
3. [x] Be still uses it: the tour order (Christ first and last, as before), 35 s per figure,
   12 s cross-fades. The mode still names the figure for the phone.
4. [x] At rest: `Tuning.drift` (0…1 of the subject light, default 0.5; 0 = off), 40 s per figure,
   15 s cross-fades, looping. Off during wind-down, the intro and alignment. Breathing, glints and
   moments carry on.
5. [x] Wall: a `DriftLayer` draws the weights continuously (no SwiftUI animation steps).

## Parity: everything on one app can be done from the other
Already on both: Explore a figure, Unfold, Context, Be still, sound, hide text, steps, pause, back,
dreamcoat (remote code / hold the title), demo, show painting, align, all light values, seasons.
6. [x] Phone: Explore in the mode row (starts where the remote's Explore starts).
7. [x] Phone: glint style; drifting light; "Show alignment pattern" and "About" on the wall.
8. [x] Wall: drifting light on the Tune screen.
9. [x] Protocol: `PhoneCommand.show(WallScreen)` (pattern, about); `Destination.exploreStart`.
Phone-only by nature (no remote equivalent): the flashlight and Siri shortcuts.

## Verify
10. [x] Core suite; TV and phone UI suites; a simulator clip of the drift at rest and in Be still;
    phone screenshots at rest only (never the read-along with verses).
