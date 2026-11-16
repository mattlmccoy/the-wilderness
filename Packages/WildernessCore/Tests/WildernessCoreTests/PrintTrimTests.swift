import Foundation
import Testing
@testable import WildernessCore

// Painting trim (Matt, 2026-11-15): the print shows a little less of the painting than the
// image, so outlines near the top sat low. The 8 handles stay on the cloth's edges; the trim
// says how much painting each edge lost, and the app fits the painting inside the cloth.

private let output = PixelSize(width: 1920, height: 1080)
private func cal() -> Calibration { .defaultFor(artworkAspect: 1.2, output: output) }

@Test func noTrimLeavesThePaintingWhereItWas() {
    let p = cal().clothPoint(artwork: .init(x: 0.3, y: 0.2))
    #expect(abs(p.x - 0.3) < 1e-12 && abs(p.y - 0.2) < 1e-12)
}

@Test func aTopTrimLiftsThePaintingMostAtTheTop() {
    var c = cal()
    c.trimInches = [0.5, 0, 0, 0]                       // half an inch of painting lost at the top
    let t = 0.5 / Calibration.tapestryInches.h
    #expect(abs(c.clothPoint(artwork: .init(x: 0.5, y: t)).y) < 1e-12)       // that row is now the cloth's top
    #expect(abs(c.clothPoint(artwork: .init(x: 0.5, y: 1)).y - 1) < 1e-12)   // the bottom stays put
    let head = c.clothPoint(artwork: .init(x: 0.75, y: 0.2)).y, feet = c.clothPoint(artwork: .init(x: 0.75, y: 0.8)).y
    #expect(0.2 - head > 0.8 - feet && 0.8 - feet > 0)   // everything moves up, the top most
}

@Test func trimMovesInSixteenthsAndStaysSensible() {
    var c = cal()
    c.trim(.top, steps: 3)
    #expect(c.trimInches == [3.0 / 16, 0, 0, 0])
    c.trim(.left, steps: -2)
    #expect(c.trimInches[3] == 0)                       // never negative
    c.trim(.bottom, steps: 1000)
    #expect(c.trimInches[2] == Calibration.maxTrimInches)
    #expect(c.isTrimmed)
}

@Test func oldSavesLoadWithNoTrimAndNewOnesKeepIt() throws {
    let old = #"{"artworkAspect":1.2,"output":{"width":1920,"height":1080},"corners":[{"x":0.1,"y":0.1},{"x":0.9,"y":0.1},{"x":0.9,"y":0.9},{"x":0.1,"y":0.9}]}"#
    let c = try JSONDecoder().decode(Calibration.self, from: Data(old.utf8))
    #expect(c.trimInches == [0, 0, 0, 0] && !c.isTrimmed)
    var t = cal(); t.trim(.top, steps: 4)
    let back = try JSONDecoder().decode(Calibration.self, from: JSONEncoder().encode(t))
    #expect(back.trimInches == t.trimInches)
}

@Test func thePhoneTrimsThroughTheAlignmentSession() throws {
    var s = CalibrationSession(start: cal())
    s.handle(.trim(.top, 2))
    #expect(s.calibration.trimInches[0] == 2.0 / 16)
    #expect(s.alignmentState.trimInches == s.calibration.trimInches)
    let cmd = PhoneCommand.align(.trim(.top, 1))
    #expect(try JSONDecoder().decode(PhoneCommand.self, from: LineFramer.frame(cmd).dropLast()) == cmd)
}
