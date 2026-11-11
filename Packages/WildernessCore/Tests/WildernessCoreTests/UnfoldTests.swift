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
private func beat(_ id: String, _ d: Double, _ light: [[String]]) -> UnfoldBeat {
    UnfoldBeat(id: id, duration: d, light: light, textSide: .left, title: id, short: "", more: nil, draft: true)
}
/// Three short beats; built directly so the five-minute total check does not apply.
private let script = UnfoldScript(beats: [
    beat("one", 10, [["whole"]]), beat("two", 20, [["christ"], ["angels"]]), beat("three", 30, [["stag"]]),
])

@Test func advanceCarriesOverflowIntoTheNextBeat() throws {
    let p = try #require(script.advance(.start, by: 12))
    #expect(p.beat == 1 && abs(p.elapsed - 2) < 1e-9)
}

@Test func advanceWhilePausedDoesNothing() {
    let paused = UnfoldPlayback(beat: 1, elapsed: 3, paused: true)
    #expect(script.advance(paused, by: 5) == paused)
}

@Test func advancePastTheEndFinishes() {
    #expect(script.advance(.init(beat: 2, elapsed: 29, paused: false), by: 5) == nil)
}

@Test func stepsSplitTheBeatEvenly() {
    #expect(script.step(.init(beat: 1, elapsed: 9.9, paused: false)) == 0)
    #expect(script.step(.init(beat: 1, elapsed: 10.1, paused: false)) == 1)
}

@Test func previousOnFirstBeatRestartsIt() {
    #expect(script.previous(.init(beat: 0, elapsed: 7, paused: false)) == .start)
    #expect(script.previous(.init(beat: 2, elapsed: 7, paused: true)) == .init(beat: 1, elapsed: 0, paused: true))
}

@Test func nextOnLastBeatFinishes() {
    #expect(script.next(.init(beat: 0, elapsed: 4, paused: false)) == .init(beat: 1, elapsed: 0, paused: false))
    #expect(script.next(.init(beat: 2, elapsed: 4, paused: false)) == nil)
}

private func scriptJSON(_ beats: [(String, Double, String)]) -> Data {
    let items = beats.map { #"{"id":"\#($0.0)","duration":\#($0.1),"light":\#($0.2),"textSide":"left","title":"t","short":"s","draft":true}"# }
    return Data(#"{"beats":[\#(items.joined(separator: ","))]}"#.utf8)
}

@Test func unknownSubjectInUnfoldIsRejected() {
    let data = scriptJSON([("a", 150, #"[["whole"]]"#), ("b", 150, #"[["unicorn"]]"#)])
    #expect(throws: (any Error).self) { try UnfoldScript.decode(data, library: lib) }
}

@Test func totalDurationMustBeAboutFiveMinutes() {
    let short = scriptJSON([("a", 20, #"[["whole"]]"#), ("b", 20, #"[["christ"]]"#), ("c", 20, #"[["stag"]]"#)])
    #expect(throws: (any Error).self) { try UnfoldScript.decode(short, library: lib) }
    let ok = scriptJSON([("a", 150, #"[["whole"]]"#), ("b", 150, #"[["christ"],["angels"]]"#)])
    #expect((try? UnfoldScript.decode(ok, library: lib))?.beats.count == 2)
}

@Test func emptyLightOrZeroDurationIsRejected() {
    #expect(throws: (any Error).self) { try UnfoldScript.decode(scriptJSON([("a", 300, "[]")]), library: lib) }
    #expect(throws: (any Error).self) {
        try UnfoldScript.decode(scriptJSON([("a", 0, #"[["whole"]]"#), ("b", 300, #"[["whole"]]"#)]), library: lib)
    }
}

@Test func duplicateBeatIDsAreRejected() {
    let data = scriptJSON([("a", 150, #"[["whole"]]"#), ("a", 150, #"[["christ"]]"#)])
    #expect {
        try UnfoldScript.decode(data, library: lib)
    } throws: { error in
        String(describing: error) == "duplicate beat id a"
    }
}
