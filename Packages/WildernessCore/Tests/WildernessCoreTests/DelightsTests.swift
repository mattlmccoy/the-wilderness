import Foundation
import Testing
@testable import WildernessCore

// Seasons, day light, moments, the secret code, slow looking and wind-down
// (docs/superpowers/plans/2026-11-16-delights.md).

private let ny = TimeZone(identifier: "America/New_York")!
private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = ny; return c }
private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
    cal.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
}
private func hm(_ date: Date) -> Int { let c = cal.dateComponents([.hour, .minute], from: date); return c.hour! * 60 + c.minute! }

// MARK: Seasons

@Test func christmasRunsFromDecemberFirstToEpiphany() {
    #expect(!Seasons.effects(at: at(2026, 11, 30, 20), calendar: cal).christmas)
    #expect(Seasons.effects(at: at(2026, 12, 1, 20), calendar: cal).christmas)
    #expect(Seasons.effects(at: at(2027, 1, 6, 20), calendar: cal).christmas)
    #expect(!Seasons.effects(at: at(2027, 1, 7, 20), calendar: cal).christmas)
}

@Test func theStarShinesOnChristmasEveDayAndEpiphany() {
    #expect(Seasons.effects(at: at(2026, 12, 24, 21), calendar: cal).star)
    #expect(Seasons.effects(at: at(2026, 12, 25, 9), calendar: cal).star)
    #expect(!Seasons.effects(at: at(2026, 12, 26, 9), calendar: cal).star)
    #expect(Seasons.effects(at: at(2027, 1, 6, 19), calendar: cal).star)
}

@Test func easterDawnIsEasterMorningOnly() {
    #expect(Seasons.effects(at: at(2026, 4, 5, 7), calendar: cal).easterDawn)
    #expect(!Seasons.effects(at: at(2026, 4, 5, 13), calendar: cal).easterDawn)
    #expect(!Seasons.effects(at: at(2026, 4, 6, 7), calendar: cal).easterDawn)
}

@Test func halloweenEyesGlowAfterDusk() {
    #expect(!Seasons.effects(at: at(2026, 10, 31, 15), calendar: cal).halloween)
    #expect(Seasons.effects(at: at(2026, 10, 31, 19), calendar: cal).halloween)
    #expect(Seasons.effects(at: at(2026, 11, 1, 1), calendar: cal).halloween)
    #expect(!Seasons.effects(at: at(2026, 11, 1, 9), calendar: cal).halloween)
}

@Test func countersAndTintFollowTheChurchYear() {
    let advent = Seasons.effects(at: at(2026, 12, 7, 20), calendar: cal)
    #expect(advent.adventCandles == 2 && advent.tint == .violet && advent.lentDay == nil)
    let lent = Seasons.effects(at: at(2026, 3, 2, 20), calendar: cal)
    #expect(lent.lentDay == 11 && lent.tint == .violet)
    #expect(Seasons.effects(at: at(2026, 3, 29, 10), calendar: cal).tint == .red)     // Palm Sunday
    #expect(Seasons.effects(at: at(2026, 5, 24, 10), calendar: cal).tint == .red)     // Pentecost
    #expect(Seasons.effects(at: at(2026, 4, 12, 10), calendar: cal).tint == .gold)    // Easter season
    #expect(Seasons.effects(at: at(2026, 12, 25, 10), calendar: cal).tint == .gold)
    #expect(Seasons.effects(at: at(2026, 7, 12, 10), calendar: cal).tint == .green)
}

// MARK: Sun and day light

@Test func sunriseAndSunsetInAtlanta() {
    let nov = SunClock.times(on: CivilDate(year: 2026, month: 11, day: 16), place: .home, calendar: cal)!
    #expect(abs(hm(nov.sunrise) - (7 * 60 + 11)) <= 6)
    #expect(abs(hm(nov.sunset) - (17 * 60 + 32)) <= 6)
    let jun = SunClock.times(on: CivilDate(year: 2026, month: 6, day: 21), place: .home, calendar: cal)!
    #expect(abs(hm(jun.sunrise) - (6 * 60 + 27)) <= 6)
    #expect(abs(hm(jun.sunset) - (20 * 60 + 51)) <= 6)
}

