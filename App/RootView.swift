import SwiftUI
import WildernessCore

/// Wires the remote to `ModeMachine` (the remote map of spec §5.5) and draws each mode.
/// One LightLayer stays on screen across modes, so light fades between them instead of
/// popping; text, glints and Settings sit on top.
struct RootView: View {
    @StateObject private var store = CalibrationStore()
    @StateObject private var tuningStore = TuningStore()
    @Environment(\.scenePhase) private var scenePhase
    /// Debug: project the painting under everything to check where light and text land.
    // On by default while the tapestry is not hung yet (Matt); turn off in Settings → Show painting.
    @AppStorage("debug.showPainting") private var showPainting = true
    /// Menu → Sound: the quiet wind bed, off by default (Matt, 2026-11-10).
    @AppStorage("sound.on") private var soundOn = false
    @State private var sound = SoundPlayer()
    private static let painting: UIImage? = Bundle.main.path(forResource: "painting", ofType: "jpg").flatMap(UIImage.init(contentsOfFile:))
    @State private var machine: ModeMachine?
    @State private var tuningSession: TuningSession?
    /// Decoded once per process, not on every RootView re-creation. A failure is kept too,
    /// so the visible "Content failed to load" message still shows.
    private static let content = ContentLoader.load()
    private let ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    /// Measures the real time between ticks; a box, so updating it never redraws the view.
    @State private var clock = TickClockBox()

    private static var now: Double { Date().timeIntervalSinceReferenceDate }
    /// UI tests launch with `-skipIntro YES` so their first press acts at rest, as before.
    private static var skipIntro: Bool { UserDefaults.standard.bool(forKey: "skipIntro") }

