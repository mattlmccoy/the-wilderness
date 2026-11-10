import Foundation
import Testing
@testable import WildernessCore

private let points: [Point<ArtworkSpace>] = (0..<50).map { i in .init(x: Double(i) / 50, y: 0.5) }

/// Samples the scheduler like a 20 fps display and returns each distinct glint once.
private func distinctGlints(seconds: Double, step: Double = 0.05, seed: UInt64 = 7) -> [Glint] {
    var s = GlintScheduler(points: points, params: GlintParams(), rng: SplitMix64(seed: seed), now: 0)
    var out: [Glint] = []
    var t = 0.0
    while t < seconds {
        if let g = s.active(at: t), out.last != g { out.append(g) }
        t += step
    }
    return out
}

@Test func neverTwoAtOnce() {
    let gs = distinctGlints(seconds: 3600)
    #expect(gs.count > 100)
    for (a, b) in zip(gs, gs.dropFirst()) {
        #expect(b.start >= a.start + a.life + GlintParams().minGap - 1e-9)
    }
}

@Test func meanIntervalIsAboutEightSeconds() {
    let gs = distinctGlints(seconds: 20_000, step: 0.1)
    let gaps = zip(gs, gs.dropFirst()).map { $1.start - $0.start }
    let mean = gaps.reduce(0, +) / Double(gaps.count)
    #expect((7.2...10.6).contains(mean), "mean gap \(mean)")
}

@Test func intensityIsZeroAtEdgesAndPeaksInTheMiddle() {
    let g = Glint(point: points[0], start: 10, life: 1.2, peak: 0.8, direction: 1)
    #expect(g.intensity(at: 10) < 1e-9 && g.intensity(at: 11.2) < 1e-9)
    #expect(abs(g.intensity(at: 10.6) - 0.8) < 1e-9)
    #expect(g.intensity(at: 9) == 0 && g.intensity(at: 12) == 0)
}

@Test func glintsComeOnlyFromTheGivenPoints() {
    let set = Set(points.map { "\($0.x),\($0.y)" })
    for g in distinctGlints(seconds: 600) { #expect(set.contains("\(g.point.x),\(g.point.y)")) }
}

@Test func noPointsMeansNoGlints() {
    var s = GlintScheduler(points: [], params: GlintParams(), rng: SplitMix64(seed: 1), now: 0)
    #expect((0..<1000).allSatisfy { s.active(at: Double($0)) == nil })
}

@Test func fireNowStartsAGlintImmediately() {
    var s = GlintScheduler(points: points, params: GlintParams(), rng: SplitMix64(seed: 3), now: 0)
    s.fireNow(at: 0.5)
    #expect(s.active(at: 0.6)?.start == 0.5)
}

@Test func emptyGlintFileIsRejected() {
    #expect(throws: (any Error).self) { try GlintPoints.decode(Data(#"{"source":"x","points":[]}"#.utf8)) }
    #expect(throws: (any Error).self) { try GlintPoints.decode(Data(#"{"source":"x","points":[{"x":1.5,"y":0.2}]}"#.utf8)) }
}
