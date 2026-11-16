import Foundation

/// A rare moment at rest: about three an evening, at times seeded by the date.
public struct Moment: Equatable, Hashable, Sendable {
    public enum Kind: CaseIterable, Sendable { case stagLeaps, ravenGlints, angelsBrighten }
    public var kind: Kind
    /// Minutes after local midnight.
    public var minute: Int
    public static let duration = 8.0
}

public enum Moments {
    /// Three moments between 18:00 and 23:00, one in each 100-minute window, each kind once.
    public static func schedule(for day: CivilDate) -> [Moment] {
        var rng = SplitMix(seed: UInt64(day.year * 10_000 + day.month * 100 + day.day))
        var kinds = Moment.Kind.allCases
        for i in stride(from: kinds.count - 1, to: 0, by: -1) { kinds.swapAt(i, Int(rng.next() % UInt64(i + 1))) }
        return kinds.enumerated().map { i, k in Moment(kind: k, minute: 18 * 60 + i * 100 + 5 + Int(rng.next() % 90)) }
    }

    public static func active(at date: Date, calendar: Calendar = .current) -> Moment? {
        let day = CivilDate(date, calendar: calendar)
        let start = calendar.startOfDay(for: date)
        return schedule(for: day).first { m in
            let t = date.timeIntervalSince(start) - Double(m.minute * 60)
            return t >= 0 && t < Moment.duration
        }
    }
}

struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// ↑ ↑ ↓ ↓ ← → ← → Select: the dreamcoat. Watches the last nine presses.
public struct SecretCode: Equatable, Sendable {
    public static let sequence: [AppInput] = [.move(.up), .move(.up), .move(.down), .move(.down),
                                              .move(.left), .move(.right), .move(.left), .move(.right), .select]
    private var recent: [AppInput] = []
    public init() {}

    /// True when this press completes the code (which then starts over).
    public mutating func feed(_ input: AppInput) -> Bool {
        recent.append(input)
        if recent.count > Self.sequence.count { recent.removeFirst() }
        guard recent == Self.sequence else { return false }
        recent = []
        return true
    }
}

/// Where Be still has got to: figure n of m.
public struct SlowProgress: Codable, Equatable, Sendable {
    public var figure: Int
    public var of: Int
    public init(figure: Int, of: Int) { self.figure = figure; self.of = of }
}

/// Seven minutes of slow looking: Christ, then each figure, then Christ again, light only.
public enum SlowLooking {
    public static let secondsPerFigure = 35.0

    public static func path(ids: [String]) -> [String] {
        ["christ"] + ids.filter { $0 != "christ" } + ["christ"]
    }
    public static func total(ids: [String]) -> Double { Double(path(ids: ids).count) * secondsPerFigure }
    public static func figure(at t: Double, ids: [String]) -> String? {
        let p = path(ids: ids), i = Int(t / secondsPerFigure)
        return t >= 0 && i < p.count ? p[i] : nil
    }
}

/// Late in the evening the wall settles to breathing only, then lets the Apple TV sleep.
public struct WindDown: Equatable, Sendable {
    public enum Phase: Equatable, Sendable { case awake, settling, sleeping }
    public var startMinute: Int
    public static let settleMinutes = 30, wakeMinute = 5 * 60
    public init(startMinute: Int = 22 * 60 + 30) { self.startMinute = startMinute }

    public func phase(at date: Date, calendar: Calendar = .current) -> Phase {
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let m = c.hour! * 60 + c.minute!
        if m < Self.wakeMinute || m >= startMinute + Self.settleMinutes { return .sleeping }
        return m >= startMinute ? .settling : .awake
    }
}

/// Repeatable scatter for the snow and other sprinkled light: a value in 0..<1 for item `i`, channel `k`.
public enum Scatter {
    public static func unit(_ i: Int, _ k: Int) -> Double {
        var g = SplitMix(seed: UInt64(truncatingIfNeeded: i) &* 0x1000_0000_01B3 &+ UInt64(truncatingIfNeeded: k))
        return Double(g.next() >> 11) / Double(1 << 53)
    }
}
