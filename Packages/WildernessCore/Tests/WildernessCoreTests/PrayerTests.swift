import Foundation
import Testing
@testable import WildernessCore

// Into the Quiet (docs/superpowers/specs/2026-11-16-prayer-mode-design.md). Fixture lines are
// invented placeholders; real wording lives only in App/Content (BSB) and the git-ignored NIV file.

@Test func morningIsFourAMToThreePM() {
    #expect(Prayer.period(hour: 3) == .evening)
    #expect(Prayer.period(hour: 4) == .morning)
    #expect(Prayer.period(hour: 14) == .morning)
    #expect(Prayer.period(hour: 15) == .evening)
}

@Test func theSleepEndingIsOnlyLateAtNight() {
    #expect(!Prayer.sleepEnding(hour: 20))
    #expect(Prayer.sleepEnding(hour: 21))
    #expect(Prayer.sleepEnding(hour: 23))
    #expect(Prayer.sleepEnding(hour: 3))
    #expect(!Prayer.sleepEnding(hour: 4))
    #expect(!Prayer.sleepEnding(hour: 16))   // a 4 pm session never blacks out the wall
}

@Test func theMovementsShareTheChosenLength() {
    for minutes in Prayer.lengths {
        let s = Prayer.schedule(minutes: minutes)
        #expect(s.map(\.movement) == [.read, .reflect, .respond, .rest])
        let total = Double(minutes * 60)
        #expect(abs(s.map(\.seconds).reduce(0, +) - total) < 1e-9)
        #expect(s[0].seconds >= 45)
        #expect(abs(s[1].seconds - total * 0.2) < 1e-9 && abs(s[2].seconds - total * 0.2) < 1e-9)
        #expect(s[3].seconds >= total * 0.45)
    }
    #expect(Prayer.lengths == [5, 10, 20, 30])
    #expect(Prayer.schedule(minutes: 5)[0].seconds == 45)      // 10% of 5 min is 30 s: the floor wins
    #expect(Prayer.schedule(minutes: 20)[0].seconds == 120)
}

private let line = PrayerLine(ref: "Psalm 1:1", text: "line one", translation: .bsb)

@Test func aSessionWalksTheMovementsThenFinishes() {
    let s = PrayerSession(startedAt: 100, minutes: 10, line: line, sleeps: false)
    #expect(s.movement(at: 100)?.movement == .read)
    #expect(s.movement(at: 100 + 59)?.movement == .read)
    #expect(s.movement(at: 100 + 60)?.movement == .reflect)
    #expect(s.movement(at: 100 + 60)?.index == 2)
    #expect(s.movement(at: 100 + 600 - 1)?.movement == .rest)
    #expect(s.movement(at: 100 + 600) == nil)
    #expect(!s.isFinished(at: 100 + 599) && s.isFinished(at: 100 + 600))
    #expect(s.movement(at: 100 + 60)?.of == 4)
}

private func lines(_ n: Int, prefix: String) -> [PrayerContent.Entry] {
    (1...n).map { .init(ref: "Psalm \($0):1", text: "\(prefix) \($0)") }
}
private let content = PrayerContent(morning: lines(5, prefix: "dawn"), evening: lines(5, prefix: "dusk"))

@Test func theLineIsTheSameAllDayAndChangesTheNext() {
    let a = Prayer.line(on: CivilDate(year: 2026, month: 11, day: 16), period: .morning, content: content, licensed: .none)
    let b = Prayer.line(on: CivilDate(year: 2026, month: 11, day: 16), period: .morning, content: content, licensed: .none)
    let c = Prayer.line(on: CivilDate(year: 2026, month: 11, day: 17), period: .morning, content: content, licensed: .none)
    #expect(a == b && a != c)
    #expect(a?.text.hasPrefix("dawn") == true)
    #expect(Prayer.line(on: CivilDate(year: 2026, month: 11, day: 16), period: .evening, content: content, licensed: .none)?.text.hasPrefix("dusk") == true)
}

@Test func theLicensedTextReplacesThePlaceholderAndKeepsItsLabel() {
    let day = CivilDate(year: 2026, month: 11, day: 16)
    let plain = Prayer.line(on: day, period: .morning, content: content, licensed: .none)!
    #expect(plain.translation == .bsb)          // never labelled NIV without NIV text
    let lic = LicensedVerses(verses: [LicensedVerse(ref: plain.ref, translation: .niv, text: "licensed words")])
    let shown = Prayer.line(on: day, period: .morning, content: content, licensed: lic)!
    #expect(shown.text == "licensed words" && shown.translation == .niv && shown.ref == plain.ref)
}

@Test func anOverLongLineIsSkipped() {
    let day = CivilDate(year: 2026, month: 11, day: 16)
    let plain = Prayer.line(on: day, period: .morning, content: content, licensed: .none)!
    let long = String(repeating: "w ", count: Prayer.maxLineCharacters)
    let lic = LicensedVerses(verses: [LicensedVerse(ref: plain.ref, translation: .niv, text: long)])
    let shown = Prayer.line(on: day, period: .morning, content: content, licensed: lic)!
    #expect(shown.ref != plain.ref)
    #expect(shown.text.count <= Prayer.maxLineCharacters)
}

// MARK: The real content

private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

@Test func theCommittedLinesAreShortBSBClausesWithSources() throws {
    let c = try PrayerContent.decode(Data(contentsOf: root.appendingPathComponent("App/Content/prayer.json")))
    #expect(c.morning.count == 14 && c.evening.count == 14)
    let sources = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("docs/copy/verse-sources.json"))) as! [String: [String: String]]
    for e in c.morning + c.evening {
        #expect(e.text.count <= Prayer.maxLineCharacters, "\(e.ref) too long")
        let bsb = try #require(sources[e.ref]?["BSB"], "\(e.ref) has no BSB source")
        #expect(bsb.contains(e.text.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!"))), "\(e.ref) is not a clause of its source")
    }
}
