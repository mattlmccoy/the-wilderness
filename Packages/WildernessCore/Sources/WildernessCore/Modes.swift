import Foundation

public enum SettingsItem: Int, CaseIterable, Sendable { case calibrate, tune, pattern, painting, about, demo }
/// The guest-facing front door: a short list beside the tapestry (Select at rest).
public enum MenuItem: Int, CaseIterable, Sendable { case explore, unfold, context, still, sound }

/// Everything the app can be showing (spec §5).
public enum Mode: Equatable, Sendable {
    case stillness
    /// The boot-up intro: outlines draw around the figures, then fade into Stillness.
    /// Started on a calibrated launch and right after a calibration is saved.
    case intro(startedAt: Double)
    case menu(focus: MenuItem)
    case explore(id: String, expanded: Bool)
    case unfold(UnfoldPlayback)
    /// Context: pages about the painting itself, turned with ← →.
    case context(page: Int)
    case settings(focus: SettingsItem)
    case calibrating, tuning, pattern, about
}

public enum AppInput: Sendable {
    case move(NudgeDirection), select, holdSelect, playPause, back
    /// The phone companion: jump straight to a figure or mode.
    case go(Destination)
}

/// Where the phone can send the wall directly (no stepping through the menu).
public enum Destination: Codable, Equatable, Sendable {
    case explore(String)
    /// Explore from its start, as the menu's Explore does (the phone's Explore button).
    case exploreStart
    case unfold
    case context
}

/// Settings screens the phone can put on the wall.
public enum WallScreen: String, Codable, Sendable { case pattern, about }
public enum ModeEffect: Equatable, Sendable {
    case exitApp
    /// Debug: show or hide the painting projected under everything (Settings → Show painting).
    case togglePainting
    /// Menu → Sound: switch the quiet pad on or off (the menu stays open).
    case toggleSound
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

    /// `intro: false` starts a calibrated machine at rest (UI tests launch with -skipIntro YES).
    public init(calibrated: Bool, now: Double, intro: Bool = true) {
        mode = !calibrated ? .calibrating : intro ? .intro(startedAt: now) : .stillness
        lastInputAt = now
    }

    /// The self-running demo (DemoScript): when it began, or nil.
    public private(set) var demoSince: Double?
    public var isDemo: Bool { demoSince != nil }

    /// Explore with the light only (Matt, 2026-11-16): double-press Play/Pause in Explore, or the
    /// phone. Stays as you move from figure to figure, until toggled again.
    public private(set) var textHidden = false
    /// A single Play/Pause in Explore waits this long in case it is the first of a double press.
    public static let doublePressWindow = 0.4
    private var pendingPlayAt: Double?

    public mutating func setTextHidden(_ hidden: Bool) { textHidden = hidden }

    /// ↑ ↑ ↓ ↓ ← → ← → Select: every outline cycles the rainbow for a minute (the dreamcoat).
    public static let dreamcoatSeconds = 60.0
    private var code = SecretCode()
    /// The mode before each of the last presses, so the code can put the wall back where it began.
    private var modesBeforePress: [Mode] = []
    public private(set) var dreamcoatUntil: Double?
    public func dreamcoat(now: Double) -> Bool { dreamcoatUntil.map { now < $0 } ?? false }

    /// Menu → Be still: Christ alone, His words rotating on the canvas, until any button (StillRotation).
    public private(set) var slowLookingSince: Double?
    public var isSlowLooking: Bool { slowLookingSince != nil }

    /// Be still, from the menu or the phone.
    public mutating func startSlowLooking(now: Double, library: AnnotationLibrary) {
        prayer = nil   // one quiet thing at a time: Be still replaces a prayer session
        slowLookingSince = now
        textHidden = true
        lastInputAt = now
        mode = .explore(id: "christ", expanded: false)
    }

    public mutating func stopSlowLooking() {
        guard slowLookingSince != nil else { return }
        slowLookingSince = nil
        textHidden = false
        mode = .stillness
    }

    // MARK: Into the Quiet (docs/superpowers/specs/2026-11-16-prayer-mode-design.md)

    public private(set) var prayer: PrayerSession?
    public private(set) var prayerPeriod: Prayer.Period = .morning
    private var prayerDarkUntil: Double?
    private var prayerSleeps = false
    private var prayerEndedAt: Double?
    public var isPraying: Bool { prayer != nil }

    /// Starts a session from the phone. `darkUntil`: for a late session, when the wall wakes after
    /// its fade (the next 05:00); nil for a session that ends back at rest.
    public mutating func startPrayer(now: Double, minutes: Int, line: PrayerLine?, period: Prayer.Period, darkUntil: Double?) {
        guard mode != .calibrating else { return }   // never abandons an alignment in progress
        slowLookingSince = nil
        demoSince = nil
        dreamcoatUntil = nil
        textHidden = false
        prayerDarkUntil = nil
        prayerEndedAt = nil
        prayerPeriod = period
        prayerSleeps = darkUntil != nil
        prayer = PrayerSession(startedAt: now, minutes: minutes, line: line, sleeps: darkUntil != nil)
        pendingDark = darkUntil
        mode = .stillness
        lastInputAt = now
    }
    private var pendingDark: Double?

