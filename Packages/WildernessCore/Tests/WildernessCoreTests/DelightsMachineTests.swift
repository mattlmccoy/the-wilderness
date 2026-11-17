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

@Test func beStillStaysOnChristUntilAnyButton() {
    // Matt, 2026-11-16: Christ alone, His words rotating, until any button (no walk, no end).
    var m = ModeMachine(calibrated: true, now: 0, intro: false)
    m.force(.menu(focus: .still))
    m.press(.select, at: 10)
    #expect(m.isSlowLooking && m.textHidden)
    let times: [Double] = [11, 46, 431, 3610]
    for t in times {
        m.tick(now: t, dt: 0.25, script: script)
        #expect(m.mode == .explore(id: "christ", expanded: false) && m.isSlowLooking, "at \(t)")
    }
    m.press(.move(.right), at: 4000)
    #expect(!m.isSlowLooking && m.mode == .stillness)
}

@Test func anyPressEndsSlowLookingAndBringsTheTextBack() {
    var m = ModeMachine(calibrated: true, now: 0, intro: false)
    m.force(.menu(focus: .still))
    m.press(.select, at: 10)
    m.tick(now: 11, dt: 0.25, script: script)
    m.press(.move(.left), at: 20)
    #expect(!m.isSlowLooking && m.mode == .stillness && !m.textHidden)
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

// MARK: From the phone (docs/superpowers/plans/2026-11-16-thanksgiving-and-phone.md)

@Test func thePhoneCanStartAndStopBeStill() {
    var m = ModeMachine(calibrated: true, now: 0, intro: false)
    m.startSlowLooking(now: 5, library: lib)
    #expect(m.isSlowLooking && m.textHidden && m.mode == .explore(id: "christ", expanded: false))
    m.stopSlowLooking()
    #expect(!m.isSlowLooking && !m.textHidden && m.mode == .stillness)
}

@Test func thePhoneCanStartAndStopTheDreamcoat() {
    var m = ModeMachine(calibrated: true, now: 0, intro: false)
    m.setDreamcoat(true, now: 10)
    #expect(m.dreamcoat(now: 11))
    m.setDreamcoat(false, now: 12)
    #expect(!m.dreamcoat(now: 13))
}

// MARK: Parity (docs/superpowers/plans/2026-11-16-drift-and-parity.md)

@Test func exploreFromThePhoneStartsWhereTheRemotesExploreStarts() {
    var fromMenu = ModeMachine(calibrated: true, now: 0, intro: false)
    fromMenu.force(.menu(focus: .explore))
    fromMenu.press(.select, at: 1)
    var fromPhone = ModeMachine(calibrated: true, now: 0, intro: false)
    fromPhone.press(.go(.exploreStart), at: 1)
    #expect(fromPhone.mode == fromMenu.mode)
    if case .explore = fromPhone.mode {} else { Issue.record("not exploring: \(fromPhone.mode)") }
}

@Test func thePhoneCanPutThePatternAndAboutOnTheWall() throws {
    var m = ModeMachine(calibrated: true, now: 0, intro: false)
    m.openScreen(.pattern)
    #expect(m.mode == .pattern)
    m.openScreen(.about)
    #expect(m.mode == .about)
    for c: PhoneCommand in [.show(.pattern), .show(.about), .go(.exploreStart)] {
        #expect(try JSONDecoder().decode(PhoneCommand.self, from: JSONEncoder().encode(c)) == c)
    }
}

@Test func anyPressEndsTheDreamcoatAndIsUsedUp() {
    // Matt, 2026-11-16: "if dreamcoat is run, there's no way to turn it off unless you fully close the app".
    var m = ModeMachine(calibrated: true, now: 0, intro: false)
    var t = 1.0
    for i in SecretCode.sequence { m.press(i, at: t); t += 0.3 }
    #expect(m.dreamcoat(now: t))
    let before = m.mode
    m.press(.select, at: t + 5)
    #expect(!m.dreamcoat(now: t + 5.1))
    #expect(m.mode == before)          // the press only ended the dreamcoat; it opened nothing
    m.press(.select, at: t + 6)        // the next press works as usual
    #expect(m.mode != before)
}
