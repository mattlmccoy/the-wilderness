import Foundation

/// Light values tuned live on the wall (spec §5.4). Defaults are the spec's starting points.
public struct Tuning: Codable, Equatable, Sendable {
    public var subjectStrength = 0.44
    public var baseWash = 0.0   // Matt: the background must be completely black
    public var exploreWashFactor = 0.45
    public var glintMeanInterval = 8.0
    public var glintBrightness = 1.0
    /// Matt's wall is ~17 projector px per inch: below ~0.1 in a glint is a pixel or two.
    public var glintSizeInches = 0.3
    public var glintStyle: GlintStyle = .thread
    /// Explore: strength of the thin line drawn around the chosen figure (0 = off).
    public var edgeLine = 0.8
    /// At rest: peak opacity of each region's slow breath (0 = off). See `Breathing`.
    public var breathing = 0.06
    /// At rest: a soft band of light crossing the tapestry every few minutes. See `PassingLight`.
    public var passingLight = false
    /// At rest: a soft light drifting slowly from figure to figure, as a share of the subject light
    /// (0 = off). See `Drift`.
    public var drift = 0.5
    /// Christmas hats, Advent candles, the Easter dawn and the rest of the church year (2026-11-16).
    public var seasons = true
    /// The light warms and dims with the time of day (sunrise and sunset at home).
    public var followDay = true
    /// Per-season Auto / On / Off from Settings (missing = auto), keyed by `SeasonMode.rawValue`.
    public var seasonSwitches: [String: SeasonSwitch] = [:]

    public func switchFor(_ m: SeasonMode) -> SeasonSwitch { seasonSwitches[m.rawValue] ?? .auto }
    public mutating func setSwitch(_ m: SeasonMode, _ v: SeasonSwitch) {
        seasonSwitches[m.rawValue] = v == .auto ? nil : v
    }

    public init() {}
    public static let defaults = Tuning()
    public static let storageKey = "tuning.v1"

    /// A new field must be added here and in `init(from:)`, or it is silently not saved.
    enum CodingKeys: String, CodingKey {
        case subjectStrength, baseWash, exploreWashFactor, glintMeanInterval, glintBrightness, glintSizeInches, glintStyle
        case edgeLine, breathing, passingLight, seasons, followDay, seasonSwitches, drift
    }

    /// Tolerant of profiles saved before a field existed: a missing key takes that field's
    /// default and every saved value is kept. A present but unreadable value still throws.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = Tuning()
        subjectStrength = try c.decodeIfPresent(Double.self, forKey: .subjectStrength) ?? d.subjectStrength
        baseWash = try c.decodeIfPresent(Double.self, forKey: .baseWash) ?? d.baseWash
        exploreWashFactor = try c.decodeIfPresent(Double.self, forKey: .exploreWashFactor) ?? d.exploreWashFactor
        glintMeanInterval = try c.decodeIfPresent(Double.self, forKey: .glintMeanInterval) ?? d.glintMeanInterval
        glintBrightness = try c.decodeIfPresent(Double.self, forKey: .glintBrightness) ?? d.glintBrightness
        glintSizeInches = try c.decodeIfPresent(Double.self, forKey: .glintSizeInches) ?? d.glintSizeInches
        glintStyle = try c.decodeIfPresent(GlintStyle.self, forKey: .glintStyle) ?? d.glintStyle
        edgeLine = try c.decodeIfPresent(Double.self, forKey: .edgeLine) ?? d.edgeLine
        breathing = try c.decodeIfPresent(Double.self, forKey: .breathing) ?? d.breathing
        passingLight = try c.decodeIfPresent(Bool.self, forKey: .passingLight) ?? d.passingLight
        seasons = try c.decodeIfPresent(Bool.self, forKey: .seasons) ?? d.seasons
        followDay = try c.decodeIfPresent(Bool.self, forKey: .followDay) ?? d.followDay
        drift = try c.decodeIfPresent(Double.self, forKey: .drift) ?? d.drift
        seasonSwitches = try c.decodeIfPresent([String: SeasonSwitch].self, forKey: .seasonSwitches) ?? d.seasonSwitches
    }

    /// Every value inside the range the wall's Tune screen allows (the phone sends whole Tunings).
    public var clamped: Tuning {
        func c(_ v: Double, _ r: ClosedRange<Double>) -> Double { min(max(v, r.lowerBound), r.upperBound) }
        var t = self
        t.subjectStrength = c(subjectStrength, 0...1)
        t.baseWash = c(baseWash, 0...0.5)
        t.exploreWashFactor = c(exploreWashFactor, 0...1)
        t.edgeLine = c(edgeLine, 0...1)
        t.breathing = c(breathing, 0...0.3)
        t.drift = c(drift, 0...1)
        t.glintBrightness = c(glintBrightness, 0.2...1)
        t.glintSizeInches = c(glintSizeInches, 0.05...0.6)
        t.glintMeanInterval = c(glintMeanInterval, 4...16)
        return t
    }

    public var glintParams: GlintParams {
        var p = GlintParams()
        p.meanInterval = glintMeanInterval
        return p
    }
}