    /// Ends the session (the phone's End, a remote press, or the time running out).
    public mutating func endPrayer(now: Double) {
        guard prayer != nil else { return }
        prayer = nil
        prayerEndedAt = now
        prayerDarkUntil = prayerSleeps ? pendingDark : nil
        mode = .stillness
        lastInputAt = now
    }

    /// Any phone command but a setting wakes the wall from the post-prayer dark.
    public mutating func wakeFromPrayerDark() { prayerDarkUntil = nil }

    /// After a late session the wall stays dark until a press or its wake time.
    public func isAfterPrayerDark(now: Double) -> Bool { prayerDarkUntil.map { now < $0 } ?? false }

    /// The closing line, for a minute after a session ends.
    public func prayerClosing(now: Double) -> String? {
        guard let e = prayerEndedAt, now - e < 60 else { return nil }
        return prayerSleeps ? "Amen. Sleep in peace." : "Amen. Go in peace."
    }

    /// What the phone shows while a session runs.
    public func prayerStatus(now: Double) -> PrayerStatus? {
        guard let p = prayer, let m = p.movement(at: now) else { return nil }
        // No running clock in here: the snapshot changes only when the movement does.
        return PrayerStatus(movement: m.movement, index: m.index, of: m.of, minutes: p.minutes, line: p.line)
    }

    /// The alignment pattern or About, from the phone.
    public mutating func openScreen(_ screen: WallScreen) {
        mode = screen == .pattern ? .pattern : .about
    }

    /// The dreamcoat from the phone: on for its minute, or off at once.
    public mutating func setDreamcoat(_ on: Bool, now: Double) {
        dreamcoatUntil = on ? now + Self.dreamcoatSeconds : nil
    }

    public mutating func startDemo(now: Double) {
        prayer = nil; prayerDarkUntil = nil   // the demo replaces a prayer session
        demoSince = now
        lastInputAt = now
    }

