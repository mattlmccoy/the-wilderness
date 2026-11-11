/// Turns the app timer's ticks into the time that really passed, so Unfold plays at wall-clock
/// speed even when a tick arrives late. A long gap (the app suspended, the Apple TV asleep) is
/// clamped to `maxStep`, so Unfold resumes where it was instead of skipping beats.
public struct TickClock: Sendable {
    public static let maxStep = 1.0
    private var last: Double?

    public init() {}

    /// Seconds since the previous tick, 0…maxStep. The first tick has nothing to measure: 0.
    public mutating func dt(now: Double) -> Double {
        defer { last = now }
        guard let last else { return 0 }
        return min(max(now - last, 0), Self.maxStep)
    }
}
