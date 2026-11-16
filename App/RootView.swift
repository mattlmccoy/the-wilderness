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
    /// Menu → Sound: the quiet ethereal pad, off by default (Matt, 2026-11-10).
    @AppStorage("sound.on") private var soundOn = false
    @State private var sound = SoundPlayer()
    /// The phone companion (docs/superpowers/specs/2026-11-11-iphone-companion-design.md).
    @State private var companion = CompanionServer()
    private static let painting: UIImage? = Bundle.main.path(forResource: "painting", ofType: "jpg").flatMap(UIImage.init(contentsOfFile:))
    @State private var machine: ModeMachine?
    /// The alignment in progress: shared by the remote (CalibrationView) and the phone (Align).
    @State private var calSession: CalibrationSession?
    @State private var screenSize = PixelSize(width: 1920, height: 1080)
    @State private var tuningSession: TuningSession?
    /// Decoded once per process, not on every RootView re-creation. A failure is kept too,
    /// so the visible "Content failed to load" message still shows.
    private static let content = ContentLoader.load()
    /// Where the alignment instructions sit on the cloth.
    private static let instructionsZone: TextZone = {
        guard case let .success(c) = content else { return .fallback }
        return CanvasText.instructionsZone(library: c.library, zones: c.zones)
    }()
    /// Every traced figure, for checking the alignment against the print.
    private static let outlines: [[Point<ArtworkSpace>]] = {
        guard case let .success(c) = content else { return [] }
        return c.library.annotations.compactMap(\.outline)
    }()
    /// Measures the real time between ticks; a box, so updating it never redraws the view.
    @State private var clock = TickClockBox()
    /// The last mode the sound answered (a box: updating it never redraws the view).
    @State private var heard = HeardMode()
    /// The phone's flashlight: where, and when it last moved (it goes out 3 s after the finger stops).
    @State private var flashlight: (point: Point<ArtworkSpace>, at: Double)?
    private static let cues: SoundCues? = {
        guard case let .success(c) = content else { return nil }
        return SoundCues(library: c.library)
    }()
    /// When the wall started breathing, so glints can follow the breath.
    @State private var alive = AliveClock()

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
                            session: Binding(get: { calSession ?? CalibrationSession(start: startingCalibration(for: screen)) },
                                             set: { calSession = $0 }),
                            screen: geo.size,
                            canCancel: store.saved != nil,
                            onFinish: { finishCalibration($0) },
                            outlines: Self.outlines,
                            instructionsZone: Self.instructionsZone)
                    } else if let cal = store.saved {
                        artwork(cal, screen: geo.size)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onGeometryChange(for: CGSize.self) { $0.size } action: { screenSize = PixelSize(width: $0.width, height: $0.height) }
        .onAppear {
            if machine == nil {
                machine = ModeMachine(calibrated: store.saved != nil, now: Self.now, intro: !Self.skipIntro)
            }
            companion.onCommand = { handlePhone($0) }
            companion.start()
        }
        // Every phone sees what the wall shows, and the settings it can change, as they change.
        .onChange(of: snapshot) { _, s in if let s { companion.broadcast(s) } }
        // Four ticks a second drive timed modes (intro, Unfold, hints, idle).
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(250))
                tick()
            }
        }
        // Waking the Apple TV (or dismissing its screensaver) is use, even though the press
        // never reaches the app: hold the screensaver off again for the next 6 hours.
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { machine?.noteActivity(now: Self.now); updateIdleTimer(); sound.resume(); companion.start() }
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
                    let day = dayLight, season = seasons
                    // The light warms and dims with the day (DayLight); the wash takes the church year's tint.
                    ZStack(alignment: .topLeading) {
                        LightLayer(library: content.library, tuning: wallTuning,
                                   targets: lightTargets(mode, content), exploring: mode.dimsWash(script: content.script, context: content.context),
                                   dark: mode.isIntro, washColor: season.map { Self.washColor($0.tint) } ?? Palette.ivory)
                        AliveLayer(library: content.library, breathing: content.breathing, tuning: wallTuning,
                                   active: Breathing.isActive(mode) && windDown != .sleeping, clock: alive, demoSince: machine?.demoSince)
                    }
                    .colorMultiply(Color(red: 1, green: 1 - 0.22 * day.warmth, blue: 1 - 0.45 * day.warmth))
                    .opacity(day.level)
                    .animation(.easeInOut(duration: 20), value: day)
                    DelightsLayer(library: content.library, delights: content.delights,
                                  seasons: mode.isIntro || mode == .calibrating ? nil : season,
                                  atRest: mode == .stillness && windDown != .sleeping,
                                  zone: CanvasText.instructionsZone(library: content.library, zones: content.zones),
                                  dreamcoat: machine?.dreamcoat(now: Self.now) ?? false,
                                  flashlight: flashlight?.point,
                                  moment: currentMoment,
                                  reveal: revealSeconds(mode, content))
                    if machine?.isSlowLooking == true, let since = machine?.slowLookingSince, Self.now - since < 9 {
                        WallColumn(placement: TextColumnLayout.place(preferred: .left, calibration: cal,
                                                                     canvasZone: CanvasText.readingZone(library: content.library, zones: content.zones)),
                                   anchorY: 0) {
                            Wayfinding.hint("Seven minutes of slow looking.\nBreathe with the light. Any button ends it.")
                        }
                        .transition(.opacity.animation(.easeInOut(duration: 2)))
                    }
                    switch mode {
                    case let .intro(startedAt):
                        IntroView(library: content.library, tuning: wallTuning, startedAt: startedAt)
                            .transition(.opacity.animation(.easeOut(duration: 1.0)))
                    case .stillness:
                        GlintLayer(points: content.glints, tuning: wallTuning, calibration: cal,
                                   demo: UserDefaults.standard.bool(forKey: "glintDemo"), bias: glintBias(content))
                    case let .menu(focus):
                        GlintLayer(points: content.glints, tuning: wallTuning, calibration: cal,
                                   demo: UserDefaults.standard.bool(forKey: "glintDemo"))
                        MenuView(focus: focus, calibration: cal, soundOn: soundOn, soundAvailable: sound.available,
                                 canvasZone: CanvasText.readingZone(library: content.library, zones: content.zones))
                            .transition(.opacity.animation(.easeInOut(duration: LightTiming.textOut)))
                    case let .explore(id, expanded):
                        ExploreView(library: content.library, state: .exploring(id: id, expanded: expanded),
                                    calibration: cal, showsHint: machine?.hintUntil != nil,
                                    edgeLine: wallTuning.edgeLine,
                                    canvasZone: CanvasText.zone(for: id, library: content.library, zones: content.zones),
                                    textHidden: machine?.textHidden ?? false)
                    case let .unfold(p):
                        UnfoldView(script: content.script, playback: p, library: content.library, calibration: cal,
                                   header: mode.wayfinding(library: content.library, script: content.script),
                                   showsHint: machine?.hintUntil != nil,
                                   canvasZone: CanvasText.readingZone(library: content.library, zones: content.zones))
                    case let .context(page):
                        ContextView(script: content.context, maps: content.maps, page: page, calibration: cal,
                                    header: mode.wayfinding(library: content.library, script: content.script,
                                                            context: content.context),
                                    showsHint: machine?.hintUntil != nil,
                                    canvasZone: CanvasText.readingZone(library: content.library, zones: content.zones))
                    case .pattern:
                        RegistrationTestPattern()
                    case .tuning:
                        GlintLayer(points: content.glints, tuning: wallTuning, calibration: cal, demo: true,
                                   bias: glintBias(content))
                        // Show the edge line on Christ while tuning it (and everything else).
                        if let christ = content.library.annotations.first(where: { $0.id == "christ" }) {
                            EdgeLineView(annotation: christ, strength: wallTuning.edgeLine)
                        }
                        SettingsView(mode: mode, tuning: tuningSession, notices: content.notices, showPainting: showPainting)
                    case .settings, .about:
                        SettingsView(mode: mode, tuning: nil, notices: content.notices, showPainting: showPainting,
                                     credits: ["Maps: " + content.maps.source] + content.context.imageCredits)
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
            // Select: click and hold-for-a-second, read from the button alone (SelectPressDetector).
            .background(SelectPressDetector(
                onClick: {
                    if mode == .tuning { tuningSession?.select(); applyTuning() }
                    send(.select, content)   // in tuning this only records the press
                },
                onHold: { send(.holdSelect, content) }))
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

    private var snapshot: WallSnapshot? {
        guard let m = machine, case let .success(c) = Self.content else { return nil }
        var s = WallSnapshot.make(mode: m.mode, library: c.library, script: c.script, context: c.context,
                                  tuning: tuningStore.tuning, soundOn: soundOn, showPainting: showPainting,
                                  textHidden: m.textHidden)
        if m.mode == .calibrating {
            s.alignment = (calSession ?? CalibrationSession(start: store.saved ?? startingCalibration(for: screenSize))).alignmentState
        }
        return s
    }

    private func finishCalibration(_ outcome: CalibrationSession.Outcome) {
        var saved = false
        if case let .save(cal) = outcome { store.save(cal); saved = true }
        calSession = nil
        machine?.finishCalibration(now: Self.now, playIntro: saved && !Self.skipIntro)
    }

    /// The phone's Align screen drives the same session as the remote.
    private func handleAlign(_ command: AlignCommand) {
        if command == .start {
            guard store.saved != nil else { return }   // first setup stays on the remote
            // Start from what is on the wall now: the saved calibration.
            calSession = CalibrationSession(start: store.saved ?? startingCalibration(for: screenSize))
            machine?.beginCalibration()
            return
        }
        guard machine?.mode == .calibrating else { return }
        var session = calSession ?? CalibrationSession(start: store.saved ?? startingCalibration(for: screenSize))
        switch command {
        case let .pick(p): session.handle(.pick(p))
        case let .move(d): session.handle(.move(d))
        case let .place(p, at): session.handle(.place(p, at))
        case .toggleFine: session.handle(.playPause)
        case let .trim(edge, steps): session.handle(.trim(edge, steps))
        case .save: finishCalibration(.save(session.calibration)); return
        case .cancel:
            if store.saved != nil { finishCalibration(.cancel) }
            return
        case .start: break
        }
        calSession = session
    }

    private func handlePhone(_ command: PhoneCommand) {
        guard case let .success(c) = Self.content else { return }
        switch command {
        case .hello:
            if let s = snapshot { companion.broadcast(s) }
        case let .setTuning(t):
            tuningStore.tuning = t.clamped
        case let .setSound(on):
            soundOn = on
        case let .setShowPainting(on):
            showPainting = on
        case let .setTextHidden(hidden):
            machine?.setTextHidden(hidden)
        case let .flashlight(point):
            flashlight = point.map { (point: $0, at: Self.now) }
            machine?.noteActivity(now: Self.now)
        case let .align(a):
            handleAlign(a)
        case let .demo(on):
            if on, store.saved != nil { machine?.startDemo(now: Self.now) }
            else if !on, machine?.isDemo == true { send(.back, c) }
        default:
            if let input = command.input { send(input, c) }
        }
    }

    /// Glints lean toward regions near the top of their breath, while breathing is on.
    private func glintBias(_ c: AppContent) -> ((Point<ArtworkSpace>, Double) -> Double)? {
        guard tuningStore.tuning.breathing > 0 else { return nil }
        let clock = alive, library = c.library, breathing = c.breathing
        return { p, t in
            guard let since = clock.since else { return 1 }
            return breathing.glintWeight(regionId: FigureHitTest.figure(at: p, in: library), at: t, since: since)
        }
    }

    /// What the wall uses: the saved tuning, except during the demo, which makes sure glints and
    /// sun rays actually appear on film.
    private var wallTuning: Tuning {
        var t = tuningStore.tuning
        if machine?.isDemo == true {
            t.passingLight = true
            t.glintMeanInterval = 4
            t.breathing = max(t.breathing, 0.12)
        } else if windDown != .awake, machine?.isSlowLooking != true {
            // Late evening: breathing only, no glints or sun rays.
            t.passingLight = false
            t.glintMeanInterval = 1_000_000
        }
        return t
    }

    // MARK: Seasons, the day, wind-down, moments (docs/superpowers/plans/2026-11-16-delights.md)

    /// Preview any date in the simulator: `-previewDate 2026-12-24T19:00`.
    private static let previewOffset: TimeInterval = {
        guard let s = UserDefaults.standard.string(forKey: "previewDate") else { return 0 }
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd'T'HH:mm"; f.timeZone = .current
        return f.date(from: s).map { $0.timeIntervalSinceNow } ?? 0
    }()
    private var wallDate: Date { Date().addingTimeInterval(Self.previewOffset) }
    private var seasons: SeasonEffects? { tuningStore.tuning.seasons ? Seasons.effects(at: wallDate) : nil }
    private var dayLight: DayLight { tuningStore.tuning.followDay ? DayLight.at(wallDate, place: .home) : .neutral }
    private var windDown: WindDown.Phase {
        machine?.isDemo == true ? .awake : WindDown().phase(at: wallDate)
    }
    private var currentMoment: (kind: Moment.Kind, progress: Double)? {
        guard let m = Moments.active(at: wallDate) else { return nil }
        let start = Calendar.current.startOfDay(for: wallDate).addingTimeInterval(Double(m.minute * 60))
        return (m.kind, wallDate.timeIntervalSince(start) / Moment.duration)
    }
    static func washColor(_ tint: LiturgicalTint) -> Color {
        let c = tint.rgb, k = 0.35   // a faint tint over ivory
        return Color(red: 1 - k * (1 - c.r), green: 0.97 - k * (0.97 - c.g), blue: 0.9 - k * (0.9 - c.b))
    }
    /// The restoration page reveals the angels it is about.
    private func revealSeconds(_ mode: Mode, _ c: AppContent) -> Double? {
        guard case let .context(page) = mode, c.context.pages.indices.contains(page),
              c.context.pages[page].id == "angels", let since = heard.contextSince else { return nil }
        return Self.now - since
    }

    private func applyTuning() {
        if let t = tuningSession?.tuning, t != tuningStore.tuning { tuningStore.tuning = t }
    }

    private func tick() {
        guard var m = machine, case let .success(c) = Self.content else { return }
        let now = Self.now
        let dt = clock.value.dt(now: now)
        m.tick(now: now, dt: dt, script: c.script, context: c.context)
        let breath = alive.since.map { SoundCues.swell(breathing: c.breathing, at: now, since: $0) } ?? 0.5
        let quiet = windDown == .sleeping ? 0.0 : windDown == .settling ? 0.5 : 1.0   // wind-down hushes the sound too
        sound.update(target: Soundscape.target(mode: m.mode, on: soundOn) * quiet, dt: dt, breath: breath)
        // A new figure, Unfold beat or Context page rings the bowl at its own note.
        if let last = heard.mode, let cue = Self.cues?.cue(from: last, to: m.mode, script: c.script) { sound.ring(cue) }
        if heard.mode != m.mode, case .context = m.mode { heard.contextSince = now }
        heard.mode = m.mode
        if let f = flashlight, now - f.at > 3 { flashlight = nil }
        if m != machine { machine = m }
        updateIdleTimer()
    }

    private func updateIdleTimer() {
        guard let m = machine else { return }
        var keep = AwakePolicy.keepAwake(lastInputAt: m.lastInputAt, now: Self.now)
        // Wind-down: late at night, ten minutes after the last press, the Apple TV may sleep.
        if windDown == .sleeping, Self.now - m.lastInputAt > 600 { keep = false }
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

/// What the sound last answered, so a change of figure rings once.
final class HeardMode {
    var mode: Mode?
    /// When the current Context page appeared (for the restoration reveal).
    var contextSince: Double?
}