    var body: some View {
        GeometryReader { geo in
            let screen = PixelSize(width: geo.size.width, height: geo.size.height)
            ZStack {
                Color.black
                if let m = machine {
                    if m.mode == .calibrating || store.saved == nil {
                        CalibrationView(
                            start: startingCalibration(for: screen),
                            screen: geo.size,
                            canCancel: store.saved != nil,
                            onFinish: { outcome in
                                var saved = false
                                if case let .save(cal) = outcome { store.save(cal); saved = true }
                                machine?.finishCalibration(now: Self.now, playIntro: saved && !Self.skipIntro)
                            })
                    } else if let cal = store.saved {
                        artwork(cal, screen: geo.size)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            if machine == nil {
                machine = ModeMachine(calibrated: store.saved != nil, now: Self.now, intro: !Self.skipIntro)
            }
        }
        .onReceive(ticker) { _ in tick() }
        // Waking the Apple TV (or dismissing its screensaver) is use, even though the press
        // never reaches the app: hold the screensaver off again for the next 6 hours.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { machine?.noteActivity(now: Self.now); updateIdleTimer(); sound.resume() }
        }
    }

    @ViewBuilder
    private func artwork(_ cal: Calibration, screen: CGSize) -> some View {
        switch Self.content {
        case let .failure(error):
            // Visible and distinct: never a silent dark wall that looks like "working".
            Text("Content failed to load: \(String(describing: error))")
                .font(.system(size: 18)).foregroundStyle(Palette.gold)
        case let .success(content):
            let mode = machine?.mode ?? .stillness
            MappedCanvas(calibration: cal, screen: screen) {
                ZStack(alignment: .topLeading) {
                    if showPainting, let img = Self.painting {
                        Image(uiImage: img).resizable()
                            .frame(width: Artwork.canvasWidth, height: Artwork.canvasHeight)
                    }
                    LightLayer(library: content.library, tuning: tuningStore.tuning,
                               targets: lightTargets(mode, content), exploring: mode.dimsWash(script: content.script, context: content.context),
                               dark: mode.isIntro)
                    switch mode {
                    case let .intro(startedAt):
                        IntroView(library: content.library, tuning: tuningStore.tuning, startedAt: startedAt)
                            .transition(.opacity.animation(.easeOut(duration: 1.0)))
                    case .stillness:
                        GlintLayer(points: content.glints, tuning: tuningStore.tuning, calibration: cal,
                                   demo: UserDefaults.standard.bool(forKey: "glintDemo"))
                    case let .menu(focus):
                        GlintLayer(points: content.glints, tuning: tuningStore.tuning, calibration: cal,
                                   demo: UserDefaults.standard.bool(forKey: "glintDemo"))
                        MenuView(focus: focus, calibration: cal, soundOn: soundOn, soundAvailable: sound.available)
                            .transition(.opacity.animation(.easeInOut(duration: LightTiming.textOut)))
                    case let .explore(id, expanded):
                        ExploreView(library: content.library, state: .exploring(id: id, expanded: expanded),
                                    calibration: cal, showsHint: machine?.hintUntil != nil)
                    case let .unfold(p):
                        UnfoldView(script: content.script, playback: p, library: content.library, calibration: cal,
                                   header: mode.wayfinding(library: content.library, script: content.script),
                                   showsHint: machine?.hintUntil != nil)
                    case let .context(page):
                        ContextView(script: content.context, page: page, calibration: cal,
                                    header: mode.wayfinding(library: content.library, script: content.script,
                                                            context: content.context),
                                    showsHint: machine?.hintUntil != nil)
                    case .pattern:
                        RegistrationTestPattern()
                    case .tuning:
                        GlintLayer(points: content.glints, tuning: tuningStore.tuning, calibration: cal, demo: true)
                        SettingsView(mode: mode, tuning: tuningSession, notices: content.notices, showPainting: showPainting)
                    case .settings, .about:
                        SettingsView(mode: mode, tuning: nil, notices: content.notices, showPainting: showPainting)
                    case .calibrating:
                        EmptyView()
                    }
                }
            }
            .focusable()
            .onMoveCommand { direction in
                if mode == .tuning { tuningSession?.handle(direction.nudge); applyTuning() }
                send(.move(direction.nudge), content)   // in tuning this only records the press
            }
            .onTapGesture {
                if mode == .tuning { tuningSession?.select(); applyTuning() }
                send(.select, content)   // in tuning this only records the press
            }
            // Hold Select for a second → Settings. A UIKit press recognizer, because SwiftUI's
            // long press is cancelled by the thumb's small movements on a real Siri Remote.
            .background(SelectHoldDetector { send(.holdSelect, content) })
            .onPlayPauseCommand { send(.playPause, content) }
            // In Stillness, pass Back through so tvOS returns to the home screen.
            .onExitCommand(perform: mode == .stillness ? nil : { send(.back, content) })
        }
    }

    private func send(_ input: AppInput, _ content: AppContent) {
        guard var m = machine else { return }
        switch m.handle(input, now: Self.now, library: content.library, script: content.script,
                        context: content.context) {
        case .togglePainting: showPainting.toggle()
        case .toggleSound: soundOn.toggle()
        default: break
        }
        if m.mode == .tuning, tuningSession == nil { tuningSession = TuningSession(tuning: tuningStore.tuning) }
        if m.mode != .tuning { tuningSession = nil }
        machine = m
        updateIdleTimer()
    }

    private func applyTuning() {
        if let t = tuningSession?.tuning, t != tuningStore.tuning { tuningStore.tuning = t }
    }

    private func tick() {
        guard var m = machine, case let .success(c) = Self.content else { return }
        let now = Self.now
        let dt = clock.value.dt(now: now)
        m.tick(now: now, dt: dt, script: c.script)
        sound.update(target: Soundscape.target(mode: m.mode, on: soundOn), dt: dt)
        if m != machine { machine = m }
        updateIdleTimer()
    }

    private func updateIdleTimer() {
        guard let m = machine else { return }
        let keep = AwakePolicy.keepAwake(lastInputAt: m.lastInputAt, now: Self.now)
        if UIApplication.shared.isIdleTimerDisabled != keep { UIApplication.shared.isIdleTimerDisabled = keep }
    }

    private func lightTargets(_ mode: Mode, _ c: AppContent) -> Set<String> {
        switch mode {
        case let .explore(id, _): [id]
        case let .unfold(p): UnfoldView.targets(c.script, p)
        case let .context(page): ContextView.targets(c.context, page: page)
        case .tuning: ["christ"]
        default: []
        }
    }

    private func startingCalibration(for screen: PixelSize) -> Calibration {
        if let saved = store.saved, saved.matches(output: screen) { return saved }
        return .defaultFor(artworkAspect: Artwork.aspect, output: screen)
    }
}

/// Holds the tick clock outside SwiftUI's change tracking.
final class TickClockBox {
    var value = TickClock()
}

extension MoveCommandDirection {
    var nudge: NudgeDirection {
        switch self {
        case .up: .up
        case .down: .down
        case .left: .left
        case .right: .right
        @unknown default: .right
        }
    }
}

private extension Mode {
    var isIntro: Bool { if case .intro = self { return true }; return false }
}
