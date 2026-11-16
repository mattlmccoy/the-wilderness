import Foundation
import Testing
@testable import WildernessCore

// The dreamcoat code and slow looking, as the remote drives them.

private func a(_ id: String, _ x: Double) -> Annotation {
    Annotation(id: id, title: id, short: "", extended: "", references: [], evidence: .documented,
               anchor: .init(x: x, y: 0.5), outline: [.init(x: x, y: 0.4), .init(x: x + 0.05, y: 0.5), .init(x: x, y: 0.6)],
               textSide: .left, geometrySource: "test")
}
private let lib = AnnotationLibrary(artworkAspect: 1.2, annotations: [a("christ", 0.77), a("stag", 0.19), a("lion", 0.9)])
private let script = UnfoldScript(beats: [UnfoldBeat(id: "b", duration: 10, light: [["christ"]], textSide: .left,
                                                     title: "", short: "", more: nil, draft: true)])
private extension ModeMachine {
    mutating func press(_ i: AppInput, at t: Double) { handle(i, now: t, library: lib, script: script) }
}

@Test func theCodeStartsTheDreamcoatForAMinuteAndItsSelectDoesNothingElse() {
    var m = ModeMachine(calibrated: true, now: 0, intro: false)
    let before = m.mode
    var t = 1.0
    for k: AppInput in [.move(.up), .move(.up), .move(.down), .move(.down), .move(.left), .move(.right), .move(.left), .move(.right)] {
        m.press(k, at: t); t += 0.3
    }
    m.press(.select, at: t)
    #expect(m.dreamcoat(now: t + 1))
    #expect(!m.dreamcoat(now: t + ModeMachine.dreamcoatSeconds + 1))
    #expect(m.mode == before)
}

@Test func beStillWalksTheFiguresWithTheLightOnly() {
    var m = ModeMachine(calibrated: true, now: 0, intro: false)
    m.force(.menu(focus: .still))
    m.press(.select, at: 10)
    #expect(m.isSlowLooking)
    m.tick(now: 11, dt: 0.25, script: script)
    #expect(m.mode == .explore(id: "christ", expanded: false))
    #expect(m.textHidden)
    m.tick(now: 10 + SlowLooking.secondsPerFigure + 1, dt: 0.25, script: script)
    #expect(m.mode == .explore(id: "stag", expanded: false))
}

@Test func anyPressEndsSlowLookingAndBringsTheTextBack() {
    var m = ModeMachine(calibrated: true, now: 0, intro: false)
    m.force(.menu(focus: .still))
    m.press(.select, at: 10)
    m.tick(now: 11, dt: 0.25, script: script)
    m.press(.move(.left), at: 20)
    #expect(!m.isSlowLooking && m.mode == .stillness && !m.textHidden)
}

@Test func slowLookingEndsAtRestByItself() {
    var m = ModeMachine(calibrated: true, now: 0, intro: false)
    m.force(.menu(focus: .still))
    m.press(.select, at: 10)
    m.tick(now: 10 + SlowLooking.total(ids: ["christ", "stag", "lion"]) + 1, dt: 0.25, script: script)
    #expect(!m.isSlowLooking && m.mode == .stillness)
}

@Test func theWholeCodeFromRestLeavesTheWallAtRest() {
    // Simulator capture, 2026-11-16: the arrows opened the menu and left it over the dreamcoat.
    var m = ModeMachine(calibrated: true, now: 0, intro: false)
    let start = m.mode
    var t = 10.0
    for i in SecretCode.sequence { m.press(i, at: t); t += 0.3 }
    #expect(m.dreamcoat(now: t))
    #expect(m.mode == start)
}
