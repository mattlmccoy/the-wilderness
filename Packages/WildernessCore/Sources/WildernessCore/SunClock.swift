import Foundation

/// Where the wall hangs, for sunrise and sunset (the Apple TV has no location; home is Atlanta).
public struct Place: Equatable, Sendable {
    public var latitude, longitude: Double
    public static let home = Place(latitude: 33.749, longitude: -84.388)
}

/// Sunrise and sunset by the NOAA approximation (good to a few minutes).
public enum SunClock {
    public static func times(on day: CivilDate, place: Place, calendar: Calendar = .current) -> (sunrise: Date, sunset: Date)? {
        var utc = Calendar(identifier: .gregorian); utc.timeZone = TimeZone(identifier: "UTC")!
        guard let midnight = utc.date(from: DateComponents(year: day.year, month: day.month, day: day.day)),
              let n = utc.ordinality(of: .day, in: .year, for: midnight) else { return nil }
        let g = 2 * Double.pi / 365 * Double(n - 1)
        let eqtime = 229.18 * (0.000075 + 0.001868 * cos(g) - 0.032077 * sin(g) - 0.014615 * cos(2 * g) - 0.040849 * sin(2 * g))
        let decl = 0.006918 - 0.399912 * cos(g) + 0.070257 * sin(g) - 0.006758 * cos(2 * g)
            + 0.000907 * sin(2 * g) - 0.002697 * cos(3 * g) + 0.00148 * sin(3 * g)
        let lat = place.latitude * .pi / 180
        let cosH = cos(90.833 * .pi / 180) / (cos(lat) * cos(decl)) - tan(lat) * tan(decl)
        guard abs(cosH) <= 1 else { return nil }
        let h = acos(cosH) * 180 / .pi
        let rise = 720 - 4 * (place.longitude + h) - eqtime, set = 720 - 4 * (place.longitude - h) - eqtime
        return (midnight.addingTimeInterval(rise * 60), midnight.addingTimeInterval(set * 60))
    }
}

/// The light's mood through the day: `warmth` 0 (neutral) … 1 (candle) and `level` 0…1.
/// Warm at sunrise and sunset, neutral in the day, candle-warm in the evening, dim late at night.
public struct DayLight: Equatable, Sendable {
    public var warmth: Double
    public var level: Double
    public static let neutral = DayLight(warmth: 0, level: 1)

    public static func at(_ date: Date, place: Place, calendar: Calendar = .current) -> DayLight {
        let day = CivilDate(date, calendar: calendar)
        guard let sun = SunClock.times(on: day, place: place, calendar: calendar) else { return .neutral }
        let c = calendar.dateComponents([.hour, .minute], from: date)
        let t = Double(c.hour! * 60 + c.minute!)
        let minute = { (d: Date) -> Double in let k = calendar.dateComponents([.hour, .minute], from: d); return Double(k.hour! * 60 + k.minute!) }
        let sr = minute(sun.sunrise), ss = minute(sun.sunset)
        let ramp = { (x: Double, a: Double, b: Double) in min(max((x - a) / (b - a), 0), 1) }
        switch t {
        case ..<300, (23 * 60)...: return DayLight(warmth: 1, level: 0.6)
        case ..<sr: return DayLight(warmth: 0.8, level: 0.75)
        case ..<(sr + 90): let k = ramp(t, sr, sr + 90); return DayLight(warmth: 0.6 * (1 - k), level: 0.85 + 0.15 * k)
        case ..<(ss - 90): return .neutral
        case ..<(ss + 60): let k = ramp(t, ss - 90, ss + 60); return DayLight(warmth: 0.7 * k, level: 1 - 0.1 * k)
        default: return DayLight(warmth: 0.8, level: 0.85)
        }
    }
}
