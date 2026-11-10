import Foundation

public enum SettingsItem: Int, CaseIterable, Sendable { case calibrate, tune, pattern, about }

/// Everything the app can be showing (spec §5).
public enum Mode: Equatable, Sendable {
    case stillness
    case explore(id: String, expanded: Bool)
    case unfold(UnfoldPlayback)
    case settings(focus: SettingsItem)
    case calibrating, tuning, pattern, about
}

public enum AppInput: Sendable { case move(NudgeDirection), select, holdSelect, playPause, back }
public enum ModeEffect: Equatable, Sendable { case exitApp }

/// The remote map of spec §5.5 as a pure state machine. Calibration and tuning presses are
/// handled by `CalibrationSession` / `TuningSession`; this machine only knows how to leave them.
public struct ModeMachine: Sendable {
    public static let exploreIdleTimeout = 45.0

    public private(set) var mode: Mode
    public private(set) var lastInputAt: Double

    public init(calibrated: Bool, now: Double) {
        mode = calibrated ? .stillness : .calibrating
        lastInputAt = now
    }

    @discardableResult
    public mutating func handle(_ input: AppInput, now: Double, library: AnnotationLibrary,
                                script: UnfoldScript) -> ModeEffect? {
        lastInputAt = now
        switch (mode, input) {
        case (.stillness, .back):
            return .exitApp
        case (.stillness, .move(let d)):
            var e = ExploreState.idle
            e.handle(.move(d), library: library)
            if case let .exploring(id, expanded) = e { mode = .explore(id: id, expanded: expanded) }
        case (.stillness, .playPause), (.explore, .playPause):
            mode = .unfold(.start)
        case (.stillness, .holdSelect), (.explore, .holdSelect):
            mode = .settings(focus: .calibrate)
        case (.explore(let id, let expanded), .move), (.explore(let id, let expanded), .select):
            var e = ExploreState.exploring(id: id, expanded: expanded)
            e.handle(input == .select ? .select : .move(input.direction!), library: library)
            if case let .exploring(nid, nexp) = e { mode = .explore(id: nid, expanded: nexp) }
        case (.explore, .back), (.unfold, .back), (.settings, .back):
            mode = .stillness
        case (.unfold(var p), .playPause):
            p.paused.toggle()
            mode = .unfold(p)
        case (.unfold(let p), .move(.right)):
            mode = script.next(p).map { .unfold($0) } ?? .stillness
        case (.unfold(let p), .move(.left)):
            mode = .unfold(script.previous(p))
        case (.settings(let f), .move(.up)):
            mode = .settings(focus: SettingsItem(rawValue: max(f.rawValue - 1, 0))!)
        case (.settings(let f), .move(.down)):
            mode = .settings(focus: SettingsItem(rawValue: min(f.rawValue + 1, SettingsItem.allCases.count - 1))!)
        case (.settings(let f), .select):
            mode = switch f {
            case .calibrate: .calibrating
            case .tune: .tuning
            case .pattern: .pattern
            case .about: .about
            }
        case (.tuning, .back):
            mode = .settings(focus: .tune)
        case (.pattern, .back):
            mode = .settings(focus: .pattern)
        case (.about, .back):
            mode = .settings(focus: .about)
        default:
            break
        }
        return nil
    }

    /// Time passing: Explore falls back to Stillness after 45 s idle; Unfold plays on.
    public mutating func tick(now: Double, dt: Double, script: UnfoldScript) {
        switch mode {
        case .explore where now - lastInputAt >= Self.exploreIdleTimeout:
            mode = .stillness
        case .unfold(let p):
            mode = script.advance(p, by: dt).map { .unfold($0) } ?? .stillness
        default:
            break
        }
    }

    public mutating func finishCalibration() {
        if mode == .calibrating { mode = .stillness }
    }

    /// Test hook: start from an arbitrary mode.
    mutating func force(_ m: Mode) { mode = m }
}

extension AppInput: Equatable {
    var direction: NudgeDirection? { if case let .move(d) = self { return d }; return nil }
}

/// While the app is open it holds off the screensaver and sleep, but hands that back after
/// 6 hours with no remote press, so a projector switched off for the night lets the Apple TV sleep.
public enum AwakePolicy {
    public static let releaseAfter = 6.0 * 3600
    public static func keepAwake(lastInputAt: Double, now: Double) -> Bool { now - lastInputAt < releaseAfter }
}
