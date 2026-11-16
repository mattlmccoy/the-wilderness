import Foundation

/// Where the Thanksgiving turkey runs: along the far hill, then through the foreground, in from one
/// edge and off the other (App/Content/delights.json, "turkey"). Points are 0–1 of the canvas;
/// `y` is where its feet touch the ground. Sizes are its height as a fraction of the canvas width.
public struct TurkeyPaths: Codable, Equatable, Sendable {
    public var hill: [DelightsContent.Place]
    public var hillSize: Double
    public var ground: [DelightsContent.Place]
    public var groundSize: Double
    public init(hill: [DelightsContent.Place], hillSize: Double, ground: [DelightsContent.Place], groundSize: Double) {
        self.hill = hill; self.hillSize = hillSize; self.ground = ground; self.groundSize = groundSize
    }
}

/// The turkey's run (docs/superpowers/plans/2026-11-16-thanksgiving-and-phone.md): about 7 s across
/// the hill, two seconds out of sight, about 7 s through the foreground.
public enum Turkey {
    public static let hillSeconds = 7.0
    public static let groundStart = 9.0
    public static let groundSeconds = 7.0
    public static var runSeconds: Double { groundStart + groundSeconds }
    /// Every ten minutes; every ninety seconds when Thanksgiving is switched on by hand, to show it off.
    public static let everySeconds = 600.0
    public static func every(forced: Bool) -> Double { forced ? 90 : everySeconds }

    public struct Pose: Equatable, Sendable {
        public var x, y, size: Double
        public var facingRight: Bool
        public var onHill: Bool
        /// Seconds into this leg, for the legs and the bob.
        public var seconds: Double
    }

    public static func pose(at t: Double, every: Double, paths: TurkeyPaths) -> Pose? {
        let k = t.truncatingRemainder(dividingBy: every)
        func along(_ p: [DelightsContent.Place], _ f: Double, size: Double, hill: Bool, s: Double) -> Pose? {
            guard p.count >= 2 else { return nil }
            let a = p[0], b = p[p.count - 1]
            return Pose(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f, size: size,
                        facingRight: b.x >= a.x, onHill: hill, seconds: s)
        }
        if k < hillSeconds { return along(paths.hill, k / hillSeconds, size: paths.hillSize, hill: true, s: k) }
        if k >= groundStart, k < runSeconds {
            let s = k - groundStart
            return along(paths.ground, s / groundSeconds, size: paths.groundSize, hill: false, s: s)
        }
        return nil
    }
}
