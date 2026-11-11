import Foundation

public enum SettingsItem: Int, CaseIterable, Sendable { case calibrate, tune, pattern, painting, about }
/// The guest-facing front door: a short list beside the tapestry (Select at rest).
public enum MenuItem: Int, CaseIterable, Sendable { case explore, unfold }

/// Everything the app can be showing (spec §5).
public enum Mode: Equatable, Sendable {
    case stillness
    case menu(focus: MenuItem)
    case explore(id: String, expanded: Bool)
    case unfold(UnfoldPlayback)
    case settings(focus: SettingsItem)
    case calibrating, tuning, pattern, about
}

public enum AppInput: Sendable { case move(NudgeDirection), select, holdSelect, playPause, back }
public enum ModeEffect: Equatable, Sendable {
    case exitApp
    /// Debug: show or hide the painting projected under everything (Settings → Show painting).
    case togglePainting
}

/// The remote map of spec §5.5 as a pure state machine. Calibration and tuning presses are
/// handled by `CalibrationSession` / `TuningSession`; this machine only knows how to leave them.
public struct ModeMachine: Equatable, Sendable {
    public static let exploreIdleTimeout = 45.0

    public private(set) var mode: Mode
    public private(set) var lastInputAt: Double
    /// The one-line "how to use this mode" hint shows until this time; set only when a mode is
    /// entered from the menu, so shortcuts (arrows, Play/Pause at rest) never nag.
    public private(set) var hintUntil: Double?
    public static let hintDuration = 6.0

    public init(calibrated: Bool, now: Double) {
        mode = calibrated ? .stillness : .calibrating
        lastInputAt = now
    }

    @discardableResult
    public mutating func handle(_ input: AppInput, now: Double, library: AnnotationLibrary,
                                script: UnfoldScript) -> ModeEffect? {
        lastInputAt = now
        let before = mode
        var fromMenu = false
        defer {
            if fromMenu { hintUntil = now + Self.hintDuration }
            else if before.kind != mode.kind { hintUntil = nil }
        }
        switch (mode, input) {
        case (.stillness, .back):
            return .exitApp
        case (.stillness, .select), (.stillness, .move(.up)), (.stillness, .move(.down)):
            mode = .menu(focus: .explore)
        case (.menu(let f), .move(.up)):
            mode = .menu(focus: MenuItem(rawValue: max(f.rawValue - 1, 0))!)
        case (.menu(let f), .move(.down)):
            mode = .menu(focus: MenuItem(rawValue: min(f.rawValue + 1, MenuItem.allCases.count - 1))!)
        case (.menu(.explore), .select):
            var e = ExploreState.idle
            e.handle(.move(.right), library: library)
            if case let .exploring(id, expanded) = e { mode = .explore(id: id, expanded: expanded); fromMenu = true }
        case (.menu(.unfold), .select):
            mode = .unfold(.start); fromMenu = true
        case (.menu, .back):
            mode = .stillness
        case (.stillness, .move(let d)):
            var e = ExploreState.idle
            e.handle(.move(d), library: library)
            if case let .exploring(id, expanded) = e { mode = .explore(id: id, expanded: expanded) }
        case (.stillness, .playPause), (.explore, .playPause), (.menu, .playPause):
            mode = .unfold(.start)
        case (.stillness, .holdSelect), (.explore, .holdSelect), (.menu, .holdSelect):
            mode = .settings(focus: .calibrate)
        case (.explore(let id, let expanded), .move), (.explore(let id, let expanded), .select):
            var e = ExploreState.exploring(id: id, expanded: expanded)
            e.handle(input == .select ? .select : .move(input.direction!), library: library)
            if case let .exploring(nid, nexp) = e { mode = .explore(id: nid, expanded: nexp) }
        case (.explore, .back):
            mode = .menu(focus: .explore)
        case (.unfold, .back):
            mode = .menu(focus: .unfold)
        case (.settings, .back):
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
        case (.settings(.painting), .select):
            return .togglePainting
        case (.settings(let f), .select):
            mode = switch f {
            case .calibrate: .calibrating
            case .tune: .tuning
            case .pattern, .painting: .pattern
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

    /// Settings and About return to Stillness after this long without a press.
    public static let menuIdleTimeout = 45.0
    /// Tune light, the alignment pattern and a paused Unfold get longer: they are used while
    /// looking at the wall, but must not stay projected all evening.
    public static let workIdleTimeout = 300.0

    /// Time passing: idle modes fall back to Stillness; a playing Unfold plays on to its end.
    /// Calibration never times out.
    public mutating func tick(now: Double, dt: Double, script: UnfoldScript) {
        if let h = hintUntil, now >= h { hintUntil = nil }
        let idle = now - lastInputAt
        switch mode {
        case .explore where idle >= Self.exploreIdleTimeout,
             .menu where idle >= Self.menuIdleTimeout,
             .settings where idle >= Self.menuIdleTimeout,
             .about where idle >= Self.menuIdleTimeout,
             .tuning where idle >= Self.workIdleTimeout,
             .pattern where idle >= Self.workIdleTimeout:
            mode = .stillness
        case .unfold(let p) where p.paused:
            if idle >= Self.workIdleTimeout { mode = .stillness }
        case .unfold(let p):
            mode = script.advance(p, by: dt).map { .unfold($0) } ?? .stillness
        default:
            break
        }
    }

    /// Something happened that wasn't a press this machine saw, such as the app returning to
    /// the foreground after the Apple TV woke. Counts as use for the awake policy and timeouts.
    public mutating func noteActivity(now: Double) { lastInputAt = now }

    public mutating func finishCalibration() {
        if mode == .calibrating { mode = .stillness }
    }

    public func showsHint(now: Double) -> Bool { hintUntil.map { now < $0 } ?? false }

    /// Test hook: start from an arbitrary mode.
    mutating func force(_ m: Mode) { mode = m }
}

extension Mode {
    /// Which screen this is, ignoring where in it: moving within a mode keeps its hint.
    var kind: Int {
        switch self {
        case .stillness: 0
        case .menu: 1
        case .explore: 2
        case .unfold: 3
        case .settings: 4
        case .calibrating: 5
        case .tuning: 6
        case .pattern: 7
        case .about: 8
        }
    }

    /// The faint "you are here" line at the top of the text column, e.g. "UNFOLD · 2 of 8".
    public func wayfinding(library: AnnotationLibrary, script: UnfoldScript) -> String? {
        switch self {
        case .explore:
            // No "3 of 11": arrows move to the nearest subject that way, so a count would jump.
            return "EXPLORE"
        case let .unfold(p):
            return "UNFOLD · \(p.beat + 1) of \(script.beats.count)"
        default:
            return nil
        }
    }
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
