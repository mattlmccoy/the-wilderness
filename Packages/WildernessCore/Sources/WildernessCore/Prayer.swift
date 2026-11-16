import Foundation

/// Into the Quiet: a lectio-divina prayer session (docs/superpowers/specs/2026-11-16-prayer-mode-design.md).
/// One line of scripture on the canvas, then only Christ's light, through four movements.
public enum Prayer {
    public enum Period: String, Codable, Sendable { case morning, evening
        public var label: String { self == .morning ? "Morning" : "Evening" }
    }
    public enum Movement: String, Codable, CaseIterable, Sendable { case read, reflect, respond, rest
        public var title: String { rawValue.prefix(1).uppercased() + rawValue.dropFirst() }
    }
    public struct Step: Equatable, Sendable { public var movement: Movement; public var seconds: Double }

    /// The lengths offered on the phone, in minutes.
    public static let lengths = [5, 10, 20, 30]
    /// Christ's breath during prayer: slower than the wall's resting 12 s.
    public static let breathSeconds = 14.0
    /// A line longer than this (as shown) is skipped for the day.
    public static let maxLineCharacters = 100

    /// Morning lines 04:00–14:59, evening lines 15:00–03:59.
    public static func period(hour: Int) -> Period { (4..<15).contains(hour) ? .morning : .evening }
    /// The wall fades out and lets the TV sleep only after a late session (21:00–03:59).
    public static func sleepEnding(hour: Int) -> Bool { hour >= 21 || hour < 4 }

    /// Read 10% (at least 45 s), Reflect 20%, Respond 20%, Rest the remainder.
    public static func schedule(minutes: Int) -> [Step] {
        let total = Double(minutes * 60)
        let read = max(45, total * 0.1), reflect = total * 0.2, respond = total * 0.2
        return [Step(movement: .read, seconds: read), Step(movement: .reflect, seconds: reflect),
                Step(movement: .respond, seconds: respond), Step(movement: .rest, seconds: total - read - reflect - respond)]
    }

    /// Today's line: one per day from the period's list, the same all day, skipping any line too long
    /// to set on the canvas. Licensed (NIV) text replaces the BSB placeholder when it exists.
    public static func line(on day: CivilDate, period: Period, content: PrayerContent, licensed: LicensedVerses) -> PrayerLine? {
        let list = period == .morning ? content.morning : content.evening
        guard !list.isEmpty else { return nil }
        let start = CivilDate(year: 2000, month: 1, day: 1).days(until: day)
        for k in 0..<list.count {
            let e = list[((start + k) % list.count + list.count) % list.count]
            let v = licensed.apply(to: Verse(ref: e.ref, text: e.text, testament: .old, translation: .bsb))
            guard v.text.count <= maxLineCharacters else { continue }
            return PrayerLine(ref: v.ref, text: v.text, translation: v.translation)
        }
        return nil
    }
}

/// The line shown at Read.
public struct PrayerLine: Codable, Equatable, Sendable {
    public var ref: String
    public var text: String
    public var translation: Translation
    public init(ref: String, text: String, translation: Translation) { self.ref = ref; self.text = text; self.translation = translation }
}

/// App/Content/prayer.json: the morning and evening lines, as BSB clauses (placeholders for the NIV).
public struct PrayerContent: Codable, Equatable, Sendable {
    public struct Entry: Codable, Equatable, Sendable {
        public var ref: String
        public var text: String
        public init(ref: String, text: String) { self.ref = ref; self.text = text }
    }
    public var morning: [Entry]
    public var evening: [Entry]
    public init(morning: [Entry], evening: [Entry]) { self.morning = morning; self.evening = evening }
    public static let empty = PrayerContent(morning: [], evening: [])
    public static func decode(_ data: Data) throws -> PrayerContent { try JSONDecoder().decode(Self.self, from: data) }
}

/// A session in progress. The Apple TV owns its clock.
public struct PrayerSession: Codable, Equatable, Sendable {
    public var startedAt: Double
    public var minutes: Int
    public var line: PrayerLine?
    /// Ends by fading out and letting the TV sleep (a late session), else back to rest.
    public var sleeps: Bool

    public struct Now: Equatable, Sendable {
        public var movement: Prayer.Movement
        public var index: Int
        public var of: Int
        /// Seconds into this movement, and its length.
        public var elapsed: Double
        public var length: Double
    }

    public init(startedAt: Double, minutes: Int, line: PrayerLine?, sleeps: Bool) {
        self.startedAt = startedAt; self.minutes = minutes; self.line = line; self.sleeps = sleeps
    }

    public var duration: Double { Double(minutes * 60) }
    public func isFinished(at now: Double) -> Bool { now - startedAt >= duration }

    public func movement(at now: Double) -> Now? {
        var t = now - startedAt
        guard t >= 0, t < duration else { return nil }
        let steps = Prayer.schedule(minutes: minutes)
        for (i, s) in steps.enumerated() {
            if t < s.seconds { return Now(movement: s.movement, index: i + 1, of: steps.count, elapsed: t, length: s.seconds) }
            t -= s.seconds
        }
        return nil
    }
}

/// A running session, as the phone sees it.
public struct PrayerStatus: Codable, Equatable, Sendable {
    public var movement: Prayer.Movement
    public var index: Int
    public var of: Int
    public var minutes: Int
    public var line: PrayerLine?
    public var secondsLeft: Double
}

/// What the phone's start screen shows: the period and today's line.
public struct PrayerToday: Codable, Equatable, Sendable {
    public var period: Prayer.Period
    public var line: PrayerLine?
    public init(period: Prayer.Period, line: PrayerLine?) { self.period = period; self.line = line }
}
