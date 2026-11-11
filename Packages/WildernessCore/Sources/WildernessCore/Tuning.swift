import Foundation

/// Light values tuned live on the wall (spec §5.4). Defaults are the spec's starting points.
public struct Tuning: Codable, Equatable, Sendable {
    public var subjectStrength = 0.44
    public var baseWash = 0.0   // Matt: the background must be completely black
    public var exploreWashFactor = 0.45
    public var glintMeanInterval = 8.0
    public var glintBrightness = 1.0
    /// Matt's wall is ~17 projector px per inch: below ~0.1 in a glint is a pixel or two.
    public var glintSizeInches = 0.15
    public var glintStyle: GlintStyle = .thread
    /// Explore: strength of the thin line drawn around the chosen figure (0 = off).
    public var edgeLine = 0.8
    /// At rest: peak opacity of each region's slow breath (0 = off). See `Breathing`.
    public var breathing = 0.06
    /// At rest: a soft band of light crossing the tapestry every few minutes. See `PassingLight`.
    public var passingLight = false

    public init() {}
    public static let defaults = Tuning()
    public static let storageKey = "tuning.v1"

    /// A new field must be added here and in `init(from:)`, or it is silently not saved.
    enum CodingKeys: String, CodingKey {
        case subjectStrength, baseWash, exploreWashFactor, glintMeanInterval, glintBrightness, glintSizeInches, glintStyle
        case edgeLine, breathing, passingLight
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
    }

    public var glintParams: GlintParams {
        var p = GlintParams()
        p.meanInterval = glintMeanInterval
        return p
    }
}

public enum TuningRow: Int, CaseIterable, Sendable {
    case subjectStrength, baseWash, edgeLine, breathing, passingLight, glintFrequency, glintBrightness, glintSize, glintStyle, resetDefaults
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
        case .glintBrightness: tuning.glintBrightness = step(tuning.glintBrightness, 0.05, 0.2...1)
        case .glintSize: tuning.glintSizeInches = step(tuning.glintSizeInches, 0.05, 0.05...0.6)
        case .glintStyle: tuning.glintStyle = tuning.glintStyle == .thread ? .pinpoint : .thread
        case .glintFrequency:
            let f = Self.frequencies
            let i = f.firstIndex { $0.seconds == tuning.glintMeanInterval } ?? 1
            tuning.glintMeanInterval = f[min(max(i + Int(sign), 0), f.count - 1)].seconds
        case .resetDefaults: break
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
        case .glintFrequency:
            return "Glints · " + (frequencies.first { $0.seconds == t.glintMeanInterval }?.name ?? "\(t.glintMeanInterval) s")
        case .glintBrightness: return "Glint brightness · \(pct(t.glintBrightness))"
        case .glintSize: return "Glint size · \(String(format: "%.2f", t.glintSizeInches)) in"
        case .glintStyle: return "Glint style · " + (t.glintStyle == .thread ? "along a thread" : "pinpoint")
        case .resetDefaults: return "Reset to defaults"
        }
    }
}
