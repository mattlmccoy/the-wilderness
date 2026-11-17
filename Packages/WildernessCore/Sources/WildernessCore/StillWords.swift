import Foundation

/// Be still (Matt, 2026-11-16): Christ's light alone, and a slow rotation of His own words, with Old
/// Testament verses that point to Him, until any button. App/Content/stillwords.json holds BSB clauses as
/// placeholders; the NIV is fetched at build time like every other verse.
public struct StillWords: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable { case jesus, prophecy }
    public struct Entry: Codable, Equatable, Sendable {
        public var ref: String
        public var text: String
        public var kind: Kind
        public init(ref: String, text: String, kind: Kind) { self.ref = ref; self.text = text; self.kind = kind }
    }
    public var entries: [Entry]
    public init(entries: [Entry]) { self.entries = entries }
    public static let empty = StillWords(entries: [])
    public static func decode(_ data: Data) throws -> StillWords { try JSONDecoder().decode(Self.self, from: data) }
}

public enum StillRotation {
    /// Each line: in over 3 s, held 22 s, out over 3 s, then 2 s of light alone.
    public static let fadeIn = 3.0, hold = 22.0, fadeOut = 3.0, gap = 2.0
    public static var period: Double { fadeIn + hold + fadeOut + gap }
    /// A line longer than this (as shown) is skipped.
    public static let maxCharacters = 140

    public struct Shown: Equatable, Sendable {
        public var line: PrayerLine
        public var kind: StillWords.Kind
        public var alpha: Double
    }

    /// The line at `t` seconds into Be still. The rotation starts at a different place each day.
    public static func line(at t: Double, day: CivilDate, words: StillWords, licensed: LicensedVerses) -> Shown? {
        let shown = words.entries.compactMap { e -> (PrayerLine, StillWords.Kind)? in
            let v = licensed.apply(to: Verse(ref: e.ref, text: e.text, testament: .new, translation: .bsb))
            guard v.text.count <= maxCharacters else { return nil }
            return (PrayerLine(ref: v.ref, text: v.text, translation: v.translation), e.kind)
        }
        guard !shown.isEmpty, t >= 0 else { return nil }
        let start = CivilDate(year: 2000, month: 1, day: 1).days(until: day) * 7   // a different place each day
        let n = Int(t / period), phase = t - Double(n) * period
        let pick = shown[((start + n) % shown.count + shown.count) % shown.count]
        let alpha: Double
        switch phase {
        case ..<fadeIn: alpha = phase / fadeIn
        case ..<(fadeIn + hold): alpha = 1
        case ..<(fadeIn + hold + fadeOut): alpha = (fadeIn + hold + fadeOut - phase) / fadeOut
        default: alpha = 0
        }
        return Shown(line: pick.0, kind: pick.1, alpha: alpha)
    }
}
