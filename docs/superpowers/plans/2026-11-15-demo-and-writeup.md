# Self-running demo + GitHub write-up

Matt, 2026-11-15: an automatically running demo to film with a static camera for the portfolio,
and the project on GitHub (public, `the-wilderness`) with a strong write-up: pictures, annotated
pictures, simulations.

## Decisions (Matt)
- Repo: public, `the-wilderness`. Nothing pushed until Matt confirms the final README.
- Demo shows NIV as on the wall (Matt's call). The **repo and README never contain NIV/NLT text**:
  `licensed-verses.json` stays ignored; README images avoid expanded verse cards.
- Demo starts from a Settings row on the Apple TV and a Demo button on the phone; Back ends it.

## Demo design (~3 min loop, every feature once)
| Segment | Shows | Length |
|---|---|---|
| Intro | outlines draw themselves | 15 s |
| Rest | breathing, glints (often), one pass of sun rays | 40 s |
| Explore | Christ, raven, lion, pelican, stag, bowing animal (short, then expanded) | 6 × 10 s |
| Unfold | 4 beats, compressed to 9 s each, lights stepping | 36 s |
| Context | Into the Wilderness (map+photo), Mount of Temptation, Brescia to Jerusalem (route), Its Real Size (frame) | 4 × 8 s |
| Rest | breathe out, then loop | 10 s |

Pure timeline in core (`DemoScript`), TDD: segment at time t, loops, total length, compressed Unfold playback.
ModeMachine gets demo start/stop; any remote/phone input other than demo ends it.

## Steps
1. [ ] Core: `DemoScript` + tests.  2. [ ] Core: ModeMachine demo mode + tests.
3. [ ] App: demo drives modes; forces glints often + one ray pass in the rest segment; Settings row.
4. [ ] Phone: Demo button (PhoneCommand.demo).  5. [ ] Verify in simulator (recording).
6. [ ] Media: screenshots, annotated images (outlines, calm zones, bend, maps), simulator recordings → GIFs.
7. [ ] README write-up + LICENSE/credits; audit no licensed text in tree/history.
8. [ ] Create repo + push only after Matt confirms.
