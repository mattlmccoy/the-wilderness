import Foundation
import Testing
@testable import WildernessCore

// Hide the text while exploring (Matt, 2026-11-16): double-press Play/Pause in Explore, light only.

private func a(_ id: String, _ x: Double) -> Annotation {
    Annotation(id: id, title: id, short: "", extended: "", references: [], evidence: .documented,
               anchor: .init(x: x, y: 0.5), outline: nil, textSide: .left, geometrySource: "test")
}
private let lib = AnnotationLibrary(artworkAspect: 1.2, annotations: [a("christ", 0.77), a("stag", 0.19)])
private let script = UnfoldScript(beats: [UnfoldBeat(id: "b", duration: 10, light: [["christ"]], textSide: .left,
                                                     title: "", short: "", more: nil, draft: true)])
private func exploring() -> ModeMachine {
    var m = ModeMachine(calibrated: true, now: 0, intro: false)
    m.force(.explore(id: "christ", expanded: false))
    return m
}
private extension ModeMachine {
    mutating func press(_ i: AppInput, at t: Double) { handle(i, now: t, library: lib, script: script) }
    mutating func wait(until t: Double) { tick(now: t, dt: 0.25, script: script) }
}

@Test func doublePressHidesTheTextAndStaysExploring() {
    var m = exploring()
    m.press(.playPause, at: 10)
    m.press(.playPause, at: 10.25)
    #expect(m.textHidden)
    m.wait(until: 12)
    #expect(m.mode == .explore(id: "christ", expanded: false))   // no Unfold after all
}

@Test func doublePressAgainBringsTheTextBack() {
    var m = exploring()
    m.press(.playPause, at: 10); m.press(.playPause, at: 10.2)
    m.press(.playPause, at: 20); m.press(.playPause, at: 20.2)
    #expect(!m.textHidden)
}

@Test func hiddenTextStaysHiddenFromFigureToFigure() {
    var m = exploring()
    m.press(.playPause, at: 10); m.press(.playPause, at: 10.2)
    m.press(.move(.left), at: 11)
    #expect(m.mode == .explore(id: "stag", expanded: false))
    #expect(m.textHidden)
}

@Test func twoSlowPressesAreNotADoublePress() {
    var m = exploring()
    m.press(.playPause, at: 10)
    m.wait(until: 10 + ModeMachine.doublePressWindow + 0.05)
    #expect(m.mode == .unfold(.start))
    #expect(!m.textHidden)
}

@Test func anotherPressCancelsAWaitingPlay() {
    var m = exploring()
    m.press(.playPause, at: 10)
    m.press(.move(.left), at: 10.1)
    m.wait(until: 11)
    #expect(m.mode == .explore(id: "stag", expanded: false))
}

@Test func thePhoneCanHideTheTextToo() throws {
    var m = exploring()
    m.setTextHidden(true)
    #expect(m.textHidden)
    let cmd = PhoneCommand.setTextHidden(true)
    #expect(try JSONDecoder().decode(PhoneCommand.self, from: LineFramer.frame(cmd).dropLast()) == cmd)
}
