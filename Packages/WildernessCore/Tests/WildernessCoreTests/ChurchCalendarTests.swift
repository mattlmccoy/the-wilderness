import Foundation
import Testing
@testable import WildernessCore

// The church year, for the seasons on the wall (docs/superpowers/plans/2026-11-16-delights.md).

private func d(_ y: Int, _ m: Int, _ day: Int) -> CivilDate { CivilDate(year: y, month: m, day: day) }

@Test func easterFollowsTheGregorianComputus() {
    #expect(ChurchCalendar.easter(2024) == d(2024, 3, 31))
    #expect(ChurchCalendar.easter(2025) == d(2025, 4, 20))
    #expect(ChurchCalendar.easter(2026) == d(2026, 4, 5))
    #expect(ChurchCalendar.easter(2027) == d(2027, 3, 28))
}

@Test func theMovableFeastsHangOffEasterAndChristmas() {
    #expect(ChurchCalendar.ashWednesday(2026) == d(2026, 2, 18))
    #expect(ChurchCalendar.pentecost(2026) == d(2026, 5, 24))
    #expect(ChurchCalendar.palmSunday(2026) == d(2026, 3, 29))
    #expect(ChurchCalendar.adventSunday(2026) == d(2026, 11, 29))
    #expect(ChurchCalendar.adventSunday(2025) == d(2025, 11, 30))
}

@Test func seasonsOfTheYear() {
    #expect(ChurchCalendar.season(d(2026, 11, 28)) == .ordinary)
    #expect(ChurchCalendar.season(d(2026, 11, 29)) == .advent)
    #expect(ChurchCalendar.season(d(2026, 12, 25)) == .christmas)
    #expect(ChurchCalendar.season(d(2027, 1, 6)) == .christmas)      // Epiphany closes Christmas here
    #expect(ChurchCalendar.season(d(2027, 1, 7)) == .ordinary)
    #expect(ChurchCalendar.season(d(2026, 2, 18)) == .lent)
    #expect(ChurchCalendar.season(d(2026, 3, 29)) == .holyWeek)
    #expect(ChurchCalendar.season(d(2026, 4, 5)) == .easter)
    #expect(ChurchCalendar.season(d(2026, 5, 23)) == .easter)
    #expect(ChurchCalendar.season(d(2026, 5, 24)) == .pentecost)
    #expect(ChurchCalendar.season(d(2026, 5, 25)) == .ordinary)
}

@Test func lentCountsFortyDaysWithoutTheSundays() {
    #expect(ChurchCalendar.lentDay(d(2026, 2, 17)) == nil)
    #expect(ChurchCalendar.lentDay(d(2026, 2, 18)) == 1)
    #expect(ChurchCalendar.lentDay(d(2026, 2, 21)) == 4)
    #expect(ChurchCalendar.lentDay(d(2026, 2, 22)) == 4)               // a Sunday keeps Saturday's count
    #expect(ChurchCalendar.lentDay(d(2026, 4, 4)) == 40)               // Holy Saturday
    #expect(ChurchCalendar.lentDay(d(2026, 4, 5)) == nil)              // Easter
}

@Test func adventLightsACandleEachSunday() {
    #expect(ChurchCalendar.adventCandles(d(2026, 11, 28)) == 0)
    #expect(ChurchCalendar.adventCandles(d(2026, 11, 29)) == 1)
    #expect(ChurchCalendar.adventCandles(d(2026, 12, 5)) == 1)
    #expect(ChurchCalendar.adventCandles(d(2026, 12, 6)) == 2)
    #expect(ChurchCalendar.adventCandles(d(2026, 12, 20)) == 4)
    #expect(ChurchCalendar.adventCandles(d(2026, 12, 24)) == 4)
    #expect(ChurchCalendar.adventCandles(d(2026, 12, 25)) == 0)
}

@Test func civilDatesComeFromTheLocalClock() {
    var cal = Calendar(identifier: .gregorian); cal.timeZone = TimeZone(identifier: "America/New_York")!
    let late = cal.date(from: DateComponents(year: 2026, month: 12, day: 24, hour: 23, minute: 30))!
    #expect(CivilDate(late, calendar: cal) == d(2026, 12, 24))
}
