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
    private static let painting: UIImage? = Bundle.main.path(forResource: "painting", ofType: "jpg").flatMap(UIImage.init(contentsOfFile:))
    @State private var machine: ModeMachine?
    @State private var tuningSession: TuningSession?
    private let content = ContentLoader.load()
    private let ticker = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    private static var now: Double { Date().timeIntervalSinceReferenceDate }

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
                                if case let .save(cal) = outcome { store.save(cal) }
                                machine?.finishCalibration()
                            })
                    } else if let cal = store.saved {
                        artwork(cal, screen: geo.size)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            if machine == nil { machine = ModeMachine(calibrated: store.saved != nil, now: Self.now) }
        }
        .onReceive(ticker) { _ in tick() }
        // Waking the Apple TV (or dismissing its screensaver) is use, even though the press
        // never reaches the app: hold the screensaver off again for the next 6 hours.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { machine?.noteActivity(now: Self.now); updateIdleTimer() }
        }
    }

    @ViewBuilder
    private func artwork(_ cal: Calibration, screen: CGSize) -> some View {
        switch content {
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
                               targets: lightTargets(mode, content), exploring: isExploring(mode))
                    switch mode {
                    case .stillness:
                        GlintLayer(points: content.glints, tuning: tuningStore.tuning, calibration: cal,
                                   demo: UserDefaults.standard.bool(forKey: "glintDemo"))
                    case let .explore(id, expanded):
                        ExploreView(library: content.library, state: .exploring(id: id, expanded: expanded),
                                    calibration: cal)
                    case let .unfold(p):
                        UnfoldView(script: content.script, playback: p, library: content.library, calibration: cal)
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
        if m.handle(input, now: Self.now, library: content.library, script: content.script) == .togglePainting {
            showPainting.toggle()
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
        guard var m = machine, case let .success(c) = content else { return }
        m.tick(now: Self.now, dt: 0.25, script: c.script)
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
        case .tuning: ["christ"]
        default: []
        }
    }

    private func isExploring(_ mode: Mode) -> Bool {
        switch mode {
        case .explore, .tuning:
            return true
        case let .unfold(p):
            guard case let .success(c) = content else { return true }
            return !UnfoldView.targets(c.script, p).contains(UnfoldBeat.wholeTarget)
        default:
            return false
        }
    }

    private func startingCalibration(for screen: PixelSize) -> Calibration {
        if let saved = store.saved, saved.matches(output: screen) { return saved }
        return .defaultFor(artworkAspect: Artwork.aspect, output: screen)
    }
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
