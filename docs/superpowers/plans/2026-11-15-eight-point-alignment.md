# Eight-point alignment, adjustable from the phone

Matt, 2026-11-15: "adjust the alignment from my phone too … add 4 more midpoints so we can really tune it to the tapestry."

## Design
- Calibration keeps its 4 corners (perspective homography, unchanged) and gains 4 **edge offsets**
  (top, right, bottom, left): how far each edge's midpoint sits from where the homography puts it,
  in normalized projector units. Missing/zero ⇒ exactly the old mapping (old saves load unchanged).
- Bend field (artwork u,v ∈ 0…1), b(s) = 4s(1−s):
  D(u,v) = (1−v)·T·b(u) + v·B·b(u) + (1−u)·L·b(v) + u·R·b(v). Zero at corners, full offset at each midpoint.
- Final projector point = H(u,v) + D(u,v).
- Render: existing projectionEffect, then a Metal `distortionEffect` on the screen-sized layer that
  samples source = p − D(H⁻¹(p)) (first-order inverse; offsets are small, clamped to ≤ 0.08).
- Remote: 8 handles clockwise from top-left (corner, top middle, corner, right middle, …), then review.
- Phone: Settings → Align. Diagram of the 8 handles; tap one, nudge with arrows (coarse/fine), Save/Cancel.
  Wall enters calibration and shows the pattern live; snapshot carries handle positions + selection.

## Steps (TDD for every core piece)
1. [x] Core: `Calibration.edgeOffsets` (tolerant decode), `bend(u:v:)`, `projectorPoint(artwork:)`, `handle(_:)`.
2. [x] Core: `AlignPoint` (8, clockwise), adjuster nudges corners or offsets (clamped), session walks 8 + review.
3. [x] App: Metal bend shader + MappedCanvas uses it; CalibrationView shows 8 handles.
4. [x] Core: phone protocol `PhoneCommand.align(...)`, `WallSnapshot.alignment`.
5. [x] App: calibration session lifted to RootView so phone + remote drive the same session.
6. [x] Phone: Align screen.
7. [x] Verify: simulator screenshots with a bent edge; phone sim drives TV sim; all tests green; commit per step.