public enum TuningRow: Int, CaseIterable, Sendable {
    case subjectStrength, baseWash, edgeLine, breathing, drift, passingLight, glintFrequency, glintBrightness, glintSize, glintStyle, resetDefaults
    /// Through the year: the second column of the Tune screen.
    case seasons, followDay, advent, christmas, lent, easter, thanksgiving

    public static var lightRows: [TuningRow] { allCases.filter { $0.rawValue <= TuningRow.resetDefaults.rawValue } }
    public static var yearRows: [TuningRow] { allCases.filter { $0.rawValue > TuningRow.resetDefaults.rawValue } }

    /// The season this row switches, if it is one.
    public var season: SeasonMode? {
        switch self {
        case .advent: .advent
        case .christmas: .christmas
        case .lent: .lent
        case .easter: .easter
        case .thanksgiving: .thanksgiving
        default: nil
        }
    }
}

/// The tuning screen's remote logic: up/down picks a row, left/right changes its value.
public struct TuningSession: Sendable {
    public private(set) var tuning: Tuning
    public private(set) var row: TuningRow = .subjectStrength

    /// Rare, now and then, often: mean seconds between glints.
    static let frequencies: [(seconds: Double, name: String)] = [(16, "rare"), (8, "now and then"), (4, "often")]

    public init(tuning: Tuning) { self.tuning = tuning }

    public mutating func handle(_ d: NudgeDirection) {
        switch d {
        case .up: row = TuningRow(rawValue: max(row.rawValue - 1, 0))!
        case .down: row = TuningRow(rawValue: min(row.rawValue + 1, TuningRow.allCases.count - 1))!
        case .left: change(by: -1)
        case .right: change(by: 1)
        }
    }

    public mutating func select() {
        if row == .resetDefaults { tuning = .defaults }
    }

    private mutating func change(by sign: Double) {
        func step(_ v: Double, _ by: Double, _ r: ClosedRange<Double>) -> Double {
            (min(max(v + sign * by, r.lowerBound), r.upperBound) * 100).rounded() / 100
        }
        switch row {
        case .subjectStrength: tuning.subjectStrength = step(tuning.subjectStrength, 0.02, 0...1)
        case .baseWash: tuning.baseWash = step(tuning.baseWash, 0.01, 0...0.5)
        case .edgeLine: tuning.edgeLine = step(tuning.edgeLine, 0.05, 0...1)
        case .breathing: tuning.breathing = step(tuning.breathing, 0.02, 0...0.3)
        case .passingLight: tuning.passingLight.toggle()
        case .drift: tuning.drift = step(tuning.drift, 0.05, 0...1)
        case .glintBrightness: tuning.glintBrightness = step(tuning.glintBrightness, 0.05, 0.2...1)
        case .glintSize: tuning.glintSizeInches = step(tuning.glintSizeInches, 0.05, 0.05...0.6)
        case .glintStyle: tuning.glintStyle = tuning.glintStyle == .thread ? .pinpoint : .thread
        case .glintFrequency:
            let f = Self.frequencies
            let i = f.firstIndex { $0.seconds == tuning.glintMeanInterval } ?? 1
            tuning.glintMeanInterval = f[min(max(i + Int(sign), 0), f.count - 1)].seconds
        case .resetDefaults: break
        case .seasons: tuning.seasons.toggle()
        case .followDay: tuning.followDay.toggle()
        case .advent, .christmas, .lent, .easter, .thanksgiving:
            guard let m = row.season else { break }
            let order = SeasonSwitch.allCases, i = order.firstIndex(of: tuning.switchFor(m))!
            tuning.setSwitch(m, order[(i + (sign > 0 ? 1 : order.count - 1)) % order.count])
        }
    }

    public var rowLabel: String { Self.label(row, tuning) }

    public static func label(_ row: TuningRow, _ t: Tuning) -> String {
        let pct = { (v: Double) in "\(Int((v * 100).rounded()))%" }
        switch row {
        case .subjectStrength: return "Light on subjects · \(pct(t.subjectStrength))"
        case .baseWash: return "Background wash · \(pct(t.baseWash))"
        case .edgeLine: return "Edge line · " + (t.edgeLine == 0 ? "off" : pct(t.edgeLine))
        case .breathing: return "Breathing · " + (t.breathing == 0 ? "off" : pct(t.breathing))
        case .passingLight: return "Passing light · " + (t.passingLight ? "on" : "off")
        case .drift: return "Drifting light · " + (t.drift == 0 ? "off" : pct(t.drift))
        case .glintFrequency:
            return "Glints · " + (frequencies.first { $0.seconds == t.glintMeanInterval }?.name ?? "\(t.glintMeanInterval) s")
        case .glintBrightness: return "Glint brightness · \(pct(t.glintBrightness))"
        case .glintSize: return "Glint size · \(String(format: "%.2f", t.glintSizeInches)) in"
        case .glintStyle: return "Glint style · " + (t.glintStyle == .thread ? "along a thread" : "pinpoint")
        case .resetDefaults: return "Reset to defaults"
        case .seasons: return "Seasons · " + (t.seasons ? "on" : "off")
        case .followDay: return "Light follows the day · " + (t.followDay ? "on" : "off")
        case .advent, .christmas, .lent, .easter, .thanksgiving:
            let m = row.season!
            return "\(m.title) · \(t.switchFor(m).rawValue)"
        }
    }
}
