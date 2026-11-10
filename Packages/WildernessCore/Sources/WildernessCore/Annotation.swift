import Foundation

/// How firmly a statement is supported. Shown to the viewer; never collapsed into one voice.
public enum Evidence: String, Codable, Sendable {
    case documented            // stated by the Met or primary sources
    case iconographicTradition // established Christian symbolism, not specific to this painting
    case plausible             // reasonable interpretation, not established for this work
    case speculative           // reconstruction or conjecture
}

public enum TextSide: String, Codable, Sendable { case left, right }

public struct Annotation: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var short: String
    public var extended: String
    public var references: [String]
    public var evidence: Evidence
    /// Where the detail sits on the tapestry; drives remote navigation and focus light.
    public var anchor: Point<ArtworkSpace>
    /// Outline traced on the tapestry photo. nil until traced — never invented.
    public var outline: [Point<ArtworkSpace>]?
    public var textSide: TextSide
    /// Provenance of the geometry, e.g. "met-reference-estimate" or "tapestry-photo-trace".
    public var geometrySource: String
}

public struct AnnotationLibrary: Codable, Sendable {
    public var artworkAspect: Double
    public var annotations: [Annotation]

    public enum ValidationError: Error, CustomStringConvertible {
        case invalid(String)
        public var description: String { if case let .invalid(m) = self { return m }; return "" }
    }

    /// Decodes and validates. Bad content fails loudly rather than rendering in the wrong place.
    public static func decode(_ data: Data) throws -> AnnotationLibrary {
        let lib = try JSONDecoder().decode(AnnotationLibrary.self, from: data)
        var seen = Set<String>()
        for a in lib.annotations {
            guard seen.insert(a.id).inserted else { throw ValidationError.invalid("duplicate id \(a.id)") }
            let pts = [a.anchor] + (a.outline ?? [])
            guard pts.allSatisfy({ (0...1).contains($0.x) && (0...1).contains($0.y) }) else {
                throw ValidationError.invalid("\(a.id): geometry outside the artwork (0...1)")
            }
            if let o = a.outline, o.count < 3 { throw ValidationError.invalid("\(a.id): outline needs 3+ points") }
        }
        return lib
    }
}

/// Remote navigation by physical position: pressing right moves to the nearest detail
/// to the right on the wall, not to the next item in a list.
public enum SpatialNavigator {
    /// Only details within ±60° of the pressed direction are candidates.
    static let coneSlope = 1.732

    public static func next(from current: Annotation, direction: NudgeDirection,
                            among all: [Annotation], artworkAspect: Double) -> Annotation? {
        let (dx, dy): (Double, Double) = switch direction {
        case .left: (-1, 0)
        case .right: (1, 0)
        case .up: (0, -1)
        case .down: (0, 1)
        }
        return all
            .filter { $0.id != current.id }
            .compactMap { cand -> (Annotation, Double)? in
                // Physical units: stretch x by the aspect so a step is a step on the wall.
                let vx = (cand.anchor.x - current.anchor.x) * artworkAspect
                let vy = cand.anchor.y - current.anchor.y
                let along = vx * dx + vy * dy
                let perp = abs(vx * dy - vy * dx)
                guard along > 1e-9, perp <= along * coneSlope else { return nil }
                return (cand, along + perp)
            }
            .min { $0.1 < $1.1 }?.0
    }
}
