import Foundation

/// Small, fast, seedable generator so glint timing is reproducible in tests.
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64
    public init(seed: UInt64) { state = seed }
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

public enum GlintStyle: String, Codable, Sendable { case thread, pinpoint }

/// Glint rhythm (spec §4.1). Defaults are the round-3 values; all are tuned on the wall.
public struct GlintParams: Equatable, Sendable {
    public var meanInterval = 8.0
    public var minGap = 1.5
    public var life: ClosedRange<Double> = 1.2...2.2
    public var peak: ClosedRange<Double> = 0.75...1.0
    public init() {}
}

/// One glint: where, when, and how bright at its peak.
public struct Glint: Equatable, Sendable {
    public var point: Point<ArtworkSpace>
    public var start: Double
    public var life: Double
    public var peak: Double
    /// +1 or -1: which way a "thread" glint slides.
    public var direction: Double

    /// How far it drifts over its life, as a fraction of the artwork (a small star shifting).
    public var driftX: Double = 0
    public var driftY: Double = 0

    public init(point: Point<ArtworkSpace>, start: Double, life: Double, peak: Double, direction: Double,
                driftX: Double = 0, driftY: Double = 0) {
        self.point = point; self.start = start; self.life = life; self.peak = peak; self.direction = direction
        self.driftX = driftX; self.driftY = driftY
    }

    /// Where it is now: drifting smoothly from its point along its own direction.
    public func position(at t: Double) -> Point<ArtworkSpace> {
        let p = min(max(progress(at: t), 0), 1)
        let eased = p * p * (3 - 2 * p)
        return Point(x: point.x + driftX * eased, y: point.y + driftY * eased)
    }

    public var end: Double { start + life }
    public func progress(at t: Double) -> Double { (t - start) / life }

    /// Smooth sin² rise and fall; zero outside the glint's life.
    public func intensity(at t: Double) -> Double {
        let p = progress(at: t)
        guard (0...1).contains(p) else { return 0 }
        let s = sin(Double.pi * p)
        // A gentle twinkle: three soft dips over its life, none at the peak.
        let w = sin(2 * Double.pi * 3 * p)
        return peak * s * s * (1 - 0.2 * w * w)
    }
}

/// One glint at a time, at random (Poisson) intervals, never closer than `minGap` apart.
public struct GlintScheduler<R: RandomNumberGenerator> {
    public var params: GlintParams
    /// Optional preference, 0…1, for a point at a time (the breath of the region under it).
    /// A candidate is kept with that probability; after a few tries the last one stands.
    public var weight: ((Point<ArtworkSpace>, Double) -> Double)?
    static var weightedTries: Int { 8 }
    private let points: [Point<ArtworkSpace>]
    private var rng: R
    private var current: Glint?
    private var nextStart: Double

    public init(points: [Point<ArtworkSpace>], params: GlintParams, rng: R, now: Double) {
        self.points = points; self.params = params; self.rng = rng
        self.nextStart = 0
        self.nextStart = now + gap()
    }

    /// The live glint at `now`, if any. Ends expired glints and starts due ones.
    public mutating func active(at now: Double) -> Glint? {
        if let g = current {
            if now < g.end { return g }
            current = nil
            nextStart = g.end + gap()
        }
        guard !points.isEmpty, now >= nextStart else { return nil }
        current = make(at: now)
        return current
    }

    /// Starts a glint right away (the tuning screen's demo).
    public mutating func fireNow(at now: Double) {
        guard !points.isEmpty else { return }
        current = make(at: now)
    }

    private mutating func gap() -> Double {
        let u = Double.random(in: 0..<1, using: &rng)
        return max(params.minGap, -params.meanInterval * log(1 - u))
    }

    private mutating func pick(at t: Double) -> Point<ArtworkSpace> {
        var p = points[Int.random(in: 0..<points.count, using: &rng)]
        guard let weight else { return p }
        for _ in 1..<Self.weightedTries {
            if Double.random(in: 0..<1, using: &rng) < weight(p, t) { break }
            p = points[Int.random(in: 0..<points.count, using: &rng)]
        }
        return p
    }

    private mutating func make(at t: Double) -> Glint {
        Glint(point: pick(at: t), start: t,
              life: Double.random(in: params.life, using: &rng),
              peak: Double.random(in: params.peak, using: &rng),
              direction: Bool.random(using: &rng) ? 1 : -1,
              driftX: 0, driftY: 0).drifting(angle: Double.random(in: 0..<(2 * .pi), using: &rng),
                                             distance: Double.random(in: 0.009...0.016, using: &rng))
    }
}

/// Candidate glint points, precomputed offline by scripts/make_glints.py.
public struct GlintPoints: Codable, Sendable {
    public var source: String
    public var points: [Point<ArtworkSpace>]

    public static func decode(_ data: Data) throws -> GlintPoints {
        let g = try JSONDecoder().decode(GlintPoints.self, from: data)
        guard !g.points.isEmpty else { throw AnnotationLibrary.ValidationError.invalid("glints.json has no points") }
        guard g.points.allSatisfy({ (0...1).contains($0.x) && (0...1).contains($0.y) }) else {
            throw AnnotationLibrary.ValidationError.invalid("glints.json has points outside the artwork (0...1)")
        }
        return g
    }
}

extension Glint {
    func drifting(angle: Double, distance: Double) -> Glint {
        var g = self
        g.driftX = cos(angle) * distance
        g.driftY = sin(angle) * distance
        return g
    }
}
