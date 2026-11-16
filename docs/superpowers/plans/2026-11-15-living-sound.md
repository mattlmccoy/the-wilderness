# Living sound: real recordings that answer the wall

Matt, 2026-11-15: the synthesized pad "sounds horrendous… like a computer". He wants the most
real, ethereal, relaxing sound, slightly interactive: it should change, just noticeably, when
something breathes and when you move to another figure. Downloads approved.

## Decisions
- **Real recordings only**, CC0 from Freesound (licence filter in the search; ids and authors in
  `App/Sound/CREDITS.md`). No synthesis in the bed.
- **Bed**: a real choir in D major (Freesound 360352 "Meditation Choir"; 84126 as a second layer if
  it helps), looped offline with a long equal-power crossfade so there is no seam.
- **Figures**: one recorded singing bowl, retuned per figure to a note of D major pentatonic
  (D E F# A B), so every move rings in key. Played live on the Apple TV with a cathedral reverb.
- **Breath**: the bed's brightness and level follow Christ's 12 s breath (±1.5 dB, a gentle
  low-pass sweep). The 13 regions together breathe too often for discrete sounds; one shared
  swell is "ever so slightly noticeable" without becoming a metronome.
- Sound stays off by default; Menu → Sound / phone toggle as today.

## Steps (red-green where there is logic)
1. Core `SoundCues` (tests first): figure → pentatonic note, stable and distinct for neighbours;
   mode change → cue (new figure, Unfold beat, Context page; none for the menu or for the same
   figure); breath swell 0…1 from `Breathing`.
2. Script `scripts/make_soundscape.py` (tests first): seamless crossfade loop, bowl trim with a
   clean decay, peak and level limits. Writes `App/Sound/bed.m4a`, `App/Sound/bowl.m4a`.
3. App `SoundPlayer`: bed loop → EQ (low-pass) → reverb; bowl voices with varispeed for pitch;
   driven by `SoundCues`. Not unit-testable: verify in the simulator (logs) and by Matt's ears.
4. Remove the synthesized pad (`make_ambience.py`, `ambience.m4a`) and the old wind.
5. README credits; build; install on Matt's go.