    @discardableResult
    public mutating func handle(_ input: AppInput, now: Double, library: AnnotationLibrary,
                                script: UnfoldScript, context: ContextScript = .empty) -> ModeEffect? {
        // Any press during the demo ends it and leaves the wall at rest.
        if demoSince != nil {
            demoSince = nil
            mode = .stillness
            lastInputAt = now
            return nil
        }
        lastInputAt = now
        // Any press ends a prayer session; after a late one, the first press wakes the wall. Used up.
        if prayer != nil { endPrayer(now: now); return nil }
        if isAfterPrayerDark(now: now) { prayerDarkUntil = nil; return nil }
        // Any press ends the dreamcoat, and does nothing else (Matt, 2026-11-16: no way to turn it off).
        if dreamcoat(now: now) { dreamcoatUntil = nil; return nil }
        // Any press ends slow looking and leaves the wall at rest, words back on.
        if slowLookingSince != nil {
            slowLookingSince = nil
            textHidden = false
            mode = .stillness
            return nil
        }
        // The secret code's last press is used up: it opens nothing else.
        modesBeforePress.append(mode)
        if modesBeforePress.count > SecretCode.sequence.count { modesBeforePress.removeFirst() }
        if code.feed(input) {
            dreamcoatUntil = now + Self.dreamcoatSeconds
            mode = modesBeforePress.first ?? mode   // undo what the code's arrows did on the way
            modesBeforePress = []
            return nil
        }
        // Play/Pause in Explore: once = Unfold (after the window, in tick), twice = hide/show text.
        if input == .playPause, case .explore = mode {
            if let p = pendingPlayAt, now - p <= Self.doublePressWindow {
                pendingPlayAt = nil
                textHidden.toggle()
            } else {
                pendingPlayAt = now
            }
            return nil
        }
        pendingPlayAt = nil   // any other press cancels a waiting Play
        let before = mode
        var fromMenu = false
        defer {
            if fromMenu { hintUntil = now + Self.hintDuration }
            else if before.kind != mode.kind { hintUntil = nil }
        }
        switch (mode, input) {
        case (.calibrating, .go), (.tuning, .go), (.pattern, .go):
            break   // never yank the wall away while it is being aligned or tuned
        case (_, .go(let destination)):
            switch destination {
            case let .explore(id) where library.annotations.contains(where: { $0.id == id }):
                var keepOpen = false
                if case let .explore(_, expanded) = mode { keepOpen = expanded }
                mode = .explore(id: id, expanded: keepOpen)
            case .exploreStart:
                var e = ExploreState.idle
                e.handle(.move(.right), library: library)
                if case let .exploring(id, expanded) = e { mode = .explore(id: id, expanded: expanded); fromMenu = true }
            case .unfold:
                mode = .unfold(.start)
            case .context where !context.pages.isEmpty:
                mode = .context(page: 0)
            default:
                break
            }
        case (.intro, _):
            // Any button skips the intro, and the press is used up: it opens nothing else.
            mode = .stillness
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
        case (.menu(.still), .select):
            startSlowLooking(now: now, library: library)
        case (.menu(.sound), .select):
            return .toggleSound
        case (.menu(.context), .select) where !context.pages.isEmpty:
            mode = .context(page: 0); fromMenu = true
        case (.context(let page), .move(.right)):
            mode = .context(page: min(page + 1, max(context.pages.count - 1, 0)))
        case (.context(let page), .move(.left)):
            mode = .context(page: max(page - 1, 0))
        case (.context, .back):
            mode = .menu(focus: .context)
        case (.context, .playPause):
            mode = .unfold(.start)
        case (.context, .holdSelect):
            mode = .settings(focus: .calibrate)
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
        case (.settings(.demo), .select):
            demoSince = now
            mode = .intro(startedAt: now)
        case (.settings(let f), .select):
            mode = switch f {
            case .calibrate: .calibrating
            case .tune: .tuning
            case .pattern, .painting: .pattern
            case .about: .about
            case .demo: .stillness   // handled above
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

    /// Context pages are read, not glanced at: two minutes before returning to rest.
    public static let readingIdleTimeout = 120.0
    /// Settings and About return to Stillness after this long without a press.
    public static let menuIdleTimeout = 45.0
    /// Tune light, the alignment pattern and a paused Unfold get longer: they are used while
    /// looking at the wall, but must not stay projected all evening.
    public static let workIdleTimeout = 300.0

    /// Time passing: idle modes fall back to Stillness; a playing Unfold plays on to its end.
    /// Calibration never times out; the intro is never cut short, it simply ends.
    public mutating func tick(now: Double, dt: Double, script: UnfoldScript, context: ContextScript = .empty) {
        if let start = demoSince {
            mode = DemoScript.mode(at: now, since: start, script: script, context: context)
            lastInputAt = now   // the demo is never idle
            return
        }
        if let p = prayer {
            if p.isFinished(at: now) { endPrayer(now: now) } else { lastInputAt = now }   // never idle while praying
            return
        }
        if let d = prayerDarkUntil, now >= d { prayerDarkUntil = nil }
        if slowLookingSince != nil {
            // Be still: Christ alone until any button; never idle while it runs.
            mode = .explore(id: "christ", expanded: false)
            lastInputAt = now
            return
        }
        if let h = hintUntil, now >= h { hintUntil = nil }
        if let p = pendingPlayAt, now - p > Self.doublePressWindow {
            pendingPlayAt = nil
            if case .explore = mode { mode = .unfold(.start); hintUntil = nil; return }   // starts now, plays from the next tick
        }
        let idle = now - lastInputAt
        switch mode {
        case .explore where idle >= Self.exploreIdleTimeout,
             .context where idle >= Self.readingIdleTimeout,
             .menu where idle >= Self.menuIdleTimeout,
             .settings where idle >= Self.menuIdleTimeout,
             .about where idle >= Self.menuIdleTimeout,
             .tuning where idle >= Self.workIdleTimeout,
             .pattern where idle >= Self.workIdleTimeout:
            mode = .stillness
        case .intro(let start) where IntroTimeline.isFinished(at: now - start):
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
    /// Never starts the intro again: that plays only on launch and after a calibration is saved.
    public mutating func noteActivity(now: Double) { lastInputAt = now }

    /// The phone's Align: straight into calibration from wherever the wall is.
    public mutating func beginCalibration() {
        mode = .calibrating
    }

    /// Leaves calibration: into the intro when a calibration was just saved (and intros are
    /// not skipped), otherwise straight to Stillness.
    public mutating func finishCalibration(now: Double, playIntro: Bool) {
        if mode == .calibrating { mode = playIntro ? .intro(startedAt: now) : .stillness }
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
        case .intro: 9
        case .context: 10
        }
    }

    /// The faint "you are here" line at the top of the text column, e.g. "UNFOLD · 2 of 8".
    public func wayfinding(library: AnnotationLibrary, script: UnfoldScript,
                           context: ContextScript = .empty) -> String? {
        switch self {
        case .explore:
            // No "3 of 11": arrows move to the nearest subject that way, so a count would jump.
            return "EXPLORE"
        case let .unfold(p):
            return "UNFOLD · \(p.beat + 1) of \(script.beats.count)"
        case let .context(page):
            return "CONTEXT · \(page + 1) of \(context.pages.count)"
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

extension Mode {
    /// Whether the background wash drops (× `Tuning.exploreWashFactor`) so a lit subject stands
    /// out. Not while tuning: the wall shows the wash at the value being set, which is what the
    /// "Background wash" row reads and what Stillness will show.
    public func dimsWash(script: UnfoldScript, context: ContextScript = .empty) -> Bool {
        switch self {
        case .explore: true
        case let .unfold(p): !script.targets(p).contains(UnfoldBeat.wholeTarget)
        case let .context(page): context.pages.indices.contains(page) && !context.pages[page].light.isEmpty
        default: false
        }
    }
}
