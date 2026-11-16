import Foundation

/// A day on the wall's own calendar (no time, no time zone).
public struct CivilDate: Equatable, Hashable, Comparable, Sendable {
    public var year, month, day: Int
    public init(year: Int, month: Int, day: Int) { self.year = year; self.month = month; self.day = day }

    /// Today as the local clock reads it.
    public init(_ date: Date, calendar: Calendar = .current) {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: c.year!, month: c.month!, day: c.day!)
    }

    private static let utc: Calendar = { var c = Calendar(identifier: .gregorian); c.timeZone = TimeZone(identifier: "UTC")!; return c }()
    private var noon: Date { Self.utc.date(from: DateComponents(year: year, month: month, day: day, hour: 12))! }

    public func adding(days n: Int) -> CivilDate {
        CivilDate(Self.utc.date(byAdding: .day, value: n, to: noon)!, calendar: Self.utc)
    }
    public func days(until other: CivilDate) -> Int {
        Self.utc.dateComponents([.day], from: noon, to: other.noon).day!
    }
    /// 1 = Sunday … 7 = Saturday.
    public var weekday: Int { Self.utc.component(.weekday, from: noon) }

    public static func < (a: CivilDate, b: CivilDate) -> Bool { (a.year, a.month, a.day) < (b.year, b.month, b.day) }
}

/// The church year, for the seasons on the wall (docs/superpowers/plans/2026-11-16-delights.md).
public enum ChurchCalendar {
    public enum Season: Equatable, Sendable { case advent, christmas, ordinary, lent, holyWeek, easter, pentecost }

    /// Easter Sunday by the anonymous Gregorian algorithm (Meeus/Jones/Butcher).
    public static func easter(_ y: Int) -> CivilDate {
        let a = y % 19, b = y / 100, c = y % 100, d = b / 4, e = b % 4
        let f = (b + 8) / 25, g = (b - f + 1) / 3, h = (19 * a + b - d - g + 15) % 30
        let i = c / 4, k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7
        let m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31, day = (h + l - 7 * m + 114) % 31 + 1
        return CivilDate(year: y, month: month, day: day)
    }

    public static func ashWednesday(_ y: Int) -> CivilDate { easter(y).adding(days: -46) }
    public static func palmSunday(_ y: Int) -> CivilDate { easter(y).adding(days: -7) }
    public static func pentecost(_ y: Int) -> CivilDate { easter(y).adding(days: 49) }

    /// The fourth Sunday before Christmas.
    public static func adventSunday(_ y: Int) -> CivilDate {
        let christmas = CivilDate(year: y, month: 12, day: 25)
        let back = christmas.weekday == 1 ? 7 : christmas.weekday - 1    // the Sunday before Christmas
        return christmas.adding(days: -back - 21)
    }

    public static func season(_ date: CivilDate) -> Season {
        let y = date.year
        if date.month == 1, date.day <= 6 { return .christmas }
        if date >= CivilDate(year: y, month: 12, day: 25) { return .christmas }
        if date >= adventSunday(y) { return .advent }
        let easter = easter(y)
        if date == pentecost(y) { return .pentecost }
        if date >= easter, date < pentecost(y) { return .easter }
        if date >= palmSunday(y), date < easter { return .holyWeek }
        if date >= ashWednesday(y), date < palmSunday(y) { return .lent }
        return .ordinary
    }

    /// Day n of the forty days of Lent (Sundays are not counted and keep Saturday's number);
    /// nil outside Ash Wednesday … Holy Saturday.
    public static func lentDay(_ date: CivilDate) -> Int? {
        let ash = ashWednesday(date.year), holySaturday = easter(date.year).adding(days: -1)
        guard date >= ash, date <= holySaturday else { return nil }
        var n = 0, day = ash
        while day <= date {
            if day.weekday != 1 { n += 1 }
            day = day.adding(days: 1)
        }
        return n
    }

    /// Advent candles lit: one for each Advent Sunday reached, up to four; 0 outside Advent.
    public static func adventCandles(_ date: CivilDate) -> Int {
        guard season(date) == .advent else { return 0 }
        return min(adventSunday(date.year).days(until: date) / 7 + 1, 4)
    }
}
