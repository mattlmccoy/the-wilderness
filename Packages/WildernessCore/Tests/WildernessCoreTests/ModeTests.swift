import Foundation
import Testing
@testable import WildernessCore

private func a(_ id: String, _ x: Double, _ y: Double) -> Annotation {
    Annotation(id: id, title: id, short: "", extended: "", references: [], evidence: .documented,
               anchor: .init(x: x, y: y), outline: nil, textSide: .left, geometrySource: "test")
}
private let lib = AnnotationLibrary(artworkAspect: 1.2, annotations: [
    a("christ", 0.77, 0.50), a("angels", 0.85, 0.18), a("stag", 0.19, 0.59),
])
private func beat(_ id: String, _ d: Double) -> UnfoldBeat {
    UnfoldBeat(id: id, duration: d, light: [["whole"]], textSide: .left, title: id, short: "", more: nil, draft: true)
}
private let script = UnfoldScript(beats: [beat("one", 10), beat("two", 20), beat("three", 30)])

/// A calibrated machine already past the boot-up intro, i.e. at rest.
private func machine(_ mode: Mode? = nil) -> ModeMachine {
    var m = ModeMachine(calibrated: true, now: 0, intro: false)
    if let mode { m.force(mode) }
    return m
}
private extension ModeMachine {
    @discardableResult
    mutating func press(_ i: AppInput, at t: Double = 1) -> ModeEffect? { handle(i, now: t, library: lib, script: script) }
}

@Test func arrowFromStillnessExploresChrist() {
    var m = machine()
    m.press(.move(.left))
    #expect(m.mode == .explore(id: "christ", expanded: false))
}

@Test func selectInStillnessOpensTheMenuOnExplore() {
    var m = machine()
    m.press(.select)
    #expect(m.mode == .menu(focus: .explore))
}

@Test func playPauseFromStillnessAndExploreStartsUnfoldAtTheBeginning() {
    var m = machine()
    m.press(.playPause)
    #expect(m.mode == .unfold(.start))
    // In Explore a single press waits a moment (it may be the first of a double press: hide text).
    var e = machine(.explore(id: "angels", expanded: true))
    e.press(.playPause, at: 1)
    #expect(e.mode == .explore(id: "angels", expanded: true))
    e.tick(now: 1 + ModeMachine.doublePressWindow + 0.05, dt: 0.25, script: script)
    #expect(e.mode == .unfold(.start))
}

@Test func playPauseInUnfoldPausesAndResumes() {
    var m = machine(.unfold(.init(beat: 1, elapsed: 3, paused: false)))
    m.press(.playPause)
    #expect(m.mode == .unfold(.init(beat: 1, elapsed: 3, paused: true)))
    m.press(.playPause)
    #expect(m.mode == .unfold(.init(beat: 1, elapsed: 3, paused: false)))
}

@Test func leftRightStepBeats() {
    var m = machine(.unfold(.init(beat: 1, elapsed: 3, paused: false)))
    m.press(.move(.right))
    #expect(m.mode == .unfold(.init(beat: 2, elapsed: 0, paused: false)))
    m.press(.move(.left)); m.press(.move(.left))
    #expect(m.mode == .unfold(.init(beat: 0, elapsed: 0, paused: false)))
    m.press(.move(.up))
    #expect(m.mode == .unfold(.init(beat: 0, elapsed: 0, paused: false)))
}

@Test func rightOnLastBeatEndsUnfold() {
    var m = machine(.unfold(.init(beat: 2, elapsed: 3, paused: false)))
    m.press(.move(.right))
    #expect(m.mode == .stillness)
}

@Test func backGoesUpOneLevelModeThenMenuThenStillness() {
    var e = machine(.explore(id: "christ", expanded: true))
    #expect(e.press(.back) == nil)
    #expect(e.mode == .menu(focus: .explore))
    var u = machine(.unfold(.start))
    u.press(.back)
    #expect(u.mode == .menu(focus: .unfold))
    for start: Mode in [.menu(focus: .unfold), .settings(focus: .about)] {
        var m = machine(start)
        #expect(m.press(.back) == nil)
        #expect(m.mode == .stillness, "from \(start)")
    }
}

@Test func backInStillnessExitsTheApp() {
    var m = machine()
    #expect(m.press(.back) == .exitApp)
}

