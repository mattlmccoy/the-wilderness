import Foundation

/// How firmly a statement is supported. Shown to the viewer; never collapsed into one voice.
public enum Evidence: String, Codable, Sendable {
    case documented            // stated by the Met or primary sources
    case iconographicTradition // established Christian symbolism, not specific to this painting
    case plausible             // reasonable interpretation, not established for this work
    case speculative           // reconstruction or conjecture
}

public enum TextSide: String, Codable, Sendable { case left, right }

public enum Testament: String, Codable, Sendable { case old, new }

/// Modern translations for clarity; DRA (Douay-Rheims, the Vulgate in English) where it explains
/// what Moretto painted, e.g. the basilisk of Psalm 90:13.
public enum Translation: String, Codable, Sendable, CaseIterable { case niv = "NIV", esv = "ESV", nlt = "NLT", dra = "DRA" }

/// Whether the New Testament itself makes the link, or it is a traditional Christian reading.
public enum Connection: String, Codable, Sendable { case inScripture, christianReading }

public struct Verse: Codable, Equatable, Sendable {
    public var ref: String
    public var text: String
    public var testament: Testament
    public var translation: Translation
}

/// What the second press shows: one line of story, then the verses (Old Testament first).
public struct More: Codable, Equatable, Sendable {
    public var story: String
    public var verses: [Verse]
    public var connection: Connection
    /// True until Matt has approved the wording.
    public var draft: Bool
}

/// Word limits for wall copy (spec §7). Enforced on shipped, approved copy by tests.
public enum WordLimits {
    public static let short = 15, story = 25, verse = 20
    public static func count(_ s: String) -> Int { s.split(whereSeparator: \.isWhitespace).count }
}

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
    /// Story and verses for the second press. nil until the copy pass.
    public var more: More? = nil
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
            if let m = a.more { try validate(m, id: a.id) }
        }
        return lib
    }

    static func validate(_ m: More, id: String) throws {
        let blank = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !blank(m.story) else { throw ValidationError.invalid("\(id): more.story is empty") }
        guard !m.verses.isEmpty else { throw ValidationError.invalid("\(id): more has no verses") }
        for v in m.verses where blank(v.ref) || blank(v.text) {
            throw ValidationError.invalid("\(id): a verse is missing its reference or text")
        }
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

extension Translation {
    /// NIV, ESV and NLT are copyrighted and may be quoted only with their notice (spec §7).
    /// Douay-Rheims is public domain.
    public var needsNotice: Bool { self != .dra }
}

/// Bible translation copyright notices shown in Settings → About, keyed by abbreviation.
public struct Notices: Codable, Sendable {
    public var notices: [String: String]
    public static func decode(_ data: Data) throws -> Notices { try JSONDecoder().decode(Notices.self, from: data) }
}
