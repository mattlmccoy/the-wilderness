import Foundation
import Testing
@testable import WildernessCore

// Into the Quiet in the mode machine and over the wire.

private let lib = AnnotationLibrary(artworkAspect: 1.2, annotations: [])
private let script = UnfoldScript(beats: [UnfoldBeat(id: "b", duration: 10, light: [["christ"]], textSide: .left,
                                                     title: "", short: "", more: nil, draft: true)])
private let line = PrayerLine(ref: "Psalm 1:1", text: "line one", translation: .bsb)
private extension ModeMachine {
    mutating func press(_ i: AppInput, at t: Double) { handle(i, now: t, library: lib, script: script) }
    mutating func run(to t: Double) { tick(now: t, dt: 0.25, script: script) }
}

@Test func aDaytimeSessionEndsBackAtRest() {
    var m = ModeMachine(calibrated: true, now: 0, intro: false)
    m.startPrayer(now: 10, minutes: 5, line: line, period: .evening, darkUntil: nil)
    #expect(m.isPraying && m.mode == .stillness)
    m.run(to: 10 + 299)
    #expect(m.isPraying)
    m.run(to: 10 + 300)
    #expect(!m.isPraying && !m.isAfterPrayerDark(now: 311) && m.mode == .stillness)
    #expect(m.prayerClosing(now: 320) == "Amen. Go in peace.")
    #expect(m.prayerClosing(now: 10 + 300 + 61) == nil)
}

@Test func aLateSessionEndsDarkUntilAPressOrTheWakeTime() {
    var m = ModeMachine(calibrated: true, now: 0, intro: false)
    m.startPrayer(now: 10, minutes: 5, line: line, period: .evening, darkUntil: 5000)
    m.run(to: 310)
    #expect(m.isAfterPrayerDark(now: 320))
    #expect(m.prayerClosing(now: 320) == "Amen. Sleep in peace.")
    m.press(.select, at: 400)                 // wakes the wall; the press opens nothing
    #expect(!m.isAfterPrayerDark(now: 401) && m.mode == .stillness)
    var n = ModeMachine(calibrated: true, now: 0, intro: false)
    n.startPrayer(now: 10, minutes: 5, line: line, period: .evening, darkUntil: 5000)
    n.run(to: 310); n.run(to: 5000)
    #expect(!n.isAfterPrayerDark(now: 5000))
}

@Test func anyRemotePressEndsASessionAndIsUsedUp() {
    var m = ModeMachine(calibrated: true, now: 0, intro: false)
    m.startPrayer(now: 10, minutes: 10, line: line, period: .morning, darkUntil: nil)
    m.press(.select, at: 100)
    #expect(!m.isPraying && m.mode == .stillness)
}

@Test func thePhoneCanEndASession() {
    var m = ModeMachine(calibrated: true, now: 0, intro: false)
    m.startPrayer(now: 10, minutes: 10, line: line, period: .morning, darkUntil: nil)
    m.endPrayer(now: 50)
    #expect(!m.isPraying && m.prayerClosing(now: 55) == "Amen. Go in peace.")
}

@Test func startingPrayerEndsBeStill() {
    let figures = AnnotationLibrary(artworkAspect: 1.2, annotations: [])
    var m = ModeMachine(calibrated: true, now: 0, intro: false)
    m.startSlowLooking(now: 1, library: figures)
    m.startPrayer(now: 2, minutes: 5, line: line, period: .morning, darkUntil: nil)
    #expect(!m.isSlowLooking && m.isPraying)
}

@Test func theSnapshotCarriesTheSession() throws {
    var m = ModeMachine(calibrated: true, now: 0, intro: false)
    m.startPrayer(now: 10, minutes: 10, line: line, period: .morning, darkUntil: nil)
    let status = try #require(m.prayerStatus(now: 10 + 120))
    #expect(status.movement == .reflect && status.index == 2 && status.of == 4 && status.minutes == 10)
    #expect(status.line == line)
    var s = WallSnapshot(mode: "rest", subjectId: nil, header: nil, title: nil, short: nil, story: nil,
                         verses: [], paused: false, tuning: Tuning(), soundOn: false, showPainting: false)
    s.prayer = status
    s.prayerToday = PrayerToday(period: .morning, line: line)
    s.prayerClosing = nil
    let back = try JSONDecoder().decode(WallSnapshot.self, from: JSONEncoder().encode(s))
    #expect(back == s)
    #expect(back.status.contains("Into the quiet · Reflect"))
}

@Test func thePrayerCommandsRoundTrip() throws {
    for c: PhoneCommand in [.pray(minutes: 20), .endPrayer] {
        #expect(try JSONDecoder().decode(PhoneCommand.self, from: JSONEncoder().encode(c)) == c)
    }
}
