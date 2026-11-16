import SwiftUI
import WildernessCore

/// The companion's one screen: the painting (tap a figure), what the wall says (read along),
/// and the few controls. Settings sit behind the gear. Same black, Garamond and gold as the wall.
struct PhoneRootView: View {
    @StateObject private var client = CompanionClient()
    @State private var showSettings = false
    @State private var showPrayer = false
    @State private var notConnected = false
    /// Flashlight mode: drag on the painting to move a pool of light on the wall.
    @State private var torch = false
    @State private var lastTorch = Date.distantPast
    let library: AnnotationLibrary?

    var body: some View {
        VStack(spacing: 0) {
            header
            statusLine
            PaintingView(library: library, selected: client.snapshot?.subjectId,
                         onTap: { id in client.send(.go(.explore(id))) },
                         onTorch: torch ? { p in
                             // About 20 updates a second while the finger moves; always the last one.
                             if p == nil || Date().timeIntervalSince(lastTorch) > 0.05 { client.send(.flashlight(p)); lastTorch = Date() }
                         } : nil)
            .padding(.horizontal, 12)
            .opacity(client.link == .connected ? 1 : 0.5)
            ReadAlongView(snapshot: client.snapshot, link: client.link)
                // Swipe like turning a page: left for next, right for previous.
                .gesture(DragGesture(minimumDistance: 30).onEnded { g in
                    guard client.snapshot?.canStep == true,
                          abs(g.translation.width) > abs(g.translation.height) * 1.5 else { return }
                    client.send(.move(g.translation.width < 0 ? .right : .left))
                })
            controls
        }
        .background(Color.black.ignoresSafeArea())
        .foregroundStyle(PhonePalette.ivory)
        .buttonStyle(PressStyle())
        // Every press is felt; a press that cannot reach the wall says so.
        .sensoryFeedback(.impact(weight: .light), trigger: client.sentCount)
        .sensoryFeedback(.error, trigger: client.refusedCount)
        .overlay(alignment: .bottom) {
            if notConnected {
                Text(client.link == .searching ? "Looking for the wall…" : "Not connected to the wall")
                    .font(PhoneType.text(16)).padding(.horizontal, 18).padding(.vertical, 10)
                    .background(Capsule().fill(PhonePalette.stone.opacity(0.35)))
                    .padding(.bottom, 120)   // just above the controls, clear of the painting and text
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .onChange(of: client.refusedCount) {
            withAnimation(.easeOut(duration: 0.25)) { notConnected = true }
            Task { try? await Task.sleep(for: .seconds(2.2)); withAnimation(.easeIn(duration: 0.4)) { notConnected = false } }
        }
        .onAppear { client.start(); deliverIntent() }
        // Siri / Shortcuts: act as soon as the wall is connected.
        .onReceive(NotificationCenter.default.publisher(for: IntentInbox.arrived)) { _ in deliverIntent() }
        .onChange(of: client.link) { deliverIntent() }
        .fullScreenCover(isPresented: $showPrayer) { PrayerView(client: client) }
        // A session started from another phone (or still running) opens the dark screen here too.
        .onChange(of: client.snapshot?.prayer != nil) { _, running in if running { showPrayer = true } }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(client: client)
                .presentationDetents([.medium, .large])
        }
    }

    private func deliverIntent() {
        guard client.link == .connected, let r = IntentInbox.shared.pending else { return }
        IntentInbox.shared.pending = nil
        switch r {
        case .demo: client.send(.demo(true))
        case .lightOnly: client.send(.setTextHidden(true))
        case .flashlight: torch = true
        }
    }

    private var header: some View {
        HStack {
            Text("The Wilderness").font(PhoneType.title(26))
                // Easter egg: hold the title for the dreamcoat (hold again to end it).
                .onLongPressGesture(minimumDuration: 1.0) { client.send(.dreamcoat(client.snapshot?.dreamcoat != true)) }
            Spacer()
            // Pulses each time the wall answers, so you can see it heard you.
            Circle().fill(client.link == .connected ? PhonePalette.gold : PhonePalette.stone)
                .frame(width: 8, height: 8)
                .phaseAnimator([1.0, 1.9, 1.0], trigger: client.heardCount) { dot, scale in dot.scaleEffect(scale) }
                    animation: { _ in .easeOut(duration: 0.18) }
                .accessibilityLabel(client.link == .connected ? "Connected" : "Not connected")
            // Into the Quiet: a prayer session, started here (the wall has no button for it).
            Button { showPrayer = true } label: { Image(systemName: "hands.and.sparkles") }
                .disabled(client.link != .connected)
                .accessibilityLabel("Into the quiet")
            Button { showSettings = true } label: { Image(systemName: "gearshape") }
                .disabled(client.link != .connected)
                .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    /// What the wall is doing now, mirrored: the mode, and anything running (Be still, the
    /// dreamcoat, the demo, the seasons).
    private var statusLine: some View {
        let s = client.snapshot
        let parts = client.link == .connected ? [Self.modeName(s)] + (s?.status ?? []) : []
        return Text(parts.compactMap { $0 }.joined(separator: "  ·  "))
            .font(PhoneType.text(14)).tracking(1)
            .foregroundStyle(PhonePalette.gold.opacity(0.9))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.bottom, 8)
            .lineLimit(2)
            .animation(.easeInOut(duration: 0.3), value: parts)
            .accessibilityLabel("The wall: " + parts.compactMap { $0 }.joined(separator: ", "))
    }

    static func modeName(_ s: WallSnapshot?) -> String? {
        guard let s else { return nil }
        if s.still != nil { return nil }   // "Be still · n of m" says it
        switch s.mode {
        case "rest": return "At rest"
        case "menu": return "Menu"
        case "intro": return "Starting"
        case "explore": return s.title.map { "Exploring: \($0)" } ?? "Exploring"
        case "unfold": return s.paused ? "Unfold, paused" : "Unfold"
        case "context": return "Context"
        case "calibrating": return "Aligning"
        default: return "Settings"
        }
    }

    /// The wall's modes, the running one lit gold; a lit one ends it. (The dreamcoat is an Easter
    /// egg, not a mode: a long press on the title, like the code on the remote.)
    private var modeRow: some View {
        let s = client.snapshot
        let still = s?.still != nil
        return HStack(spacing: 0) {
            modeButton("Explore", on: s?.mode == "explore" && !still) { client.send(.go(.exploreStart)) }
            Spacer(minLength: 2)
            modeButton("Unfold", on: s?.mode == "unfold" && !still) { client.send(.go(.unfold)) }
            Spacer(minLength: 2)
            modeButton("Context", on: s?.mode == "context") { client.send(.go(.context)) }
            Spacer(minLength: 2)
            modeButton("Be still", on: still) { client.send(.beStill(!still)) }
        }
        .font(PhoneType.text(17))
        .padding(.horizontal, 10).padding(.top, 6)
        .opacity(client.link == .connected ? 1 : 0.55)
    }

    private func modeButton(_ title: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).lineLimit(1).fixedSize()
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(Capsule().stroke(PhonePalette.gold.opacity(on ? 0.9 : 0), lineWidth: 1))
        }
        .foregroundStyle(on ? PhonePalette.gold : PhonePalette.ivory)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var controls: some View {
        VStack(spacing: 0) {
        modeRow
        HStack(spacing: 18) {
            Spacer()
            if client.snapshot?.canStep == true {
                Button { client.send(.move(.left)) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Previous")
                Button { client.send(.move(.right)) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel("Next")
            }
            if client.snapshot?.mode == "explore" {
                let hidden = client.snapshot?.textHidden ?? false
                Button { client.send(.setTextHidden(!hidden)) } label: { Image(systemName: hidden ? "eye.slash" : "eye") }
                    .accessibilityLabel(hidden ? "Show text on the wall" : "Hide text on the wall")
            }
            if client.snapshot?.canPause == true {
                Button { client.send(.playPause) } label: {
                    Image(systemName: client.snapshot?.paused == true ? "play" : "pause")
                }
                .accessibilityLabel(client.snapshot?.paused == true ? "Resume" : "Pause")
            }
            Button { torch.toggle(); if !torch { client.send(.flashlight(nil)) } } label: {
                Image(systemName: torch ? "flashlight.on.fill" : "flashlight.off.fill")
            }
            .foregroundStyle(torch ? PhonePalette.gold : PhonePalette.ivory)
            .accessibilityLabel(torch ? "Flashlight on: drag on the painting" : "Flashlight")
            Button { client.send(.back) } label: { Image(systemName: "arrow.uturn.backward") }
                .accessibilityLabel("Back")
        }
        .font(PhoneType.text(19))
        .tint(PhonePalette.gold)
        .padding(.horizontal, 20).padding(.vertical, 12)
        // Never disabled: a press while disconnected answers with a message and a buzz instead of nothing.
        .opacity(client.link == .connected ? 1 : 0.55)
        }
    }
}

/// The painting with Matt's traced outlines; a tap goes to the figure under the finger.
struct PaintingView: View {
    let library: AnnotationLibrary?
    let selected: String?
    let onTap: (String) -> Void
    /// Flashlight: while set, a finger on the painting moves a pool of light on the wall
    /// (nil when the finger lifts) instead of choosing a figure.
    var onTorch: ((Point<ArtworkSpace>?) -> Void)? = nil
    @State private var finger: CGPoint?
    private static let image = UIImage(named: "painting.jpg")

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                if let img = Self.image { Image(uiImage: img).resizable() }
                Canvas { ctx, size in
                    for a in library?.annotations ?? [] {
                        guard let o = a.outline, o.count >= 3 else { continue }
                        var p = Path()
                        p.addLines(o.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) })
                        p.closeSubpath()
                        let on = a.id == selected
                        ctx.stroke(p, with: .color(PhonePalette.gold.opacity(on ? 0.95 : 0.35)), lineWidth: on ? 2 : 1)
                    }
                }
            }
            .overlay {
                if onTorch != nil, let f = finger {
                    Circle().fill(RadialGradient(colors: [PhonePalette.ivory.opacity(0.55), .clear], center: .center, startRadius: 0, endRadius: 40))
                        .frame(width: 80, height: 80).position(f).allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .gesture(onTorch == nil ? nil : DragGesture(minimumDistance: 0)
                .onChanged { g in
                    let at = CGPoint(x: min(max(g.location.x, 0), size.width), y: min(max(g.location.y, 0), size.height))
                    finger = at
                    onTorch?(Point(x: at.x / size.width, y: at.y / size.height))
                }
                .onEnded { _ in finger = nil; onTorch?(nil) })
            .onTapGesture { at in
                guard onTorch == nil, let library else { return }
                let pt = Point<ArtworkSpace>(x: at.x / size.width, y: at.y / size.height)
                if let id = FigureHitTest.figure(at: pt, in: library) { onTap(id) }
            }
        }
        .aspectRatio(60.0 / 50.0, contentMode: .fit)
        .accessibilityLabel("The painting. Tap a figure to show it on the wall.")
    }
}

