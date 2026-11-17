import Foundation
import Testing
@testable import WildernessCore

// The light drifting between subjects (docs/superpowers/plans/2026-11-16-drift-and-parity.md).

private func fig(_ id: String, _ x: Double, _ y: Double) -> Annotation {
    Annotation(id: id, title: id, short: "", extended: "", references: [], evidence: .documented,
               anchor: .init(x: x, y: y),
               outline: [.init(x: x - 0.02, y: y - 0.02), .init(x: x + 0.02, y: y - 0.02), .init(x: x, y: y + 0.02)],
               textSide: .left, geometrySource: "test")
}
// Christ on the right; the lion next to him; the stag far left; the raven top left.
private let lib = AnnotationLibrary(artworkAspect: 1.2, annotations: [
    fig("stag", 0.2, 0.6), fig("christ", 0.75, 0.5), fig("raven", 0.2, 0.2), fig("lion", 0.9, 0.8)])

@Test func theTourStartsAtChristAndAlwaysStepsToTheNearestFigure() {
    #expect(Drift.tour(lib) == ["christ", "lion", "stag", "raven"])
}

private let path = ["a", "b", "c"]

@Test func theLightHoldsThenCrossFadesAtEachBoundary() {
    let w = { (t: Double) in Drift.weights(at: t, path: path, dwell: 40, fade: 10, loops: true) }
    #expect(w(20) == ["a": 1])
    #expect(w(34.9) == ["a": 1])
    let mid = w(40)
    #expect(abs(mid["a"]! - 0.5) < 1e-9 && abs(mid["b"]! - 0.5) < 1e-9)
    #expect(w(60) == ["b": 1])
    #expect(w(3 * 40 + 20) == ["a": 1])   // loops back to the start
}

@Test func theWeightsAlwaysSumToOneAndNeverJump() {
    var last: [String: Double]? = nil
    for k in 0..<3000 {
        let t = Double(k) * 0.05
        let w = Drift.weights(at: t, path: path, dwell: 40, fade: 10, loops: true)
        #expect(abs(w.values.reduce(0, +) - 1) < 1e-9)
        if let l = last {
            for id in path { #expect(abs((w[id] ?? 0) - (l[id] ?? 0)) < 0.02) }
        }
        last = w
    }
}

@Test func aWalkThatDoesNotLoopFadesInAndOut() {
    let w = { (t: Double) in Drift.weights(at: t, path: path, dwell: 40, fade: 10, loops: false) }
    #expect(w(-1).isEmpty)
    #expect(abs(w(2.5)["a"]! - 0.5) < 1e-9)       // half way through fading in
    #expect(w(20) == ["a": 1])
    #expect(abs(w(120 - 2.5)["c"]! - 0.5) < 1e-9) // half way through fading out at the end
    #expect(w(121).isEmpty)
}


@Test func driftingLightHasASettingThatOldProfilesReadAsOn() throws {
    #expect(Tuning.defaults.drift == 0.5)
    let t = try JSONDecoder().decode(Tuning.self, from: Data(#"{"seasons":true}"#.utf8))
    #expect(t.drift == 0.5)
    var u = Tuning(); u.drift = 0
    #expect(try JSONDecoder().decode(Tuning.self, from: JSONEncoder().encode(u)).drift == 0)
}
