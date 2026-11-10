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

private func machine(_ mode: Mode? = nil) -> ModeMachine {
    var m = ModeMachine(calibrated: true, now: 0)
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

@Test func selectInStillnessDoesNothing() {
    var m = machine()
    m.press(.select)
    #expect(m.mode == .stillness)
}

@Test func playPauseFromStillnessAndExploreStartsUnfoldAtTheBeginning() {
    var m = machine()
    m.press(.playPause)
    #expect(m.mode == .unfold(.start))
    var e = machine(.explore(id: "angels", expanded: true))
    e.press(.playPause)
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

@Test func backFromUnfoldExploreAndSettingsReturnsToStillness() {
    for start: Mode in [.unfold(.start), .explore(id: "christ", expanded: true), .settings(focus: .about)] {
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
    for item in SettingsItem.allCases {
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

@Test func uncalibratedStartsCalibratingAndFinishGoesToStillness() {
    var m = ModeMachine(calibrated: false, now: 0)
    #expect(m.mode == .calibrating)
    m.finishCalibration()
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
