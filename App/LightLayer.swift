import SwiftUI
import WildernessCore

/// The light the projector adds to the tapestry, in artwork canvas units (spec §4):
/// a faint even wash, plus soft, heavily feathered light on the chosen subjects.
/// Every subject's light is always in the tree; only its opacity changes, so moving between
/// subjects is a cross-fade.
struct LightLayer: View {
    let library: AnnotationLibrary
    let tuning: Tuning
    /// Annotation ids and/or "whole". Empty means Stillness.
    let targets: Set<String>
    /// While exploring, the wash drops so the rest of the tapestry recedes.
    let exploring: Bool
    /// The boot-up intro starts on a dark wall: no wash until it ends.
    var dark = false

    /// Feather of about 2.2 in on the wall (44 canvas units).
    static let featherRadius: CGFloat = 22

    /// Per-subject level, 0…1 (times subjectStrength). An outgoing light animates to
    /// `LightTiming.fadingOut` rather than 0, so a later change can still see it and speed it up
    /// (see `restage`); once its fade has finished it leaves `levels` and is drawn at exactly 0.
    @State private var levels: [String: Double] = [:]
    /// Counts restages, so a finished fade only settles `levels` if no newer change is running.
    @State private var restages = 0
    @State private var shown: Set<String> = []
    @State private var shownExploring = false
    @State private var shownDark = false

    private let canvas = CGSize(width: Artwork.canvasWidth, height: Artwork.canvasHeight)

    var body: some View {
        ZStack(alignment: .topLeading) {
            Rectangle().fill(Palette.ivory).opacity(washOpacity)
            ForEach(library.annotations.filter { $0.outline != nil }) { a in
                SubjectGlow(outline: a.outline!, canvas: canvas)
                    .opacity((levels[a.id] ?? 0) * tuning.subjectStrength)
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .allowsHitTesting(false)
        .onAppear {
            shown = targets; shownExploring = exploring; shownDark = dark
            for id in targets { levels[id] = 1 }
        }
        .onChange(of: targets) { old, new in restage(from: old, to: new) }
        .onChange(of: dark) { _, new in
            withAnimation(.easeInOut(duration: LightTiming.wake)) { shownDark = new }
        }
    }

    /// Fades to the new targets. Lights left from earlier quick presses fade out fast, so only
    /// the outgoing and incoming lights are ever visible together (Review Focus 1).
    private func restage(from old: Set<String>, to new: Set<String>) {
        let visible = Set(levels.filter { $0.value > 0 }.keys)
        let stale = LightTiming.staleLights(visible: visible, old: old, new: new)
        withAnimation(.easeOut(duration: LightTiming.staleFade)) {
            for id in stale { levels[id] = 0 }
        }
        restages += 1
        let generation = restages
        withAnimation(.easeInOut(duration: LightTiming.duration(from: old, to: new))) {
            for id in old.subtracting(new) { levels[id] = LightTiming.fadingOut }
            for id in new { levels[id] = 1 }
            shown = new
            shownExploring = exploring
        } completion: {
            // A newer change owns any light still fading; its own completion settles them.
            guard generation == restages else { return }
            levels = LightTiming.settled(levels)
        }
    }

    private var washOpacity: Double {
        if shownDark { return 0 }
        if shown.contains(UnfoldBeat.wholeTarget) { return tuning.subjectStrength * 0.5 }
        return tuning.baseWash * (shownExploring ? tuning.exploreWashFactor : 1)
    }
}

/// One subject's light: its outline, smoothed and blurred. Drawn once and composited as a
/// single layer so opacity changes don't re-run the blur. Also the intro's faint glow.
struct SubjectGlow: View {
    let outline: [Point<ArtworkSpace>]
    let canvas: CGSize

    var body: some View {
        SmoothOutline(points: outline.map { CGPoint(x: $0.x * canvas.width, y: $0.y * canvas.height) })
            .fill(Palette.ivory)
            .frame(width: canvas.width, height: canvas.height)
            .blur(radius: LightLayer.featherRadius)
            .drawingGroup()
    }
}

/// A closed Catmull-Rom curve through the outline points, so traced polygons read as soft shapes.
struct SmoothOutline: Shape {
    let points: [CGPoint]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let n = points.count
        guard n >= 3 else { return path }
        path.move(to: points[0])
        for i in 0..<n {
            let p0 = points[(i - 1 + n) % n], p1 = points[i], p2 = points[(i + 1) % n], p3 = points[(i + 2) % n]
            let c1 = CGPoint(x: p1.x + (p2.x - p0.x) / 6, y: p1.y + (p2.y - p0.y) / 6)
            let c2 = CGPoint(x: p2.x - (p3.x - p1.x) / 6, y: p2.y - (p3.y - p1.y) / 6)
            path.addCurve(to: p2, control1: c1, control2: c2)
        }
        path.closeSubpath()
        return path
    }
}
