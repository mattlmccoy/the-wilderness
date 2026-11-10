import SwiftUI
import WildernessCore

/// Remote map
///   Dark wall:  arrows → Explore (Christ lit) · Play/Pause → registration pattern
///               hold Select (1 s) → calibration · Menu → leave the app
///   Explore:    arrows → move between details by position · Select → longer text · Menu → dark
///   Calibrate:  see CalibrationView (Select through the corners, Select again to save; ‹ cancels)
struct RootView: View {
    @StateObject private var store = CalibrationStore()
    @State private var calibrating = false
    @State private var showPattern = false
    @State private var explore = ExploreState.idle
    private let content = ContentLoader.load()

    var body: some View {
        GeometryReader { geo in
            let screen = PixelSize(width: geo.size.width, height: geo.size.height)
            ZStack {
                Color.black
                if calibrating || store.saved == nil {
                    CalibrationView(
                        start: startingCalibration(for: screen),
                        screen: geo.size,
                        canCancel: store.saved != nil,
                        onFinish: { outcome in
                            if case let .save(cal) = outcome { store.save(cal) }
                            calibrating = false
                        })
                } else if let cal = store.saved {
                    artwork(cal, screen: geo.size)
                }
            }
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func artwork(_ cal: Calibration, screen: CGSize) -> some View {
        switch content {
        case let .failure(error):
            // Visible and distinct: never a silent dark wall that looks like "working".
            Text("Content failed to load: \(String(describing: error))")
                .font(.system(size: 18)).foregroundStyle(Palette.gold)
        case let .success(content):
            let library = content.library
            MappedCanvas(calibration: cal, screen: screen) {
                ZStack(alignment: .topLeading) {
                    RegistrationTestPattern(strength: showPattern ? 1 : 0)
                        .animation(.easeInOut(duration: 1.2), value: showPattern)
                    ExploreView(library: library, state: explore)
                    if explore == .idle {
                        GlintLayer(points: content.glints, tuning: .defaults, calibration: cal,
                                   demo: UserDefaults.standard.bool(forKey: "glintDemo"))
                    }
                }
            }
            .focusable()
            .onMoveCommand { direction in
                explore.handle(.move(direction.nudge), library: library)
            }
            .onTapGesture { explore.handle(.select, library: library) }
            .onLongPressGesture(minimumDuration: 1.0) { explore = .idle; calibrating = true }
            .onPlayPauseCommand { showPattern.toggle() }
            // On a dark wall, pass Menu through so tvOS returns to the home screen.
            .onExitCommand(perform: explore == .idle ? nil : { explore.handle(.back, library: library) })
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
