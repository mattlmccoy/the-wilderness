import Foundation
import Testing
@testable import WildernessCore

// MARK: Breathing

private let ids = ["christ", "angels", "basilisk", "lion", "stag", "fox", "bear", "fragment", "pelican", "snake", "tree"]

@Test func christBreathesSlowestAtTwelveSeconds() {
    let b = Breathing(ids: ids)
    #expect(b.period(for: "christ") == 12)
    for id in ids where id != "christ" { #expect((7.0...11.0).contains(b.period(for: id))) }
}

@Test func startOffsetsAreEvenlySpacedSoNoTwoRegionsBreatheTogether() {
    let b = Breathing(ids: ids)
    let phases = ids.map { b.phase(for: $0) }.sorted()
    #expect(Set(phases).count == ids.count)
    for (x, y) in zip(phases, phases.dropFirst()) { #expect(abs((y - x) - 1.0 / 11) < 1e-9) }
}

@Test func theSameRegionsGetTheSameRhythmOnEveryLaunch() {
    // Order of the file must not matter, and nothing random is involved.
    let a = Breathing(ids: ids), b = Breathing(ids: ids.reversed())
    for id in ids {
        #expect(a.period(for: id) == b.period(for: id) && a.phase(for: id) == b.phase(for: id))
    }
}

@Test func breathStartsDarkWaitsItsTurnThenSwellsAndEases() {
    let b = Breathing(ids: ids), id = "angels", start = 100.0
    let p = b.period(for: id), delay = b.phase(for: id) * p
    #expect(b.breath(id: id, at: start, since: start) == 0)
    #expect(b.breath(id: id, at: start + delay, since: start) == 0)
    #expect(abs(b.breath(id: id, at: start + delay + p / 2, since: start) - 1) < 1e-9)
    #expect(abs(b.breath(id: id, at: start + delay + p, since: start)) < 1e-9)
    #expect(abs(b.breath(id: id, at: start + delay + p / 4, since: start) - 0.5) < 1e-9)
    #expect(b.breath(id: "not-a-region", at: start + 50, since: start) == 0)
}

@Test func breathesOnlyAtRestAndWhileTuning() {
    #expect(Breathing.isActive(.stillness))
    #expect(Breathing.isActive(.tuning))
    #expect(!Breathing.isActive(.menu(focus: .explore)))
    #expect(!Breathing.isActive(.explore(id: "christ", expanded: false)))
    #expect(!Breathing.isActive(.context(page: 0)))
    #expect(!Breathing.isActive(.intro(startedAt: 0)))
}

// MARK: Glints follow the breath

@Test func glintBiasPrefersRegionsThatAreBrightening() {
    let left = Point<ArtworkSpace>(x: 0.2, y: 0.5), right = Point<ArtworkSpace>(x: 0.8, y: 0.5)
    var points: [Point<ArtworkSpace>] = []
    for _ in 0..<50 { points += [left, right] }
    var s = GlintScheduler(points: points, params: GlintParams(), rng: SplitMix64(seed: 7), now: 0)
    s.weight = { p, _ in p.x < 0.5 ? 1 : 0 }
    var leftCount = 0
    for i in 0..<300 {
        s.fireNow(at: Double(i) * 10)
        if s.active(at: Double(i) * 10)!.point.x < 0.5 { leftCount += 1 }
    }
    #expect(leftCount > 250)   // unbiased would be about 150
}

@Test func glintsStayUnbiasedWithoutAWeight() {
    let points = [Point<ArtworkSpace>(x: 0.2, y: 0.5), Point<ArtworkSpace>(x: 0.8, y: 0.5)]
    var s = GlintScheduler(points: points, params: GlintParams(), rng: SplitMix64(seed: 7), now: 0)
    var leftCount = 0
    for i in 0..<300 {
        s.fireNow(at: Double(i) * 10)
        if s.active(at: Double(i) * 10)!.point.x < 0.5 { leftCount += 1 }
    }
    #expect((110...190).contains(leftCount))
}

@Test func glintWeightUsesTheBreathOfTheRegionUnderThePoint() {
    let b = Breathing(ids: ids)
    #expect(b.glintWeight(regionId: nil, at: 5, since: 0) == Breathing.outsideWeight)
    let id = "angels"
    let peak = b.phase(for: id) * b.period(for: id) + b.period(for: id) / 2
    #expect(abs(b.glintWeight(regionId: id, at: peak, since: 0) - 1) < 1e-9)
    // Never zero, so a dim region can still sparkle now and then.
    #expect(b.glintWeight(regionId: id, at: 0, since: 0) == Breathing.minimumWeight)
}

// MARK: Passing light

@Test func passingLightComesEveryFourMinutesAndLastsFortyFiveSeconds() {
    #expect(PassingLight.state(at: 0, since: 0) == nil)          // never right at launch
    #expect(PassingLight.state(at: 194, since: 0) == nil)
    let mid = PassingLight.state(at: 195 + 22.5, since: 0)!
    #expect(abs(mid.x - 0.5) < 1e-9)
    #expect(abs(mid.intensity - PassingLight.peak) < 1e-9)
    let early = PassingLight.state(at: 195.0001, since: 0)!
    #expect(early.x < -0.29 && early.intensity < 1e-6)
    #expect(PassingLight.state(at: 240.5, since: 0) == nil)      // between passes
    #expect(PassingLight.state(at: 240 + 195 + 22.5, since: 0) != nil)   // and again
    #expect(PassingLight.peak <= 0.08)
}

// MARK: Tuning

@Test func breathingAndPassingLightTuneOnTheWall() {
    let t = Tuning.defaults
    #expect(t.breathing == 0.06 && t.passingLight == false)
    var s = TuningSession(tuning: t)
    while s.row != .breathing { s.handle(.down) }
    #expect(s.rowLabel == "Breathing · 6%")
    s.handle(.right); #expect(abs(s.tuning.breathing - 0.08) < 1e-9)
    for _ in 0..<40 { s.handle(.left) }
    #expect(s.tuning.breathing == 0 && s.rowLabel == "Breathing · off")
    for _ in 0..<40 { s.handle(.right) }
    #expect(s.tuning.breathing == 0.3)
    s.handle(.down)
    #expect(s.row == .passingLight && s.rowLabel == "Passing light · off")
    s.handle(.right)
    #expect(s.tuning.passingLight && s.rowLabel == "Passing light · on")
}

@Test func olderSavedTuningGetsTheNewDefaults() throws {
    let old = #"{"subjectStrength":0.5,"baseWash":0,"exploreWashFactor":0.45,"glintMeanInterval":8,"glintBrightness":1,"glintSizeInches":0.06,"glintStyle":"thread","edgeLine":0.7}"#
    let t = try JSONDecoder().decode(Tuning.self, from: Data(old.utf8))
    #expect(t.subjectStrength == 0.5 && t.breathing == 0.06 && t.passingLight == false)
    var changed = Tuning.defaults
    changed.breathing = 0.2; changed.passingLight = true
    let back = try JSONDecoder().decode(Tuning.self, from: JSONEncoder().encode(changed))
    #expect(back == changed)
}

// MARK: Sun rays (the passing light, Matt 2026-11-11: "sun rays shining down from different angles")

@Test func sunRaysOnlyShowDuringAPass() {
    #expect(SunRays.frame(at: 0, since: 0) == nil)
    #expect(SunRays.frame(at: 194, since: 0) == nil)
    #expect(SunRays.frame(at: 195 + 22.5, since: 0) != nil)
}

@Test func eachPassComesFromItsOwnAngleWithThreeToFiveBeams() {
    var angles = Set<Int>()
    for pass in 0..<6 {
        let a = SunRays.frame(at: Double(pass) * 240 + 195 + 22.5, since: 0)!
        let b = SunRays.frame(at: Double(pass) * 240 + 195 + 22.5, since: 0)!
        #expect(a == b)                                   // the same pass always looks the same
        #expect((3...5).contains(a.beams.count))
        #expect(abs(a.angleDegrees) <= 40)                // from above, never sideways
        #expect((0...1).contains(a.originX))
        angles.insert(Int(a.angleDegrees.rounded()))
    }
    #expect(angles.count >= 4)                            // different angles across passes
}

@Test func raysAlwaysLeanBackAcrossTheTapestry() {
    for pass in 0..<12 {
        let f = SunRays.frame(at: Double(pass) * 240 + 195 + 22.5, since: 0)!
        // From the left they slant right, from the right they slant left (positive = rightward).
        #expect((f.originX < 0.5) == (f.angleDegrees > 0), "pass \(pass): origin \(f.originX), angle \(f.angleDegrees)")
        #expect(abs(f.angleDegrees) >= 8)
        #expect(f.beams.allSatisfy { (0.08...0.2).contains($0.width) })
    }
}

@Test func raysShineAcrossTheCanvasDuringAPass() {
    // Matt, 2026-11-15: "they don't really move — they should shine across the canvas".
    for pass in 0..<6 {
        let t0 = Double(pass) * 240 + 195.5, t1 = Double(pass) * 240 + 239.5
        let a = SunRays.frame(at: t0, since: 0)!, b = SunRays.frame(at: t1, since: 0)!
        #expect(abs(b.originX - a.originX) >= 0.4, "the light source travels across")
        let swing = abs(b.angleDegrees - a.angleDegrees)
        #expect(swing >= 15 && swing <= 30)
    }
    let mid = SunRays.frame(at: 195 + 22.5, since: 0)!
    #expect(mid.intensity >= 0.28 && mid.intensity <= 0.32)    // visible on the real wall
    #expect(SunRays.frame(at: 195.5, since: 0)!.intensity < 0.01)
}