@Test func holdSelectOpensSettingsFromStillnessAndExploreButNotUnfold() {
    var s = machine(); s.press(.holdSelect)
    #expect(s.mode == .settings(focus: .calibrate))
    var e = machine(.explore(id: "christ", expanded: false)); e.press(.holdSelect)
    #expect(e.mode == .settings(focus: .calibrate))
    var u = machine(.unfold(.start)); u.press(.holdSelect)
    #expect(u.mode == .unfold(.start))
}

@Test func settingsFocusMovesAndSelectOpensEachItem() {
    let expected: [SettingsItem: Mode] = [.calibrate: .calibrating, .tune: .tuning, .pattern: .pattern, .about: .about]
    for item in SettingsItem.allCases where item != .painting && item != .demo {   // demo: DemoTests
        var m = machine(.settings(focus: .calibrate))
        for _ in 0..<item.rawValue { m.press(.move(.down)) }
        #expect(m.mode == .settings(focus: item))
        m.press(.select)
        #expect(m.mode == expected[item])
    }
    var top = machine(.settings(focus: .calibrate)); top.press(.move(.up))
    #expect(top.mode == .settings(focus: .calibrate))
}

@Test func backFromTuningReturnsToSettingsOnTune() {
    var m = machine(.tuning); m.press(.back)
    #expect(m.mode == .settings(focus: .tune))
    var p = machine(.pattern); p.press(.back)
    #expect(p.mode == .settings(focus: .pattern))
    var b = machine(.about); b.press(.back)
    #expect(b.mode == .settings(focus: .about))
}

@Test func tuningAndCalibratingIgnoreOtherPresses() {
    var t = machine(.tuning); t.press(.move(.left)); t.press(.select); t.press(.playPause)
    #expect(t.mode == .tuning)
    var c = machine(.calibrating); c.press(.back); c.press(.select)
    #expect(c.mode == .calibrating)
}

@Test func exploreReturnsToStillnessAfter45SecondsIdle() {
    var m = machine()
    m.press(.move(.right), at: 100)
    m.tick(now: 144.9, dt: 1, script: script)
    #expect(m.mode == .explore(id: "christ", expanded: false))
    m.tick(now: 145.1, dt: 0.2, script: script)
    #expect(m.mode == .stillness)
}

@Test func unfoldAdvancesAndFinishingFallsIntoStillness() {
    var m = machine(.unfold(.init(beat: 2, elapsed: 25, paused: false)))
    m.tick(now: 2, dt: 1, script: script)
    #expect(m.mode == .unfold(.init(beat: 2, elapsed: 26, paused: false)))
    m.tick(now: 10, dt: 5, script: script)
    #expect(m.mode == .stillness)
}

@Test func rapidMovesEndOnLatestSubject() {
    var m = machine()
    let moves: [NudgeDirection] = [.right, .up, .left, .down, .left]
    var t = 1.0
    for d in moves { m.press(.move(d), at: t); t += 0.1 }
    var replay = ExploreState.idle
    for d in moves { replay.handle(.move(d), library: lib) }
    guard case let .exploring(id, _) = replay else { Issue.record("replay not exploring"); return }
    #expect(m.mode == .explore(id: id, expanded: false))
}

@Test func uncalibratedStartsCalibratingAndFinishWithoutIntroGoesToStillness() {
    var m = ModeMachine(calibrated: false, now: 0)
    #expect(m.mode == .calibrating)
    m.finishCalibration(now: 5, playIntro: false)
    #expect(m.mode == .stillness)
}

@Test func everyPressRecordsTheTime() {
    var m = machine()
    m.press(.select, at: 42)
    #expect(m.lastInputAt == 42)
}

@Test func awakePolicyReleasesAfterSixHoursAndResetsOnInput() {
    let sixH1m = 6 * 3600.0 + 60
    #expect(AwakePolicy.keepAwake(lastInputAt: 0, now: 6 * 3600.0 - 60))
    #expect(!AwakePolicy.keepAwake(lastInputAt: 0, now: sixH1m))
    var m = machine()
    m.press(.select, at: sixH1m)
    #expect(AwakePolicy.keepAwake(lastInputAt: m.lastInputAt, now: sixH1m))
}

// Final review: nothing may stay projected indefinitely when nobody is using the remote.

@Test func settingsAndAboutReturnToStillnessAfter45SecondsIdle() {
    for start: Mode in [.settings(focus: .tune), .about] {
        var m = machine(start)
        m.press(.move(.down), at: 100)
        m.tick(now: 144.9, dt: 0.25, script: script)
        #expect(m.mode != .stillness, "\(start) left too early")
        m.tick(now: 145.1, dt: 0.25, script: script)
        #expect(m.mode == .stillness, "from \(start)")
    }
}

