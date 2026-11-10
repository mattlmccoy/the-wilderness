import Foundation

/// One beat of Unfold: what lights up (in steps), for how long, and its text.
public struct UnfoldBeat: Codable, Equatable, Sendable {
    public var id: String
    public var duration: Double
    /// Steps in order; each step lights these targets together. "whole" means the whole tapestry.
    public var light: [[String]]
    public var textSide: TextSide
    public var title: String
    public var short: String
    public var more: More?
    public var draft: Bool

    public static let wholeTarget = "whole"
}

/// Where Unfold is: which beat, how far into it, and whether it is paused.
public struct UnfoldPlayback: Equatable, Sendable {
    public var beat: Int
    public var elapsed: Double
    public var paused: Bool
    public init(beat: Int, elapsed: Double, paused: Bool) {
        self.beat = beat; self.elapsed = elapsed; self.paused = paused
    }
    public static let start = UnfoldPlayback(beat: 0, elapsed: 0, paused: false)
}

/// The guided arc (spec §5.3), as data plus a pure timeline.
public struct UnfoldScript: Codable, Equatable, Sendable {
    public var beats: [UnfoldBeat]
    public static let allowedTotal: ClosedRange<Double> = 240...360

    public init(beats: [UnfoldBeat]) { self.beats = beats }

    /// Decodes and validates against the shipped subjects. Bad content fails loudly.
    public static func decode(_ data: Data, library: AnnotationLibrary) throws -> UnfoldScript {
        typealias Invalid = AnnotationLibrary.ValidationError
        let script = try JSONDecoder().decode(UnfoldScript.self, from: data)
        let ids = Set(library.annotations.map(\.id)).union([UnfoldBeat.wholeTarget])
        guard !script.beats.isEmpty else { throw Invalid.invalid("unfold has no beats") }
        for b in script.beats {
            guard b.duration > 0 else { throw Invalid.invalid("\(b.id): duration must be positive") }
            guard !b.light.isEmpty, b.light.allSatisfy({ !$0.isEmpty }) else {
                throw Invalid.invalid("\(b.id): every light step needs a target")
            }
            for t in b.light.joined() where !ids.contains(t) {
                throw Invalid.invalid("\(b.id): unknown light target \(t)")
            }
            if let m = b.more { try AnnotationLibrary.validate(m, id: b.id) }
        }
        let total = script.beats.reduce(0) { $0 + $1.duration }
        guard allowedTotal.contains(total) else {
            throw Invalid.invalid("unfold lasts \(Int(total)) s; expected \(Int(allowedTotal.lowerBound))–\(Int(allowedTotal.upperBound)) s")
        }
        return script
    }

    /// Moves time forward, carrying overflow into later beats. nil once the last beat ends.
    public func advance(_ p: UnfoldPlayback, by dt: Double) -> UnfoldPlayback? {
        guard !p.paused else { return p }
        var q = p
        q.elapsed += dt
        while q.beat < beats.count, q.elapsed >= beats[q.beat].duration {
            q.elapsed -= beats[q.beat].duration
            q.beat += 1
        }
        return q.beat < beats.count ? q : nil
    }

    public func next(_ p: UnfoldPlayback) -> UnfoldPlayback? {
        p.beat + 1 < beats.count ? UnfoldPlayback(beat: p.beat + 1, elapsed: 0, paused: p.paused) : nil
    }

    /// The previous beat, or the start of this one on the first beat.
    public func previous(_ p: UnfoldPlayback) -> UnfoldPlayback {
        UnfoldPlayback(beat: max(p.beat - 1, 0), elapsed: 0, paused: p.paused)
    }

    /// Which light step is showing; steps split the beat's duration evenly.
    public func step(_ p: UnfoldPlayback) -> Int {
        let b = beats[p.beat]
        let i = Int(p.elapsed / (b.duration / Double(b.light.count)))
        return min(max(i, 0), b.light.count - 1)
    }
}
