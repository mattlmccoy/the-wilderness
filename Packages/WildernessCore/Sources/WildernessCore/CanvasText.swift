import Foundation

/// A calm, dark place on the painting where wall text reads well (App/Content/textzones.json,
/// from scripts/make_text_zones.py). Fractions of the artwork.
public struct TextZone: Codable, Equatable, Sendable {
    public var x, y, w, h: Double
    public var score: Double
    public init(x: Double, y: Double, w: Double, h: Double, score: Double) {
        self.x = x; self.y = y; self.w = w; self.h = h; self.score = score
    }
    var centre: (x: Double, y: Double) { (x + w / 2, y + h / 2) }
}

public struct TextZones: Codable, Sendable {
    public var zones: [TextZone]
    public static let empty = TextZones(zones: [])
    public init(zones: [TextZone]) { self.zones = zones }
    public static func decode(_ data: Data) throws -> TextZones {
        let z = try JSONDecoder().decode(TextZones.self, from: data)
        guard !z.zones.isEmpty else { throw AnnotationLibrary.ValidationError.invalid("textzones.json has no zones") }
        return z
    }
}

/// Where wall text goes when there is no room beside the tapestry (Matt's wall): on the painting,
/// in the nearest calm zone that covers neither the figure being described nor Christ.
public enum CanvasText {
    /// Keep text this far (fraction of the artwork) from a figure's outline.
    static let clearance = 0.02

    public static func zone(for subjectId: String, library: AnnotationLibrary, zones: [TextZone]) -> TextZone? {
        let subject = library.annotations.first { $0.id == subjectId }
        let avoid = ([subject] + [library.annotations.first { $0.id == "christ" }]).compactMap { $0?.outline }
        let allowed = zones.filter { z in !avoid.contains { overlaps(z, $0) } }
        guard let s = subject else { return allowed.first ?? zones.first }
        let anchor = (x: s.anchor.x, y: s.anchor.y)
        let near = allowed.min { dist($0.centre, anchor) < dist($1.centre, anchor) }
        return near ?? zones.first { z in !(s.outline.map { overlaps(z, $0) } ?? false) } ?? zones.first
    }

    /// Context and Unfold: one steady place, the best zone that does not cover Christ.
    public static func readingZone(library: AnnotationLibrary, zones: [TextZone]) -> TextZone? {
        let christ = library.annotations.first { $0.id == "christ" }?.outline
        return zones.first { z in !(christ.map { overlaps(z, $0) } ?? false) } ?? zones.first
    }

    /// Does the zone touch the outline's bounding box (plus clearance)?
    public static func overlaps(_ z: TextZone, _ outline: [Point<ArtworkSpace>]) -> Bool {
        guard let x0 = outline.map(\.x).min(), let x1 = outline.map(\.x).max(),
              let y0 = outline.map(\.y).min(), let y1 = outline.map(\.y).max() else { return false }
        let c = clearance
        return !(z.x + z.w <= x0 - c || x1 + c <= z.x || z.y + z.h <= y0 - c || y1 + c <= z.y)
    }

    static func dist(_ a: (x: Double, y: Double), _ b: (x: Double, y: Double)) -> Double { hypot(a.x - b.x, a.y - b.y) }
}
