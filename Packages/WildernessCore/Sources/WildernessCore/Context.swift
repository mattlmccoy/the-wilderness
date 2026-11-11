import Foundation

/// Context: a few pages about the painting itself (who, how big, a fragment, the subject, where it
/// is now), read with ← →. Copy lives in App/Content/context.json; every page names its sources.
public enum ContextVisual: String, Codable, Sendable {
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
    /// A real map under the text: an id in maps.json.
    public var map: String?
    /// A photograph under the text, with the credit its licence asks for.
    public var image: ContextImage?
    public var textSide: TextSide
    /// Where the page's facts come from (Met collection page, National Gallery, …).
    public var sources: [String]
    public var draft: Bool

    public init(id: String, title: String, text: String, light: [String], visual: ContextVisual?,
                map: String? = nil, image: ContextImage? = nil,
                textSide: TextSide, sources: [String], draft: Bool) {
        self.id = id; self.title = title; self.text = text; self.light = light
        self.visual = visual; self.map = map; self.image = image
        self.textSide = textSide; self.sources = sources; self.draft = draft
    }
}

/// A bundled photograph (App/Content/context-images/) and its licence credit.
public struct ContextImage: Codable, Equatable, Sendable {
    public var file: String
    public var caption: String?
    public var credit: String

    public init(file: String, caption: String?, credit: String) {
        self.file = file; self.caption = caption; self.credit = credit
    }
}

public struct ContextScript: Codable, Equatable, Sendable {
    public var pages: [ContextPage]
    public init(pages: [ContextPage]) { self.pages = pages }
    public static let empty = ContextScript(pages: [])

    /// Every photograph's credit, once each, in page order (for About).
    public var imageCredits: [String] {
        var seen = Set<String>()
        return pages.compactMap(\.image?.credit).filter { seen.insert($0).inserted }
    }

    public static func decode(_ data: Data, library: AnnotationLibrary, maps: ContextMaps = .empty) throws -> ContextScript {
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
            if let m = p.map, maps.map(m) == nil { throw Invalid.invalid("context \(p.id): unknown map \(m)") }
            if let img = p.image {
                let blank = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                guard !blank(img.file) else { throw Invalid.invalid("context \(p.id): image has no file") }
                guard !blank(img.credit) else { throw Invalid.invalid("context \(p.id): image \(img.file) has no credit") }
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