/// What the wall is showing, larger: wayfinding, title, short line, story, verses.
struct ReadAlongView: View {
    let snapshot: WallSnapshot?
    let link: CompanionClient.Link

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if link != .connected {
                    Text(link == .connecting ? "Connecting…" : "Looking for The Wilderness…")
                        .font(PhoneType.title(24))
                    Text("Open the app on the Apple TV, and keep this phone on the same Wi-Fi.")
                        .font(PhoneType.text(17, italic: true)).foregroundStyle(PhonePalette.stone)
                } else if let s = snapshot, let title = s.title {
                    if let h = s.header { Text(h).font(PhoneType.text(13)).tracking(2).foregroundStyle(PhonePalette.stone) }
                    Text(title).font(PhoneType.title(30))
                    if let short = s.short { Text(short).font(PhoneType.text(20, italic: true)) }
                    if let story = s.story { Text(story).font(PhoneType.text(18)).lineSpacing(4) }
                    ForEach(Array(s.verses.enumerated()), id: \.offset) { _, v in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(v.text).font(PhoneType.text(18)).lineSpacing(3)
                            Text(v.citation).font(PhoneType.text(13)).tracking(1).foregroundStyle(PhonePalette.stone)
                        }
                    }
                    if s.paused { Text("Paused").font(PhoneType.text(13)).tracking(1).foregroundStyle(PhonePalette.stone) }
                } else {
                    Text(restLine(snapshot?.mode)).font(PhoneType.text(18, italic: true)).foregroundStyle(PhonePalette.stone)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
    }

    private func restLine(_ mode: String?) -> String {
        switch mode {
        case "intro": "The outlines are drawing on the wall."
        case "menu": "The menu is open on the wall."
        case "settings", "calibrating": "The wall is in its settings."
        default: "The wall is at rest. Tap a figure to begin."
        }
    }
}