@Test func tuningPatternAndPausedUnfoldReturnToStillnessAfterFiveMinutesIdle() {
    for start: Mode in [.tuning, .pattern, .unfold(.init(beat: 1, elapsed: 3, paused: true))] {
        var m = machine(start)
        m.press(.move(.up), at: 100)
        m.tick(now: 100 + 299, dt: 0.25, script: script)
        #expect(m.mode != .stillness, "\(start) left too early")
        m.tick(now: 100 + 301, dt: 0.25, script: script)
        #expect(m.mode == .stillness, "from \(start)")
    }
}

@Test func playingUnfoldAndCalibrationNeverTimeOut() {
    var u = machine(.unfold(.init(beat: 0, elapsed: 0, paused: false)))
    u.press(.move(.up), at: 0)
    u.tick(now: 1000, dt: 0.25, script: script)
    #expect(u.mode == .unfold(.init(beat: 0, elapsed: 0.25, paused: false)))
    var c = machine(.calibrating)
    c.tick(now: 100_000, dt: 0.25, script: script)
    #expect(c.mode == .calibrating)
}

@Test func noteActivityResetsAwakeWithoutChangingMode() {
    var m = machine(.explore(id: "christ", expanded: true))
    let later = 7 * 3600.0
    m.noteActivity(now: later)
    #expect(m.mode == .explore(id: "christ", expanded: true))
    #expect(AwakePolicy.keepAwake(lastInputAt: m.lastInputAt, now: later + 60))
}

@Test func selectOnShowPaintingTogglesItAndStaysInSettings() {
    var m = machine(.settings(focus: .painting))
    #expect(m.press(.select) == .togglePainting)
    #expect(m.mode == .settings(focus: .painting))
}

@Test func showPaintingSitsBetweenPatternAndAbout() {
    #expect(SettingsItem.allCases == [.calibrate, .tune, .pattern, .painting, .about, .demo])
}

// MARK: - Menu and wayfinding (navigation design, 2026-11-10)

@Test func upOrDownInStillnessOpensTheMenuWhileLeftRightStillExplore() {
    for d in [NudgeDirection.up, .down] {
        var m = machine(); m.press(.move(d))
        #expect(m.mode == .menu(focus: .explore), "\(d)")
    }
}

@Test func menuFocusMovesWithUpDownAndStopsAtTheEnds() {
    var m = machine(.menu(focus: .explore))
    m.press(.move(.up)); #expect(m.mode == .menu(focus: .explore))
    m.press(.move(.down)); #expect(m.mode == .menu(focus: .unfold))
    m.press(.move(.down)); #expect(m.mode == .menu(focus: .context))
    m.press(.move(.down)); #expect(m.mode == .menu(focus: .sound))
    m.press(.move(.down)); #expect(m.mode == .menu(focus: .sound))
    m.press(.move(.up)); #expect(m.mode == .menu(focus: .context))
}

@Test func selectInTheMenuEntersTheFocusedMode() {
    var e = machine(.menu(focus: .explore)); e.press(.select)
    #expect(e.mode == .explore(id: "christ", expanded: false))
    var u = machine(.menu(focus: .unfold)); u.press(.select)
    #expect(u.mode == .unfold(.start))
}

@Test func playPauseAndHoldSelectWorkFromTheMenu() {
    var p = machine(.menu(focus: .explore)); p.press(.playPause)
    #expect(p.mode == .unfold(.start))
    var h = machine(.menu(focus: .unfold)); h.press(.holdSelect)
    #expect(h.mode == .settings(focus: .calibrate))
}

@Test func menuReturnsToStillnessAfter45SecondsIdle() {
    var m = machine(.menu(focus: .sound))
    m.press(.move(.down), at: 0)
    m.tick(now: 44, dt: 0.25, script: script); #expect(m.mode == .menu(focus: .sound))
    m.tick(now: 45, dt: 0.25, script: script); #expect(m.mode == .stillness)
}

