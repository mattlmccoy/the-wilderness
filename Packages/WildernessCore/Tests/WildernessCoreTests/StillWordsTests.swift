import Foundation
import Testing
@testable import WildernessCore

// Be still, reworked (Matt, 2026-11-16): Christ's light alone and a rotation of His words, with Old
// Testament verses that point to Him, until any button. Fixture lines are invented placeholders.

private func words(_ n: Int) -> StillWords {
    StillWords(entries: (1...n).map { .init(ref: "John \($0):1", text: "saying \($0)", kind: $0 % 3 == 0 ? .prophecy : .jesus) })
}
private let day = CivilDate(year: 2026, month: 11, day: 16)

@Test func eachLineFadesInHoldsThenFadesOut() throws {
    let w = words(6), p = StillRotation.period
    let a = try #require(StillRotation.line(at: 0, day: day, words: w, licensed: .none))
    #expect(a.alpha == 0)
    #expect(try #require(StillRotation.line(at: StillRotation.fadeIn, day: day, words: w, licensed: .none)).alpha == 1)
    #expect(try #require(StillRotation.line(at: p * 0.5, day: day, words: w, licensed: .none)).alpha == 1)
    let late = try #require(StillRotation.line(at: p - 0.1, day: day, words: w, licensed: .none))
    #expect(late.alpha == 0 && late.line == a.line)          // the gap before the next line is dark
    let next = try #require(StillRotation.line(at: p + 10, day: day, words: w, licensed: .none))
    #expect(next.line != a.line)
}

@Test func theRotationStartsSomewhereElseEachDayAndLoops() throws {
    let w = words(6)
    let today = try #require(StillRotation.line(at: 10, day: day, words: w, licensed: .none)).line
    let tomorrow = try #require(StillRotation.line(at: 10, day: day.adding(days: 1), words: w, licensed: .none)).line
    #expect(today != tomorrow)
    let lap = try #require(StillRotation.line(at: 10 + 6 * StillRotation.period, day: day, words: w, licensed: .none)).line
    #expect(lap == today)
}

@Test func licensedWordingIsUsedAndOverLongLinesAreSkipped() throws {
    let w = words(3)
    let first = try #require(StillRotation.line(at: 10, day: day, words: w, licensed: .none))
    let lic = LicensedVerses(verses: [LicensedVerse(ref: first.line.ref, translation: .niv, text: "licensed words")])
    #expect(try #require(StillRotation.line(at: 10, day: day, words: w, licensed: lic)).line.translation == .niv)
    let long = LicensedVerses(verses: [LicensedVerse(ref: first.line.ref, translation: .niv,
                                                     text: String(repeating: "w ", count: StillRotation.maxCharacters))])
    #expect(try #require(StillRotation.line(at: 10, day: day, words: w, licensed: long)).line.ref != first.line.ref)
}

// MARK: The real content

private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

@Test func theWordsAreChristsAndTheProphetsAsBSBClausesWithSources() throws {
    let w = try StillWords.decode(Data(contentsOf: root.appendingPathComponent("App/Content/stillwords.json")))
    let jesus = w.entries.filter { $0.kind == .jesus }, prophecy = w.entries.filter { $0.kind == .prophecy }
    #expect(jesus.count >= 35 && prophecy.count >= 15)
    let sources = try JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent("docs/copy/verse-sources.json"))) as! [String: [String: String]]
    let ot = ["Genesis", "Deuteronomy", "Psalm", "Isaiah", "Jeremiah", "Daniel", "Micah", "Zechariah", "Malachi"]
    for e in w.entries {
        #expect(e.text.count <= StillRotation.maxCharacters, "\(e.ref) too long")
        let bsb = try #require(sources[e.ref]?["BSB"], "\(e.ref) has no BSB source")
        #expect(bsb.contains(e.text.trimmingCharacters(in: CharacterSet(charactersIn: ".,;:!"))), "\(e.ref) is not a clause of its source")
        #expect((e.kind == .prophecy) == ot.contains { e.ref.hasPrefix($0 + " ") }, "\(e.ref) kind")
    }
    #expect(Set(w.entries.map(\.ref)).count == w.entries.count)
}
