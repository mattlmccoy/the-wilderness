import Testing
@testable import WildernessCore

@Test func wakingRisesOverThreeSeconds() {
    #expect(LightTiming.duration(from: [], to: ["christ"]) == 3)
}

@Test func returningToStillnessFallsOverSixSeconds() {
    #expect(LightTiming.duration(from: ["christ"], to: []) == 6)
}

@Test func movingBetweenSubjectsCrossFadesIn1point6Seconds() {
    #expect(LightTiming.duration(from: ["christ"], to: ["angels"]) == 1.6)
    #expect(LightTiming.duration(from: ["whole"], to: ["stag", "fox"]) == 1.6)
}

@Test func lightsFromEarlierMovesAreStaleAndFadeFast() {
    // Five quick presses: angels and basilisk are still fading when stag arrives.
    let stale = LightTiming.staleLights(visible: ["angels", "basilisk", "fox"], old: ["fox"], new: ["stag"])
    #expect(stale == ["angels", "basilisk"])
    #expect(LightTiming.staleFade < LightTiming.crossFade)
}

@Test func finishedFadesLeaveTheLevelsSoTheyAreNoLongerDrawn() {
    let g = LightTiming.fadingOut
    #expect(g > 0)   // still "visible" mid-fade, so a quick press can speed it up
    let settled = LightTiming.settled(["christ": 1, "angels": g, "stag": 0])
    #expect(settled == ["christ": 1])
}