@Test func hintShowsForSixSecondsOnlyWhenAModeIsEnteredFromTheMenu() {
    var m = machine(.menu(focus: .explore))
    m.press(.select, at: 10)
    #expect(m.showsHint(now: 15.9))
    #expect(!m.showsHint(now: 16.1))
    m.press(.back, at: 12)                       // leaving clears it
    #expect(!m.showsHint(now: 12.5))
    var shortcut = machine()
    shortcut.press(.move(.right), at: 10)        // shortcut: no hint
    #expect(!shortcut.showsHint(now: 10.5))
    var moving = machine(.menu(focus: .explore))
    moving.press(.select, at: 10)
    moving.press(.move(.right), at: 11)          // moving within the mode keeps it
    #expect(moving.showsHint(now: 11.5))
}

@Test func wayfindingNamesTheModeAndPlace() {
    #expect(Mode.explore(id: "stag", expanded: false).wayfinding(library: lib, script: script) == "EXPLORE")  // arrows move spatially, so a count would jump
    var p = UnfoldPlayback.start; p.beat = 1
    #expect(Mode.unfold(p).wayfinding(library: lib, script: script) == "UNFOLD · 2 of 3")
    #expect(Mode.stillness.wayfinding(library: lib, script: script) == nil)
    #expect(Mode.menu(focus: .explore).wayfinding(library: lib, script: script) == nil)
}

@Test func tickClearsAnExpiredHintSoTheScreenRedrawsWithoutIt() {
    var m = machine(.menu(focus: .explore))
    m.press(.select, at: 10)
    m.tick(now: 15, dt: 0.25, script: script); #expect(m.hintUntil != nil)
    m.tick(now: 16.1, dt: 0.25, script: script); #expect(m.hintUntil == nil)
}

// MARK: - Boot-up intro (2026-11-10)

private let everyInput: [AppInput] = [.select, .holdSelect, .playPause, .back,
                                      .move(.left), .move(.right), .move(.up), .move(.down)]

@Test func calibratedLaunchPlaysTheIntroUnlessSkipped() {
    #expect(ModeMachine(calibrated: true, now: 100).mode == .intro(startedAt: 100))
    #expect(ModeMachine(calibrated: true, now: 100, intro: false).mode == .stillness)
    #expect(ModeMachine(calibrated: false, now: 100).mode == .calibrating)
}

@Test func savingACalibrationPlaysTheIntro() {
    var m = ModeMachine(calibrated: false, now: 0)
    m.finishCalibration(now: 30, playIntro: true)
    #expect(m.mode == .intro(startedAt: 30))
    var fromSettings = machine(.calibrating)
    fromSettings.finishCalibration(now: 50, playIntro: true)
    #expect(fromSettings.mode == .intro(startedAt: 50))
}

@Test func anyPressDuringTheIntroSkipsToStillnessAndDoesNothingElse() {
    for input in everyInput {
        var m = ModeMachine(calibrated: true, now: 0)
        #expect(m.press(input, at: 3) == nil, "\(input) had an effect")
        #expect(m.mode == .stillness, "\(input) did not skip to rest")
        #expect(m.hintUntil == nil)
        #expect(m.lastInputAt == 3)
    }
}

@Test func theIntroEndsInStillnessWhenItsTimeIsUp() {
    var m = ModeMachine(calibrated: true, now: 100)
    m.tick(now: 100 + IntroTimeline.duration - 0.1, dt: 0.25, script: script)
    #expect(m.mode == .intro(startedAt: 100))
    m.tick(now: 100 + IntroTimeline.duration, dt: 0.25, script: script)
    #expect(m.mode == .stillness)
}

@Test func idleTimeoutsNeverInterruptTheIntro() {
    var m = ModeMachine(calibrated: false, now: 0)           // last press long ago
    m.finishCalibration(now: 10_000, playIntro: true)
    m.tick(now: 10_000 + IntroTimeline.duration - 0.1, dt: 0.25, script: script)
    #expect(m.mode == .intro(startedAt: 10_000))
}

@Test func returningFromTheBackgroundNeitherRestartsNorReplaysTheIntro() {
    var m = ModeMachine(calibrated: true, now: 0)
    m.noteActivity(now: 5)
    #expect(m.mode == .intro(startedAt: 0))
    m.tick(now: IntroTimeline.duration, dt: 0.25, script: script)
    #expect(m.mode == .stillness)
    m.noteActivity(now: 900)
    #expect(m.mode == .stillness)
}

@Test func theIntroHasNoWayfindingLine() {
    #expect(Mode.intro(startedAt: 0).wayfinding(library: lib, script: script) == nil)
}

// MARK: - Context (approved 2026-11-10)

