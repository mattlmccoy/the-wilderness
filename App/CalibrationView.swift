import SwiftUI
import WildernessCore

/// Eight-point calibration (4 corners + 4 edge midpoints) with the Siri Remote or the phone. The flow itself lives in `CalibrationSession`:
///   Arrows → move the corner · Select → next corner, then review · Select on review → save
///   ‹ Back → on review, keep adjusting; otherwise cancel · Play/Pause → fine / coarse
/// The registration pattern is drawn *through* the live mapping, so what you see on the
/// wall while adjusting is exactly what the saved calibration will produce.
struct CalibrationView: View {
    /// Owned by RootView so the phone's Align screen can drive the same session.
    @Binding var session: CalibrationSession
    let screen: CGSize
    /// False on first setup: there is nothing to return to, so Back leaves the app as tvOS expects.
    let canCancel: Bool
    let onFinish: (CalibrationSession.Outcome) -> Void
    /// Every traced figure, drawn over the pattern so you can see whether the light meets the print.
    var outlines: [[Point<ArtworkSpace>]] = []


    private var reviewing: Bool { session.phase == .review }

    var body: some View {
        ZStack(alignment: .topLeading) {
            MappedCanvas(calibration: session.calibration, screen: screen, fitsPainting: false) {
                RegistrationTestPattern()
            }
            MappedCanvas(calibration: session.calibration, screen: screen) {
                FigureOutlines(outlines: outlines)
            }
            if !reviewing {
                ForEach(AlignPoint.allCases, id: \.self) { point in handle(for: point) }
            }
            // Kept inside the TV title-safe margin (about 60 pt at 1080p) so it never falls off the wall.
            instructions
                .padding(.bottom, 60)
                .frame(width: screen.width, height: screen.height, alignment: .bottom)
        }
        .frame(width: screen.width, height: screen.height, alignment: .topLeading)
        .focusable()
        .onMoveCommand { direction in send(.move(direction.nudge)) }
        // Clicks from the button alone, so a resting thumb never swallows one (SelectPressDetector).
        .background(SelectPressDetector(onClick: { withAnimation(.easeOut(duration: 0.25)) { send(.select) } }, onHold: {}))
        .onPlayPauseCommand { send(.playPause) }
        // Back must reach the system on first setup (to leave the app), except on review.
        .onExitCommand(perform: (reviewing || canCancel) ? { send(.back) } : nil)
    }

    private func send(_ input: CalibrationSession.Input) {
        if let outcome = session.handle(input) { onFinish(outcome) }
    }

    /// Corners are rings; edge midpoints are small diamonds (they bend an edge, not move a corner).
    private func handle(for point: AlignPoint) -> some View {
        let p = session.calibration.handle(point)
        let selected = session.phase == .point(point)
        let color = selected ? Palette.gold : Palette.stone.opacity(0.5)
        let size: CGFloat = selected ? 34 : 18
        return ZStack {
            if point.edge == nil {
                Circle().stroke(color, lineWidth: selected ? 2.5 : 1.5).frame(width: size, height: size)
            } else {
                Rectangle().stroke(color, lineWidth: selected ? 2.5 : 1.5)
                    .frame(width: size * 0.75, height: size * 0.75).rotationEffect(.degrees(45))
            }
            Circle().fill(color).frame(width: 4, height: 4)
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

/// The traced figures as thin lines, in canvas units: line them up with the printed figures.
struct FigureOutlines: View {
    let outlines: [[Point<ArtworkSpace>]]

    var body: some View {
        Canvas { ctx, size in
            for o in outlines where o.count > 2 {
                var p = Path()
                p.addLines(o.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) })
                p.closeSubpath()
                ctx.stroke(p, with: .color(Palette.gold.opacity(0.8)), lineWidth: 2.5)
            }
        }
        .frame(width: Artwork.canvasWidth, height: Artwork.canvasHeight)
    }
}