/// Live settings: each change is sent to the Apple TV, which saves it and shows it at once.
struct SettingsSheet: View {
    @ObservedObject var client: CompanionClient
    @State private var tuning = Tuning.defaults
    @State private var loaded = false
    @State private var aligning = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Light") {
                    slider("Light on figures", \.subjectStrength, 0...1)
                    slider("Edge line", \.edgeLine, 0...1)
                    slider("Background wash", \.baseWash, 0...0.5)
                }
                Section("At rest") {
                    slider("Breathing", \.breathing, 0...0.3)
                    slider("Drifting light", \.drift, 0...1)
                    Toggle("Passing light", isOn: Binding(get: { tuning.passingLight },
                                                          set: { tuning.passingLight = $0; client.send(.setTuning(tuning)) }))
                }
                Section("Glints") {
                    Picker("How often", selection: Binding(get: { tuning.glintMeanInterval },
                                                           set: { tuning.glintMeanInterval = $0; client.send(.setTuning(tuning)) })) {
                        Text("Rare").tag(16.0); Text("Now and then").tag(8.0); Text("Often").tag(4.0)
                    }
                    .pickerStyle(.segmented)
                    slider("Brightness", \.glintBrightness, 0.2...1)
                    slider("Size", \.glintSizeInches, 0.05...0.6)
                    Picker("Style", selection: Binding(get: { tuning.glintStyle },
                                                       set: { tuning.glintStyle = $0; client.send(.setTuning(tuning)) })) {
                        Text("Along a thread").tag(GlintStyle.thread); Text("Pinpoint").tag(GlintStyle.pinpoint)
                    }
                }
                Section {
                    Toggle("Sound", isOn: Binding(get: { client.snapshot?.soundOn ?? false },
                                                  set: { client.send(.setSound($0)) }))
                    Toggle("Show painting", isOn: Binding(get: { client.snapshot?.showPainting ?? false },
                                                          set: { client.send(.setShowPainting($0)) }))
                }
                Section("Through the year") {
                    Toggle("Seasons", isOn: Binding(get: { tuning.seasons }, set: { tuning.seasons = $0; client.send(.setTuning(tuning)) }))
                    Toggle("Light follows the day", isOn: Binding(get: { tuning.followDay }, set: { tuning.followDay = $0; client.send(.setTuning(tuning)) }))
                }
                Section(header: Text("Each season"),
                        footer: Text("Auto follows the calendar. On shows it any day; Off hides it. Thanksgiving's turkey runs every 90 seconds when On.")) {
                    ForEach(SeasonMode.allCases, id: \.self) { m in
                        Picker(m.title, selection: Binding(get: { tuning.switchFor(m) },
                                                           set: { tuning.setSwitch(m, $0); client.send(.setTuning(tuning)) })) {
                            Text("Auto").tag(SeasonSwitch.auto); Text("On").tag(SeasonSwitch.on); Text("Off").tag(SeasonSwitch.off)
                        }
                    }
                }
                Section(footer: Text("The pattern and About show on the wall; Back on the phone or the remote closes them.")) {
                    Button("Align to the tapestry…") { aligning = true }
                    Button("Show the alignment pattern") { client.send(.show(.pattern)) }
                    Button("Show About on the wall") { client.send(.show(.about)) }
                }
                Section(footer: Text("Plays every feature in a three-minute loop, for filming. Any press on the remote ends it.")) {
                    Button("Start the demo") { client.send(.demo(true)) }
                    Button("Stop the demo") { client.send(.demo(false)) }
                }
                Section { Button("Reset light to defaults") { tuning = .defaults; client.send(.setTuning(tuning)) } }
            }
            .navigationTitle("Settings")
            .fullScreenCover(isPresented: $aligning) { AlignView(client: client) }
            .navigationBarTitleDisplayMode(.inline)
        }
        .sensoryFeedback(.selection, trigger: client.sentCount)
        .sensoryFeedback(.error, trigger: client.refusedCount)
        // Always edit the wall's real values (never defaults), and follow changes made on the wall.
        .disabled(client.snapshot == nil)
        .onAppear { if let t = client.snapshot?.tuning { tuning = t; loaded = true } }
        .onChange(of: client.snapshot?.tuning) { _, t in if let t { tuning = t; loaded = true } }
        .tint(PhonePalette.gold)
    }

    private func slider(_ label: String, _ key: WritableKeyPath<Tuning, Double>, _ range: ClosedRange<Double>) -> some View {
        VStack(alignment: .leading) {
            HStack { Text(label); Spacer(); Text("\(Int(tuning[keyPath: key] / range.upperBound * 100))%").foregroundStyle(.secondary) }
            Slider(value: Binding(get: { tuning[keyPath: key] },
                                  set: { tuning[keyPath: key] = $0; client.send(.setTuning(tuning)) }),
                   in: range)
        }
    }
}

/// Every control visibly answers the finger: it dips and glows gold while pressed.
struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(6)
            .background(Capsule().fill(PhonePalette.gold.opacity(configuration.isPressed ? 0.25 : 0)).padding(-4))
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