private func ctxPage(_ id: String) -> ContextPage {
    ContextPage(id: id, title: id, text: "t", light: [], visual: nil, textSide: .left, sources: ["s"], draft: true)
}
private let ctx = ContextScript(pages: [ctxPage("p1"), ctxPage("p2"), ctxPage("p3")])
private extension ModeMachine {
    @discardableResult
    mutating func pressCtx(_ i: AppInput, at t: Double = 1) -> ModeEffect? {
        handle(i, now: t, library: lib, script: script, context: ctx)
    }
}

@Test func menuReachesContextAndSelectOpensItsFirstPageWithAHint() {
    var m = machine(.menu(focus: .explore))
    m.pressCtx(.move(.down)); m.pressCtx(.move(.down))
    #expect(m.mode == .menu(focus: .context))
    m.pressCtx(.select, at: 5)
    #expect(m.mode == .context(page: 0))
    #expect(m.showsHint(now: 6))
}

@Test func contextPagesTurnWithLeftRightAndStopAtTheEnds() {
    var m = machine(.context(page: 0))
    m.pressCtx(.move(.left)); #expect(m.mode == .context(page: 0))
    m.pressCtx(.move(.right)); m.pressCtx(.move(.right)); #expect(m.mode == .context(page: 2))
    m.pressCtx(.move(.right)); #expect(m.mode == .context(page: 2))
    m.pressCtx(.move(.left)); #expect(m.mode == .context(page: 1))
}

@Test func backFromContextGoesToTheMenuOnContext() {
    var m = machine(.context(page: 1)); m.pressCtx(.back)
    #expect(m.mode == .menu(focus: .context))
}

@Test func contextReturnsToStillnessAfterTwoMinutesIdle() {
    var m = machine(.context(page: 1))
    m.pressCtx(.move(.right), at: 0)
    m.tick(now: 119, dt: 0.25, script: script); #expect(m.mode != .stillness)
    m.tick(now: 120, dt: 0.25, script: script); #expect(m.mode == .stillness)
}

@Test func contextWayfindingCountsPages() {
    #expect(Mode.context(page: 1).wayfinding(library: lib, script: script, context: ctx) == "CONTEXT · 2 of 3")
}


@Test func selectOnSoundTogglesItAndStaysInTheMenu() {
    var m = machine(.menu(focus: .sound))
    #expect(m.press(.select, at: 3) == .toggleSound)
    #expect(m.mode == .menu(focus: .sound))
    #expect(!m.showsHint(now: 3.5))
}

@Test func contextDimsTheWashOnlyOnPagesThatLightSubjects() {
    let lit = ContextScript(pages: [
        ContextPage(id: "map", title: "t", text: "t", light: [], visual: nil, map: "lombardy", textSide: .left, sources: ["s"], draft: true),
        ContextPage(id: "edge", title: "t", text: "t", light: ["christ"], visual: nil, textSide: .left, sources: ["s"], draft: true),
    ])
    #expect(!Mode.context(page: 0).dimsWash(script: script, context: lit))
    #expect(Mode.context(page: 1).dimsWash(script: script, context: lit))
}

// MARK: - Phone companion: jump straight to a destination (2026-11-11)

@Test func phoneGoReachesItsTargetFromRestMenuAndOtherModes() {
    for start: Mode in [.stillness, .menu(focus: .unfold), .explore(id: "stag", expanded: false),
                        .unfold(.start), .context(page: 1), .intro(startedAt: 0)] {
        var m = machine(start)
        m.pressCtx(.go(.explore("angels")))
        #expect(m.mode == .explore(id: "angels", expanded: false), "from \(start)")
    }
    var u = machine(.explore(id: "stag", expanded: false)); u.pressCtx(.go(.unfold))
    #expect(u.mode == .unfold(.start))
    var c = machine(.stillness); c.pressCtx(.go(.context))
    #expect(c.mode == .context(page: 0))
}

@Test func phoneGoKeepsTheStoryOpenWhenMovingBetweenFigures() {
    var m = machine(.explore(id: "stag", expanded: true))
    m.pressCtx(.go(.explore("christ")))
    #expect(m.mode == .explore(id: "christ", expanded: true))
}

@Test func phoneGoIsIgnoredForUnknownFiguresAndWhileCalibratingOrTuning() {
    var m = machine(.stillness); m.pressCtx(.go(.explore("unicorn")))
    #expect(m.mode == .stillness)
    for start: Mode in [.calibrating, .tuning, .pattern] {
        var k = machine(start); k.pressCtx(.go(.explore("christ")))
        #expect(k.mode == start, "\(start)")
    }
}
