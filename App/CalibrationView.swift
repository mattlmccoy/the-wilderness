import SwiftUI
import WildernessCore

/// Four-corner calibration with the Siri Remote. The flow itself lives in `CalibrationSession`:
///   Arrows → move the corner · Select → next corner, then review · Select on review → save
///   ‹ Back → on review, keep adjusting; otherwise cancel · Play/Pause → fine / coarse
/// The registration pattern is drawn *through* the live mapping, so what you see on the
/// wall while adjusting is exactly what the saved calibration will produce.
struct CalibrationView: View {
    let screen: CGSize
    /// False on first setup: there is nothing to return to, so Back leaves the app as tvOS expects.
    let canCancel: Bool
    let onFinish: (CalibrationSession.Outcome) -> Void
    @State private var session: CalibrationSession

    init(start: Calibration, screen: CGSize, canCancel: Bool,
         onFinish: @escaping (CalibrationSession.Outcome) -> Void) {
        self.screen = screen
        self.canCancel = canCancel
        self.onFinish = onFinish
        _session = State(initialValue: CalibrationSession(start: start))
    }

    private var reviewing: Bool { session.phase == .review }

    var body: some View {
        ZStack(alignment: .topLeading) {
            MappedCanvas(calibration: session.calibration, screen: screen) {
                RegistrationTestPattern()
            }
            if !reviewing {
                ForEach(Corner.allCases, id: \.self) { corner in handle(for: corner) }
            }
            // Kept inside the TV title-safe margin (about 60 pt at 1080p) so it never falls off the wall.
            instructions
                .padding(.bottom, 60)
                .frame(width: screen.width, height: screen.height, alignment: .bottom)
        }
        .frame(width: screen.width, height: screen.height, alignment: .topLeading)
        .focusable()
        .onMoveCommand { direction in send(.move(direction.nudge)) }
        .onTapGesture { withAnimation(.easeOut(duration: 0.25)) { send(.select) } }
        .onPlayPauseCommand { send(.playPause) }
        // Back must reach the system on first setup (to leave the app), except on review.
        .onExitCommand(perform: (reviewing || canCancel) ? { send(.back) } : nil)
    }

    private func send(_ input: CalibrationSession.Input) {
        if let outcome = session.handle(input) { onFinish(outcome) }
    }

    private func handle(for corner: Corner) -> some View {
        let p = session.calibration.corners[corner.rawValue]
        let selected = session.phase == .corner(corner)
        return ZStack {
            Circle().stroke(selected ? Palette.gold : Palette.stone.opacity(0.5), lineWidth: selected ? 2.5 : 1.5)
                .frame(width: selected ? 34 : 18, height: selected ? 34 : 18)
            Circle().fill(selected ? Palette.gold : Palette.stone.opacity(0.5)).frame(width: 4, height: 4)
        }
        .position(x: p.x * screen.width, y: p.y * screen.height)
    }

    private var hints: String {
        if reviewing { return "SELECT  save   ·   ‹  keep adjusting" }
        let step = session.step == .fine ? "fine" : "coarse"
        return "ARROWS  move   ·   SELECT  next   ·   ▶︎❙❙  \(step)   ·   ‹  \(canCancel ? "cancel" : "exit")"
    }

    private var instructions: some View {
        VStack(spacing: 10) {
            Text(session.stepLabel).font(.system(size: 22, weight: .regular, design: .serif))
            Text(hints).font(.system(size: 15, weight: .medium)).tracking(1.5)
        }
        .foregroundStyle(Palette.ivory.opacity(0.55))
    }
}
