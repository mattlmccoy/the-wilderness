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
    public var thanksgiving = false   // the turkey: Monday of the week before through Thanksgiving Day
    public var adventCandles = 0
    public var lentDay: Int? = nil
    public var tint: LiturgicalTint = .green
    /// Seasons switched on by hand (Settings), which show whatever the date.
    public var forced: Set<SeasonMode> = []
    public init() {}

    /// The seasons the wall is showing, in a fixed order (for the phone).
    public var active: [SeasonMode] {
        SeasonMode.allCases.filter { m in
            switch m {
            case .advent: adventCandles > 0
            case .christmas: christmas
            case .lent: lentDay != nil
            case .easter: easterDawn
            case .thanksgiving: thanksgiving
            }
        }
    }
}

/// The seasons that can be switched by hand in Settings.
public enum SeasonMode: String, Codable, CaseIterable, Sendable {
    case advent, christmas, lent, easter, thanksgiving

    public var title: String {
        switch self {
        case .advent: "Advent"
        case .christmas: "Christmas"
        case .lent: "Lent"
        case .easter: "Easter"
        case .thanksgiving: "Thanksgiving"
        }
    }
}

/// Auto follows the calendar; on and off override it.
public enum SeasonSwitch: String, Codable, CaseIterable, Sendable {
    case auto, on, off
    public var next: SeasonSwitch { self == .auto ? .on : self == .on ? .off : .auto }
}

public enum Seasons {
    public static func effects(at date: Date, calendar: Calendar = .current) -> SeasonEffects {
        let day = CivilDate(date, calendar: calendar)
        let hour = calendar.component(.hour, from: date)
        var e = SeasonEffects()
        e.christmas = day.month == 12 || (day.month == 1 && day.day <= 6)
        e.star = (day.month == 12 && (day.day == 24 || day.day == 25)) || (day.month == 1 && day.day == 6)
        e.easterDawn = day == ChurchCalendar.easter(day.year) && (5..<11).contains(hour)
        let tg = ChurchCalendar.thanksgiving(day.year)
        e.thanksgiving = day >= tg.adding(days: -10) && day <= tg
        e.adventCandles = ChurchCalendar.adventCandles(day)
        e.lentDay = ChurchCalendar.lentDay(day)
        e.tint = tint(day)
        return e
    }

    /// The calendar's seasons with Settings applied: the master switch off silences every automatic
    /// season; a season switched off is removed; a season switched on shows whatever the date.
    public static func effects(at date: Date, tuning: Tuning, calendar: Calendar = .current) -> SeasonEffects {
        let auto = effects(at: date, calendar: calendar)
        var e = auto
        for m in SeasonMode.allCases {
            let sw = tuning.switchFor(m)
            let show: Bool
            switch sw {
            case .on: show = true; e.forced.insert(m)
            case .off: show = false
            case .auto: show = tuning.seasons && auto.active.contains(m)
            }
            switch m {
            case .advent: e.adventCandles = show ? (auto.adventCandles > 0 ? auto.adventCandles : 4) : 0
            case .christmas:
                e.christmas = show
                e.star = show && (sw == .on || auto.star)
            case .lent: e.lentDay = show ? (auto.lentDay ?? 1) : nil
            case .easter: e.easterDawn = show
            case .thanksgiving: e.thanksgiving = show
            }
        }
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
        /// Hats: the tip falls to the left instead of the right.
        public var flip: Bool?
    }
    public struct Place: Codable, Equatable, Sendable {
        public var x, y: Double
        /// The star: its long rays as a fraction of the canvas width.
        public var size: Double?
        public init(x: Double, y: Double, size: Double? = nil) { self.x = x; self.y = y; self.size = size }
    }
    public var hats: [Spot]
    /// The raven's eye, where the "raven glints" moment catches the light.
    public var ravenEye: Spot
    public var star: Place
    /// Thanksgiving: the turkey's two runs (nil = none).
    public var turkey: TurkeyPaths? = nil

    public static let empty = DelightsContent(hats: [], ravenEye: Spot(id: "raven", x: 0.262, y: 0.195), star: Place(x: 0.72, y: 0.06))
    public static func decode(_ data: Data) throws -> DelightsContent { try JSONDecoder().decode(Self.self, from: data) }
}
