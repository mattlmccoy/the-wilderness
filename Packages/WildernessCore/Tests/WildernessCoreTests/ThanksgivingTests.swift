import Foundation
import Testing
@testable import WildernessCore

// Thanksgiving and the season switches (docs/superpowers/plans/2026-11-16-thanksgiving-and-phone.md).

private let ny = TimeZone(identifier: "America/New_York")!
private var cal: Calendar { var c = Calendar(identifier: .gregorian); c.timeZone = ny; return c }
private func at(_ y: Int, _ m: Int, _ d: Int, _ h: Int) -> Date {
    cal.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
}
private func tuning(_ s: [SeasonMode: SeasonSwitch], seasons: Bool = true) -> Tuning {
    var t = Tuning(); t.seasons = seasons
    for (m, v) in s { t.setSwitch(m, v) }
    return t
}

@Test func thanksgivingIsTheFourthThursdayOfNovember() {
    #expect(ChurchCalendar.thanksgiving(2026) == CivilDate(year: 2026, month: 11, day: 26))
    #expect(ChurchCalendar.thanksgiving(2027) == CivilDate(year: 2027, month: 11, day: 25))
    #expect(ChurchCalendar.thanksgiving(2029) == CivilDate(year: 2029, month: 11, day: 22))
}

@Test func thanksgivingRunsFromTheMondayOfTheWeekBeforeThroughTheDay() {
    #expect(!Seasons.effects(at: at(2026, 11, 15, 20), calendar: cal).thanksgiving)
    #expect(Seasons.effects(at: at(2026, 11, 16, 9), calendar: cal).thanksgiving)
    #expect(Seasons.effects(at: at(2026, 11, 26, 23), calendar: cal).thanksgiving)
    #expect(!Seasons.effects(at: at(2026, 11, 27, 9), calendar: cal).thanksgiving)
}

@Test func aSwitchedOffSeasonDisappears() {
    let e = Seasons.effects(at: at(2026, 12, 24, 19), tuning: tuning([.christmas: .off]), calendar: cal)
    #expect(!e.christmas && !e.star)
    #expect(e.adventCandles == 4)   // Advent is a separate switch
}

@Test func aSwitchedOnSeasonShowsAnyDay() {
    let e = Seasons.effects(at: at(2026, 7, 4, 15), tuning: tuning([.christmas: .on, .thanksgiving: .on, .easter: .on]), calendar: cal)
    #expect(e.christmas && e.star && e.thanksgiving && e.easterDawn)
    #expect(e.forced.contains(.thanksgiving))
}

@Test func forcedAdventAndLentShowSensibleCounts() {
    let e = Seasons.effects(at: at(2026, 7, 4, 15), tuning: tuning([.advent: .on, .lent: .on]), calendar: cal)
    #expect(e.adventCandles == 4)
    #expect(e.lentDay == 1)
    let real = Seasons.effects(at: at(2026, 12, 7, 19), tuning: tuning([.advent: .on]), calendar: cal)
    #expect(real.adventCandles == 2)
}

@Test func theMasterSwitchTurnsOffOnlyTheAutomaticSeasons() {
    let e = Seasons.effects(at: at(2026, 12, 24, 19), tuning: tuning([.thanksgiving: .on], seasons: false), calendar: cal)
    #expect(!e.christmas && e.adventCandles == 0)
    #expect(e.thanksgiving)
}

@Test func activeNamesWhatTheWallShows() {
    let e = Seasons.effects(at: at(2026, 12, 24, 19), calendar: cal)
    #expect(e.active == [.advent, .christmas])
}

