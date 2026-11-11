import Foundation
import Testing
@testable import WildernessCore

@Test func edgeLineDefaultsTo80PercentAndOldProfilesGetTheDefault() throws {
    // 50% read as a faint glow, not a line, in review (2026-11-10).
    #expect(Tuning.defaults.edgeLine == 0.8)
    let old = Data(#"{"subjectStrength":0.6,"baseWash":0,"exploreWashFactor":0.45,"glintMeanInterval":8,"glintBrightness":1,"glintSizeInches":0.06,"glintStyle":"thread"}"#.utf8)
    let t = try JSONDecoder().decode(Tuning.self, from: old)
    #expect(t.edgeLine == 0.8)
    #expect(t.subjectStrength == 0.6)
}

@Test func tuneLightHasAnEdgeLineRowThatStepsAndCanTurnOff() {
    var s = TuningSession(tuning: .defaults)
    while s.row != .edgeLine { s.handle(.down) }
    #expect(s.rowLabel == "Edge line · 80%")
    s.handle(.right)
    #expect(abs(s.tuning.edgeLine - 0.85) < 1e-9)
    for _ in 0..<20 { s.handle(.left) }
    #expect(s.tuning.edgeLine == 0)
    #expect(s.rowLabel == "Edge line · off")
}

@Test func edgeLineDrawsInThenSettlesToAQuietLine() {
    let start = EdgeLine.frame(at: 0)
    #expect(start.progress == 0)
    let mid = EdgeLine.frame(at: EdgeLine.delay + EdgeLine.drawSeconds / 2)
    #expect(mid.progress > 0.3 && mid.progress < 0.7)
    #expect(mid.opacity == 1)
    let drawn = EdgeLine.frame(at: EdgeLine.delay + EdgeLine.drawSeconds)
    #expect(drawn.progress == 1)
    let settled = EdgeLine.frame(at: 10)
    #expect(settled.progress == 1)
    #expect(settled.opacity == EdgeLine.restOpacity)
    #expect(EdgeLine.restOpacity < 1 && EdgeLine.restOpacity > 0)
}
