import SwiftUI
import WildernessCore

/// Explore's edge line, in artwork canvas units: the chosen figure's traced outline draws itself,
/// then settles to a quieter line (EdgeLine timing). Same stroke as the boot-up intro, scaled by
/// Tune light → Edge line. Give it a new `.id` per figure so each choice draws afresh.
struct EdgeLineView: View {
    let annotation: Annotation
    /// Tuning.edgeLine, 0…1; 0 draws nothing.
    let strength: Double

    @State private var start = Date()
    @State private var settled = false
    private let path: Path

    init(annotation: Annotation, strength: Double) {
        self.annotation = annotation
        self.strength = strength
        let w = Artwork.canvasWidth, h = Artwork.canvasHeight
        path = annotation.outline.map { o in
            SmoothOutline(points: o.map { CGPoint(x: $0.x * w, y: $0.y * h) }).path(in: .zero)
        } ?? Path()
    }

    var body: some View {
        // Animate only while drawing and settling; afterwards the line is static (no redraws).
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: settled)) { context in
            let f = EdgeLine.frame(at: context.date.timeIntervalSince(start))
            Canvas { ctx, _ in
                guard strength > 0, f.progress > 0 else { return }
                ctx.addFilter(.blur(radius: 1.0))
                let level = f.opacity * strength
                let drawn = path.trimmedPath(from: 0, to: f.progress)
                let line = StrokeStyle(lineWidth: IntroView.lineWidth, lineCap: .round, lineJoin: .round)
                let halo = StrokeStyle(lineWidth: IntroView.lineWidth * 3, lineCap: .round, lineJoin: .round)
                ctx.stroke(drawn, with: .color(Palette.gold.opacity(0.3 * level)), style: halo)
                ctx.stroke(drawn, with: .color(IntroView.lineColor.opacity(0.85 * level)), style: line)
            }
        }
        .frame(width: Artwork.canvasWidth, height: Artwork.canvasHeight)
        .allowsHitTesting(false)
        .onAppear {
            start = Date()
            let total = EdgeLine.delay + EdgeLine.drawSeconds + EdgeLine.settleSeconds + 0.1
            DispatchQueue.main.asyncAfter(deadline: .now() + total) { settled = true }
        }
    }
}
