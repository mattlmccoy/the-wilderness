import SwiftUI
import WildernessCore

/// The companion's one screen: the painting (tap a figure), what the wall says (read along),
/// and the few controls. Settings sit behind the gear. Same black, Garamond and gold as the wall.
struct PhoneRootView: View {
    @StateObject private var client = CompanionClient()
    @State private var showSettings = false
    let library: AnnotationLibrary?

    var body: some View {
        VStack(spacing: 0) {
            header
            PaintingView(library: library, selected: client.snapshot?.subjectId) { id in
                client.send(.go(.explore(id)))
            }
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
        .onAppear { client.start() }
        .sheet(isPresented: $showSettings) {
            SettingsSheet(client: client)
                .presentationDetents([.medium, .large])
        }
    }

    private var header: some View {
        HStack {
            Text("The Wilderness").font(PhoneType.title(26))
            Spacer()
            Circle().fill(client.link == .connected ? PhonePalette.gold : PhonePalette.stone)
                .frame(width: 8, height: 8)
                .accessibilityLabel(client.link == .connected ? "Connected" : "Not connected")
            Button { showSettings = true } label: { Image(systemName: "gearshape") }
                .disabled(client.link != .connected)
                .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private var controls: some View {
        HStack(spacing: 28) {
            Button("Unfold") { client.send(.go(.unfold)) }
            Button("Context") { client.send(.go(.context)) }
            Spacer()
            if client.snapshot?.canStep == true {
                Button { client.send(.move(.left)) } label: { Image(systemName: "chevron.left") }
                    .accessibilityLabel("Previous")
                Button { client.send(.move(.right)) } label: { Image(systemName: "chevron.right") }
                    .accessibilityLabel("Next")
            }
            if client.snapshot?.canPause == true {
                Button { client.send(.playPause) } label: {
                    Image(systemName: client.snapshot?.paused == true ? "play" : "pause")
                }
                .accessibilityLabel(client.snapshot?.paused == true ? "Resume" : "Pause")
            }
            Button { client.send(.back) } label: { Image(systemName: "arrow.uturn.backward") }
                .accessibilityLabel("Back")
        }
        .font(PhoneType.text(19))
        .tint(PhonePalette.gold)
        .padding(.horizontal, 20).padding(.vertical, 14)
        .disabled(client.link != .connected)
    }
}

/// The painting with Matt's traced outlines; a tap goes to the figure under the finger.
struct PaintingView: View {
    let library: AnnotationLibrary?
    let selected: String?
    let onTap: (String) -> Void
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
            .contentShape(Rectangle())
            .onTapGesture { at in
                guard let library else { return }
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
                    Toggle("Passing light", isOn: Binding(get: { tuning.passingLight },
                                                          set: { tuning.passingLight = $0; client.send(.setTuning(tuning)) }))
                }
                Section("Glints") {
                    slider("Brightness", \.glintBrightness, 0.2...1)
                    slider("Size (in)", \.glintSizeInches, 0.02...0.2)
                }
                Section {
                    Toggle("Sound", isOn: Binding(get: { client.snapshot?.soundOn ?? false },
                                                  set: { client.send(.setSound($0)) }))
                    Toggle("Show painting", isOn: Binding(get: { client.snapshot?.showPainting ?? false },
                                                          set: { client.send(.setShowPainting($0)) }))
                }
                Section { Button("Reset light to defaults") { tuning = .defaults; client.send(.setTuning(tuning)) } }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { if !loaded, let t = client.snapshot?.tuning { tuning = t; loaded = true } }
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
