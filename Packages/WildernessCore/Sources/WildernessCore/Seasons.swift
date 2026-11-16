import Foundation

/// The faint colour the background wash takes from the church year.
public enum LiturgicalTint: Equatable, Sendable {
    case violet, gold, red, green
    /// RGB, 0…1: soft, so they colour the light without turning the painting.
    public var rgb: (r: Double, g: Double, b: Double) {
        switch self {
        case .violet: (0.62, 0.52, 0.80)
        case .gold: (1.0, 0.90, 0.68)
        case .red: (0.92, 0.48, 0.42)
        case .green: (0.60, 0.80, 0.58)
        }
    }
}

/// What the seasons put on the wall at a given moment (docs/superpowers/plans/2026-11-16-delights.md).
public struct SeasonEffects: Equatable, Sendable {
    public var christmas = false      // hats and snow, 1 Dec – 6 Jan
    public var star = false           // over the angels: 24–25 Dec and Epiphany
    public var easterDawn = false     // Easter Sunday morning
    public var halloween = false      // 31 Oct after dusk
    public var adventCandles = 0
    public var lentDay: Int? = nil
    public var tint: LiturgicalTint = .green
    public init() {}
}

public enum Seasons {
    public static func effects(at date: Date, calendar: Calendar = .current) -> SeasonEffects {
        let day = CivilDate(date, calendar: calendar)
        let hour = calendar.component(.hour, from: date)
        var e = SeasonEffects()
        e.christmas = day.month == 12 || (day.month == 1 && day.day <= 6)
        e.star = (day.month == 12 && (day.day == 24 || day.day == 25)) || (day.month == 1 && day.day == 6)
        e.easterDawn = day == ChurchCalendar.easter(day.year) && (5..<11).contains(hour)
        e.halloween = (day.month == 10 && day.day == 31 && hour >= 17) || (day.month == 11 && day.day == 1 && hour < 3)
        e.adventCandles = ChurchCalendar.adventCandles(day)
        e.lentDay = ChurchCalendar.lentDay(day)
        e.tint = tint(day)
        return e
    }

    static func tint(_ day: CivilDate) -> LiturgicalTint {
        if day == ChurchCalendar.palmSunday(day.year) { return .red }
        switch ChurchCalendar.season(day) {
        case .advent, .lent, .holyWeek: return .violet
        case .christmas, .easter: return .gold
        case .pentecost: return .red
        case .ordinary: return .green
        }
    }
}

/// Hand-marked places on the painting for the seasonal touches (App/Content/delights.json).
public struct DelightsContent: Codable, Equatable, Sendable {
    public struct Spot: Codable, Equatable, Sendable {
        public var id: String
        public var x, y: Double
        /// Hats: width as a fraction of the canvas; tilt in degrees.
        public var size: Double?
        public var tilt: Double?
    }
    public struct Place: Codable, Equatable, Sendable { public var x, y: Double }
    public var hats: [Spot]
    public var eyes: [Spot]
    public var star: Place

    public static let empty = DelightsContent(hats: [], eyes: [], star: Place(x: 0.72, y: 0.06))
    public static func decode(_ data: Data) throws -> DelightsContent { try JSONDecoder().decode(Self.self, from: data) }
}
