import Foundation

/// Context: a few pages about the painting itself (who, how big, a fragment, the subject, where it
/// is now), read with ← →. Copy lives in App/Content/context.json; every page names its sources.
public enum ContextVisual: String, Codable, Sendable {
    /// Milan, Brescia and Venice placed by latitude and longitude beside the text.
    case map
    /// A thin frame on the tapestry at the original canvas's true size.
    case trueSize
}

public struct ContextPage: Codable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var text: String
    /// Subjects lit on the tapestry while this page shows.
    public var light: [String]
    public var visual: ContextVisual?
    public var textSide: TextSide
    /// Where the page's facts come from (Met collection page, National Gallery, …).
    public var sources: [String]
    public var draft: Bool

    public init(id: String, title: String, text: String, light: [String], visual: ContextVisual?,
                textSide: TextSide, sources: [String], draft: Bool) {
        self.id = id; self.title = title; self.text = text; self.light = light
        self.visual = visual; self.textSide = textSide; self.sources = sources; self.draft = draft
    }
}

public struct ContextScript: Codable, Equatable, Sendable {
    public var pages: [ContextPage]
    public init(pages: [ContextPage]) { self.pages = pages }
    public static let empty = ContextScript(pages: [])

    public static func decode(_ data: Data, library: AnnotationLibrary) throws -> ContextScript {
        typealias Invalid = AnnotationLibrary.ValidationError
        let s = try JSONDecoder().decode(ContextScript.self, from: data)
        guard !s.pages.isEmpty else { throw Invalid.invalid("context has no pages") }
        let known = Set(library.annotations.map(\.id))
        var seen = Set<String>()
        for p in s.pages {
            guard seen.insert(p.id).inserted else { throw Invalid.invalid("context: duplicate page id \(p.id)") }
            guard !p.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw Invalid.invalid("context \(p.id): text is empty")
            }
            if let bad = p.light.first(where: { !known.contains($0) }) {
                throw Invalid.invalid("context \(p.id): unknown light target \(bad)")
            }
        }
        return s
    }
}

/// The painting at the Met: oil on canvas, 18 × 21¾ in (metmuseum.org, accession 11.53).
public enum OriginalCanvas {
    public static let widthInches = 21.75
    public static let heightInches = 18.0

    /// The original's true size, centred on the tapestry, in artwork canvas units.
    public static func trueSizeFrame(canvasWidth: Double, canvasHeight: Double,
                                     unitsPerInch: Double) -> (x: Double, y: Double, width: Double, height: Double) {
        let w = widthInches * unitsPerInch, h = heightInches * unitsPerInch
        return ((canvasWidth - w) / 2, (canvasHeight - h) / 2, w, h)
    }
}

/// A minimal, honest map: three cities placed by real coordinates, no drawn coastline.
public enum ItalyMap {
    public struct Place: Equatable, Sendable {
        public let name: String
        public let lat: Double
        public let lon: Double
    }

    public static let places = [
        Place(name: "Milan", lat: 45.4642, lon: 9.1900),
        Place(name: "Brescia", lat: 45.5416, lon: 10.2118),
        Place(name: "Venice", lat: 45.4408, lon: 12.3155),
    ]

    /// Equirectangular layout scaled so the westmost place is at x 0 and the eastmost at `width`.
    /// y grows southward from the northmost place, on the same scale.
    public static func layout(width: Double) -> [(place: Place, x: Double, y: Double)] {
        let midLat = places.map(\.lat).reduce(0, +) / Double(places.count)
        let kx = cos(midLat * .pi / 180)
        let xs = places.map { $0.lon * kx }
        let minX = xs.min()!, span = xs.max()! - minX
        let maxLat = places.map(\.lat).max()!
        let scale = width / span
        return zip(places, xs).map { p, x in (p, (x - minX) * scale, (maxLat - p.lat) * scale) }
    }
}
