import Foundation
import Testing
@testable import WildernessCore

@Test func defaultsMatchTheSpec() {
    let t = Tuning.defaults
    #expect(t.subjectStrength == 0.44 && t.baseWash == 0.16 && t.exploreWashFactor == 0.45)
    #expect(t.glintMeanInterval == 8 && t.glintBrightness == 1.0 && t.glintSizeInches == 0.06)
    #expect(t.glintStyle == .thread)
    #expect(t.glintParams.meanInterval == 8 && t.glintParams.minGap == 1.5)
    #expect(Tuning.storageKey == "tuning.v1")
}

private func session(at row: TuningRow, _ t: Tuning = .defaults) -> TuningSession {
    var s = TuningSession(tuning: t)
    for _ in 0..<row.rawValue { s.handle(.down) }
    return s
}

@Test func rightRaisesStrengthAndClampsAtOne() {
    var s = session(at: .subjectStrength)
    s.handle(.right)
    #expect(abs(s.tuning.subjectStrength - 0.46) < 1e-9)
    for _ in 0..<100 { s.handle(.right) }
    #expect(s.tuning.subjectStrength == 1)
}

@Test func frequencyStepsRareNowAndThenOften() {
    var s = session(at: .glintFrequency)
    #expect(s.row == .glintFrequency && s.rowLabel == "Glints · now and then")
    s.handle(.right); #expect(s.tuning.glintMeanInterval == 4)
    s.handle(.right); #expect(s.tuning.glintMeanInterval == 4)
    s.handle(.left); s.handle(.left); #expect(s.tuning.glintMeanInterval == 16)
    #expect(s.rowLabel == "Glints · rare")
}

@Test func styleToggles() {
    var s = session(at: .glintStyle)
    s.handle(.left)
    #expect(s.tuning.glintStyle == .pinpoint)
}

@Test func rowsStopAtTheEnds() {
    var s = TuningSession(tuning: .defaults)
    s.handle(.up)
    #expect(s.row == .subjectStrength)
    for _ in 0..<20 { s.handle(.down) }
    #expect(s.row == .resetDefaults)
}

@Test func resetRestoresDefaults() {
    var changed = Tuning.defaults
    changed.baseWash = 0.3
    changed.glintStyle = .pinpoint
    var s = session(at: .resetDefaults, changed)
    s.select()
    #expect(s.tuning == .defaults)
}

@Test func tuningRoundTripsThroughJSON() throws {
    var t = Tuning.defaults
    t.glintSizeInches = 0.09
    #expect(try JSONDecoder().decode(Tuning.self, from: JSONEncoder().encode(t)) == t)
}
