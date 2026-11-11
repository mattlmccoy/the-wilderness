import Foundation

/// The wall at rest breathes: each traced region's light slowly swells and eases on its own
/// cycle. Start offsets are spread evenly across the regions (sorted by id, so the file's
/// order doesn't matter) and periods by the golden ratio, so no two ever pulse together.
/// Christ is the slowest and steadiest. The app draws a region at
/// `Tuning.breathing × breath(...)` opacity; nothing here draws.
public struct Breathing: Sendable {
    public static let christPeriod = 12.0
    public static let periodRange = 7.0...11.0
    /// A glint outside every region is as likely as one in a region at 30% breath.
    public static let outsideWeight = 0.3
    /// A region at the bottom of its breath can still sparkle, just rarely.
    public static let minimumWeight = 0.15

    private let rhythm: [String: (period: Double, phase: Double)]

    public init(ids: [String]) {
        let sorted = Array(Set(ids)).sorted()
        var r: [String: (period: Double, phase: Double)] = [:]
        for (k, id) in sorted.enumerated() {
            let golden = (Double(k) * 0.618_033_988_75).truncatingRemainder(dividingBy: 1)
            let period = id == "christ" ? Self.christPeriod
                : Self.periodRange.lowerBound + golden * (Self.periodRange.upperBound - Self.periodRange.lowerBound)
            r[id] = (period, Double(k) / Double(sorted.count))
        }
        rhythm = r
    }

    /// Seconds for one full breath (in and out); 0 for an unknown id.
    public func period(for id: String) -> Double { rhythm[id]?.period ?? 0 }

    /// Fraction of a period this region waits before its first breath, 0..<1.
    public func phase(for id: String) -> Double { rhythm[id]?.phase ?? 0 }

    /// 0…1. Dark until the region's turn, then 0.5 − 0.5·cos: in for half a period, out for half.
    /// `since` is when breathing began (the view's first appearance). 0 for an unknown id.
    public func breath(id: String, at t: Double, since start: Double) -> Double {
        guard let r = rhythm[id] else { return 0 }
        let elapsed = t - start - r.phase * r.period
        guard elapsed > 0 else { return 0 }
        return 0.5 - 0.5 * cos(2 * Double.pi * elapsed / r.period)
    }

    /// Only at rest (and on the tuning screen, so it can be set). Text and lit figures pause it.
    public static func isActive(_ mode: Mode) -> Bool {
        switch mode {
        case .stillness, .tuning: true
        default: false
        }
    }

    /// How strongly a glint prefers a point: the breath of the region under it.
    public func glintWeight(regionId: String?, at t: Double, since start: Double) -> Double {
        guard let regionId else { return Self.outsideWeight }
        return max(Self.minimumWeight, breath(id: regionId, at: t, since: start))
    }
}

/// Now and then a soft band of light drifts slowly across the whole tapestry, left to right,
/// like sun through passing cloud. Off unless switched on in Tune light.
public enum PassingLight {
    /// Seconds from the start of one pass to the next.
    public static let every = 240.0
    public static let duration = 45.0
    /// Opacity at the middle of a pass.
    public static let peak = 0.06

    /// The band's centre (fraction of the width, travelling −0.3 → 1.3) and opacity, or nil
    /// between passes. The first pass comes 3¼ minutes after `since`, never at launch.
    public static func state(at t: Double, since start: Double) -> (x: Double, intensity: Double)? {
        let phase = (t - start).truncatingRemainder(dividingBy: every)
        let begin = every - duration
        guard phase >= begin else { return nil }
        let p = (phase - begin) / duration
        let s = sin(Double.pi * p)
        return (x: -0.3 + 1.6 * p, intensity: peak * s * s)
    }
}