@Test func profilesSavedBeforeTheSwitchesReadAsAuto() throws {
    let old = #"{"subjectStrength":0.5,"seasons":true}"#
    let t = try JSONDecoder().decode(Tuning.self, from: Data(old.utf8))
    for m in SeasonMode.allCases { #expect(t.switchFor(m) == .auto) }
    var u = t; u.setSwitch(.thanksgiving, .on)
    let back = try JSONDecoder().decode(Tuning.self, from: JSONEncoder().encode(u))
    #expect(back.switchFor(.thanksgiving) == .on)
}

// MARK: The turkey

private let paths = TurkeyPaths(hill: [.init(x: 0.36, y: 0.275), .init(x: 0.60, y: 0.27)], hillSize: 0.02,
                                ground: [.init(x: -0.12, y: 0.93), .init(x: 1.12, y: 0.9)], groundSize: 0.11)

@Test func theTurkeyCrossesTheHillThenHidesThenRunsThroughTheForeground() throws {
    let every = Turkey.everySeconds, base = every * 1000
    let hill = try #require(Turkey.pose(at: base + Turkey.hillSeconds / 2, every: every, paths: paths))
    #expect(hill.onHill && abs(hill.x - 0.48) < 1e-9 && hill.size == 0.02 && hill.facingRight)
    #expect(Turkey.pose(at: base + Turkey.hillSeconds + 0.5, every: every, paths: paths) == nil)
    let groundMid = base + Turkey.groundStart + Turkey.groundSeconds / 2
    let ground = try #require(Turkey.pose(at: groundMid, every: every, paths: paths))
    #expect(!ground.onHill && abs(ground.x - 0.5) < 1e-9 && ground.size == 0.11)
    #expect(Turkey.pose(at: base + Turkey.runSeconds + 1, every: every, paths: paths) == nil)
}

@Test func theTurkeyRunsMoreOftenWhenSwitchedOn() {
    #expect(Turkey.every(forced: false) == 600)
    #expect(Turkey.every(forced: true) == 90)
}

@Test func theTurkeyFacesTheWayItRuns() throws {
    let back = TurkeyPaths(hill: [.init(x: 0.6, y: 0.27), .init(x: 0.36, y: 0.275)], hillSize: 0.02,
                           ground: [.init(x: 1.12, y: 0.9), .init(x: -0.12, y: 0.93)], groundSize: 0.11)
    #expect(try #require(Turkey.pose(at: 3, every: 600, paths: back)).facingRight == false)
}

@Test func theTurkeysPathsAreInTheContentFile() throws {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("App/Content/delights.json")
    let d = try DelightsContent.decode(Data(contentsOf: url))
    let t = try #require(d.turkey)
    #expect(t.hill.count == 2 && t.ground.count == 2)
    #expect(t.ground[0].x < 0 || t.ground[0].x > 1)    // comes in from off the canvas
    #expect(t.ground[1].x < 0 || t.ground[1].x > 1)    // and leaves it
}

// MARK: What the phone is told

@Test func theSnapshotCarriesWhatTheWallIsDoing() throws {
    var s = WallSnapshot(mode: "explore", subjectId: "christ", header: nil, title: nil, short: nil, story: nil,
                         verses: [], paused: false, tuning: Tuning(), soundOn: false, showPainting: false)
    s.still = SlowProgress(figure: 3, of: 13)
    s.dreamcoat = true
    s.seasons = [.thanksgiving]
    s.demo = false
    let back = try JSONDecoder().decode(WallSnapshot.self, from: JSONEncoder().encode(s))
    #expect(back == s)
    #expect(back.status == ["Be still · 3 of 13", "Dreamcoat", "Thanksgiving"])
    // A wall built before these fields existed still decodes, with nothing to report.
    let old = #"{"mode":"rest","verses":[],"paused":false,"tuning":{},"soundOn":false,"showPainting":false}"#
    let o = try JSONDecoder().decode(WallSnapshot.self, from: Data(old.utf8))
    #expect(o.status.isEmpty)
}

@Test func theNewPhoneCommandsRoundTrip() throws {
    for c: PhoneCommand in [.beStill(true), .beStill(false), .dreamcoat(true), .dreamcoat(false)] {
        #expect(try JSONDecoder().decode(PhoneCommand.self, from: JSONEncoder().encode(c)) == c)
    }
}

// MARK: Matt, 2026-11-16: a cross at Easter; the star shines down on Jesus; a crown of light.

@Test func theStarShinesAllChristmasAndChristWearsLight() {
    for day in [(2026, 12, 3), (2026, 12, 24), (2027, 1, 6)] {
        let e = Seasons.effects(at: at(day.0, day.1, day.2, 20), calendar: cal)
        #expect(e.star && e.halo, "\(day)")
    }
    #expect(!Seasons.effects(at: at(2026, 11, 20, 20), calendar: cal).halo)
}

@Test func easterDayHasTheCrossAndTheCrownAllDay() {
    let e = Seasons.effects(at: at(2027, 3, 28, 20), calendar: cal)   // Easter evening: dawn is over
    #expect(e.cross && e.halo && !e.easterDawn)
    #expect(!Seasons.effects(at: at(2027, 3, 29, 9), calendar: cal).cross)
}

@Test func switchingEasterOnShowsTheCross() {
    let e = Seasons.effects(at: at(2026, 7, 4, 15), tuning: tuning([.easter: .on]), calendar: cal)
    #expect(e.cross && e.easterDawn && e.halo)
    let off = Seasons.effects(at: at(2027, 3, 28, 9), tuning: tuning([.easter: .off]), calendar: cal)
    #expect(!off.cross && !off.easterDawn && !off.halo)
}
