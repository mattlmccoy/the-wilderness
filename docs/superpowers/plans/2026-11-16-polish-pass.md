# Polish pass (Matt, 2026-11-16)

1. [x] **Hide text while exploring.** Double-press Play/Pause toggles the wall's text off/on in
   Explore (light only). A single press still starts Unfold, after a short wait (0.4 s) to tell
   the two apart. Persists across figures; the phone gets a "Hide text" toggle. Core-first (TDD).
2. [x] **Alignment instructions never cover the cloth.** Put them below the quad if there is room,
   else above, else at the side with the most room (pure layout function, TDD).
3. [x] **Readable TV text.** Raise the smallest sizes (wayfinding, hints, menu, settings, About,
   calibration hints) to a floor readable from the sofa. Verify with simulator screenshots.
4. [x] **Phone feedback.** Haptic + a pressed state on every control; an error haptic and a clear
   "Not connected" when a command cannot be sent; Play/Pause, paging and Align reflect the wall's
   reply. Verify in the iPhone simulator.
5. [x] **Spacing audit.** Screenshot every TV and phone screen (never expanded verses); fix overlaps.
6. [ ] Brainstorm: features, seasonal Easter eggs, serious visual upgrades (list for Matt).
