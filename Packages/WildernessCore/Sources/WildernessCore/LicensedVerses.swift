import Foundation

/// Verse wording Matt pastes in from his own licensed Bible (NIV, ESV, NLT), kept in
/// App/Content/licensed-verses.json. It replaces the public-domain placeholder for the same
/// reference. Blank entries are ignored, so the placeholder stays until real text is pasted.
public struct LicensedVerse: Codable, Equatable, Sendable {
    public var ref: String
    public var translation: Translation
    public var text: String
    public init(ref: String, translation: Translation, text: String) {
        self.ref = ref; self.translation = translation; self.text = text
    }
}

public struct LicensedVerses: Codable, Equatable, Sendable {
    public var verses: [LicensedVerse]
    public init(verses: [LicensedVerse]) { self.verses = verses }
    public static let none = LicensedVerses(verses: [])

    public static func decode(_ data: Data) throws -> LicensedVerses {
        try JSONDecoder().decode(LicensedVerses.self, from: data)
    }

    /// Replaces a verse when real pasted text exists for its reference.
    func apply(to v: Verse) -> Verse {
        guard let l = verses.first(where: { $0.ref == v.ref }),
              !l.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return v }
        var out = v
        out.text = l.text.trimmingCharacters(in: .whitespacesAndNewlines)
        out.translation = l.translation
        return out
    }

    func apply(to m: More?) -> More? {
        guard var m else { return nil }
        m.verses = m.verses.map(apply(to:))
        return m
    }
}

extension AnnotationLibrary {
    public func applying(_ licensed: LicensedVerses) -> AnnotationLibrary {
        var out = self
        out.annotations = annotations.map { a in var a = a; a.more = licensed.apply(to: a.more); return a }
        return out
    }
}

extension UnfoldScript {
    public func applying(_ licensed: LicensedVerses) -> UnfoldScript {
        UnfoldScript(beats: beats.map { b in var b = b; b.more = licensed.apply(to: b.more); return b })
    }
}
