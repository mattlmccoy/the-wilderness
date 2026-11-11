import Foundation

/// Who the boot-up intro outlines, and in what order (approved by Matt, 2026-11-10:
/// "Christ first, then the beasts that bow, then the peaceable animals, then the angels").
/// Groups are traced one after another with a short breath between them; within a group the
/// lines overlap. The grouping follows the wall copy in App/Content/annotations.json.
public enum IntroOrder {
    public static let groups: [[String]] = [
        // Jesus Christ, alone, while the wall is otherwise dark.
        ["christ"],
        // The beasts that bow: the dangerous creatures that submit at His feet. The serpent
        // "slips beneath His bare foot" (Genesis 3:15), the lion "lies at the feet of the King
        // of kings", the basilisk "lies low near Him" (Psalm 91:13: lion and serpent trodden).
        // Within the group, nearest to Christ first, so the lines ripple outward from Him.
        ["snake", "lion", "basilisk"],
        // The peaceable animals: the creatures at rest with Him, Isaiah's peace ("With Jesus
        // Christ, the wild is at peace"). The pelican "bends low beside Him", the bear "lies in
        // the grass", the fox "rests a few steps from Him", the stag's longing "has found Him".
        // Nearest to Christ first.
        ["pelican", "raven", "beast", "bear", "fox", "stag"],
        // The angels who come to serve Him.
        ["angels"],
        // Not traced: the tree and the missing picture (cut-away cherubs at the edge) are not
        // figures gathered around Him.
    ]

    /// `order` without subjects that have no outline in `library` (nothing is invented),
    /// and without groups left empty.
    public static func groups(_ order: [[String]] = groups, in library: AnnotationLibrary) -> [[String]] {
        let outlined = Set(library.annotations.filter { $0.outline != nil }.map(\.id))
        return order.map { $0.filter(outlined.contains) }.filter { !$0.isEmpty }
    }
}

/// One subject's state at a moment of the intro: how much of its outline is drawn, how
/// strongly the line shows, and how strongly the faint glow that replaces it shows (all 0…1).
public struct IntroFrame: Equatable, Sendable {
    public var drawProgress: Double
    public var line: Double
    public var glow: Double
    public static let dark = IntroFrame(drawProgress: 0, line: 0, glow: 0)
}

/// The ~15 s boot-up intro as pure timing:
///  0.5–1.9 s   the first group (Christ) draws itself while the wall is dark;
///  2.2–9.9 s   the other groups draw in order, each line in under a second, overlapping,
///              with a longer breath between groups;
/// 10.0–12.5 s  each line softens into a faint glow over its figure, in the same order;
/// 12.5–15 s    all glows fade together, leaving Stillness.
public struct IntroTimeline: Sendable {
    public static let duration = 15.0
    public static let leadStart = 0.5, leadEnd = 1.9
    public static let traceStart = 2.2, traceEnd = 10.0
    public static let softenStart = 10.0, softenDuration = 1.5
    public static let fadeStart = 12.5

    public let groups: [[String]]
    /// How long each line after the first group takes to draw.
    public let drawDuration = 0.9
    private let starts: [String: Double]
    private let softenStarts: [String: Double]

    public init(groups: [[String]]) {
        self.groups = groups
        var starts: [String: Double] = [:]
        for id in groups.first ?? [] { starts[id] = Self.leadStart }
        // Intra-group neighbours are one step apart; a gap between groups counts as two.
        let rest = groups.dropFirst()
        let n = rest.reduce(0) { $0 + $1.count }
        let slots = max(n - 1, 0) + max(rest.count - 1, 0)
        let lastStart = Self.traceEnd - 0.1 - drawDuration
        let step = slots > 0 ? (lastStart - Self.traceStart) / Double(slots) : 0
        var slot = 0
        for (g, group) in rest.enumerated() {
            if g > 0 { slot += 1 }
            for (i, id) in group.enumerated() {
                if i > 0 || g > 0 { slot += 1 }
                starts[id] = Self.traceStart + Double(slot) * step
            }
        }
        self.starts = starts
        let all = groups.flatMap { $0 }
        let ripple = all.count > 1 ? min(0.1, 0.8 / Double(all.count - 1)) : 0
        self.softenStarts = Dictionary(uniqueKeysWithValues: all.enumerated().map { ($1, Self.softenStart + Double($0) * ripple) })
    }

    /// When `id` starts drawing, or nil if it is not in the intro.
    public func drawStart(_ id: String) -> Double? { starts[id] }

    public func frame(_ id: String, at t: Double) -> IntroFrame {
        guard let start = starts[id], let softenAt = softenStarts[id] else { return .dark }
        let lead = groups.first?.contains(id) ?? false
        let length = lead ? Self.leadEnd - Self.leadStart : drawDuration
        let drawn = Self.ease((t - start) / length)
        guard drawn > 0 else { return .dark }
        let soften = Self.ease((t - softenAt) / Self.softenDuration)
        let fade = 1 - Self.ease((t - Self.fadeStart) / (Self.duration - Self.fadeStart))
        return IntroFrame(drawProgress: drawn, line: 1 - soften, glow: soften * fade)
    }

    public static func isFinished(at elapsed: Double) -> Bool { elapsed >= duration }

    /// Smoothstep on 0…1, clamped: calm starts and ends, no sudden moves.
    static func ease(_ x: Double) -> Double {
        let c = min(max(x, 0), 1)
        return c * c * (3 - 2 * c)
    }
}