@Test func dayLightIsWarmAtTheEdgesOfTheDayAndDimLateAtNight() {
    let day = { (h: Int, m: Int) in DayLight.at(at(2026, 11, 16, h, m), place: .home, calendar: cal) }
    let noon = day(12, 30), dusk = day(17, 35), evening = day(20, 0), night = day(0, 30)
    #expect(noon.warmth < 0.1 && noon.level == 1)
    #expect(dusk.warmth > noon.warmth + 0.4)
    #expect(evening.warmth >= dusk.warmth && evening.level < 1)
    #expect(night.level < evening.level && night.warmth >= evening.warmth)
}

// MARK: Moments at rest

@Test func aFewMomentsAnEveningAtTimesThatDifferDayToDay() {
    let a = Moments.schedule(for: CivilDate(year: 2026, month: 11, day: 16))
    let b = Moments.schedule(for: CivilDate(year: 2026, month: 11, day: 17))
    #expect(a.count == 3 && a != b)
    #expect(a == Moments.schedule(for: CivilDate(year: 2026, month: 11, day: 16)))      // reproducible
    for m in a { #expect(m.minute >= 18 * 60 && m.minute < 23 * 60) }
    #expect(Set(a.map(\.kind)) == Set(Moment.Kind.allCases))
}

@Test func aMomentLastsAFewSeconds() {
    let m = Moments.schedule(for: CivilDate(year: 2026, month: 11, day: 16))[0]
    let start = cal.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: m.minute / 60, minute: m.minute % 60))!
    #expect(Moments.active(at: start.addingTimeInterval(2), calendar: cal)?.kind == m.kind)
    #expect(Moments.active(at: start.addingTimeInterval(Moment.duration + 1), calendar: cal) == nil)
}

// MARK: The secret code

@Test func theCodeIsUpUpDownDownLeftRightLeftRightSelect() {
    var code = SecretCode()
    let keys: [AppInput] = [.move(.up), .move(.up), .move(.down), .move(.down), .move(.left), .move(.right), .move(.left), .move(.right)]
    for k in keys { let done = code.feed(k); #expect(!done) }
    let done = code.feed(.select); #expect(done)
    let again = code.feed(.select); #expect(!again)                    // starts over
}

@Test func aWrongPressStartsTheCodeOver() {
    var code = SecretCode()
    for k: AppInput in [.move(.up), .move(.up), .move(.left)] { _ = code.feed(k) }
    for k: AppInput in [.move(.up), .move(.up), .move(.down), .move(.down), .move(.left), .move(.right), .move(.left), .move(.right)] { _ = code.feed(k) }
    let done = code.feed(.select); #expect(done)
}

// MARK: Slow looking

@Test func slowLookingWalksTheFiguresFromChristBackToChrist() {
    let ids = ["christ", "raven", "lion", "stag", "angels"]
    let path = SlowLooking.path(ids: ids)
    #expect(path.first == "christ" && path.last == "christ")
    #expect(Set(path) == Set(ids))
    #expect(abs(SlowLooking.total(ids: ids) - Double(path.count) * SlowLooking.secondsPerFigure) < 1e-9)
    #expect(SlowLooking.figure(at: 0, ids: ids) == "christ")
    #expect(SlowLooking.figure(at: SlowLooking.secondsPerFigure + 1, ids: ids) == path[1])
    #expect(SlowLooking.figure(at: SlowLooking.total(ids: ids) + 1, ids: ids) == nil)
}

// MARK: Wind-down

@Test func theWallSettlesThenSleepsLateInTheEvening() {
    let w = WindDown(startMinute: 22 * 60 + 30)
    #expect(w.phase(at: at(2026, 11, 16, 21, 0), calendar: cal) == .awake)
    #expect(w.phase(at: at(2026, 11, 16, 22, 45), calendar: cal) == .settling)
    #expect(w.phase(at: at(2026, 11, 16, 23, 5), calendar: cal) == .sleeping)
    #expect(w.phase(at: at(2026, 11, 17, 2, 0), calendar: cal) == .sleeping)
    #expect(w.phase(at: at(2026, 11, 17, 7, 0), calendar: cal) == .awake)
}

// MARK: Flashlight

@Test func thePhoneSendsAFlashlightPointOrNothing() throws {
    for cmd in [PhoneCommand.flashlight(Point(x: 0.4, y: 0.6)), .flashlight(nil)] {
        #expect(try JSONDecoder().decode(PhoneCommand.self, from: LineFramer.frame(cmd).dropLast()) == cmd)
    }
}
