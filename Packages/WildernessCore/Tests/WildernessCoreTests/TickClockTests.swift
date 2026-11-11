import Testing
@testable import WildernessCore

@Test func firstTickHasNothingToMeasure() {
    var c = TickClock()
    #expect(c.dt(now: 100) == 0)
}

@Test func dtIsTheRealTimeSinceThePreviousTick() {
    var c = TickClock()
    _ = c.dt(now: 100)
    #expect(abs(c.dt(now: 100.25) - 0.25) < 1e-9)
    // A late timer: the next tick arrives 0.6 s later and Unfold must advance 0.6 s, not 0.25.
    #expect(abs(c.dt(now: 100.85) - 0.6) < 1e-9)
}

@Test func aLongGapIsClampedSoASuspendedAppDoesNotSkipBeats() {
    var c = TickClock()
    _ = c.dt(now: 100)
    #expect(c.dt(now: 400) == TickClock.maxStep)
    #expect(TickClock.maxStep == 1)
    #expect(abs(c.dt(now: 400.25) - 0.25) < 1e-9)   // measured from the late tick, not before it
}

@Test func aClockThatStepsBackwardsNeverRewinds() {
    var c = TickClock()
    _ = c.dt(now: 100)
    #expect(c.dt(now: 99) == 0)
}
