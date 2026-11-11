import SwiftUI
import WildernessCore

/// The boot-up intro, in artwork canvas units: a thin warm line draws itself around Christ,
/// then around the beasts that bow, the peaceable animals and the angels (IntroOrder); each
/// line then softens into a faint glow over its figure, and the glows fade into Stillness.
/// All timing comes from `IntroTimeline`; this view only draws the frame it is given.
/// No text: the wall is meant to be watched, not read.
struct IntroView: View {
    let library: AnnotationLibrary
    let tuning: Tuning
    /// Same clock as ModeMachine (seconds since the reference date).
    let startedAt: Double

    /// Line width of about 0.1 in on the wall: thin, but it must survive the projector.
    static let lineWidth: CGFloat = 2.0
    /// Warm candle tone, about halfway from Palette.ivory toward Palette.gold: white light on
    /// the weave read as harsh in review.
    static let lineColor = Color(red: 0.86, green: 0.78, blue: 0.62)
    /// The faint glow peaks at this fraction of the normal subject light.
    static let glowLevel = 0.5

    private let timeline: IntroTimeline
    private let subjects: [(id: String, outline: [Point<ArtworkSpace>], path: Path)]
    private let canvas = CGSize(width: Artwork.canvasWidth, height: Artwork.canvasHeight)

    init(library: AnnotationLibrary, tuning: Tuning, startedAt: Double) {
        self.library = library
        self.tuning = tuning
        self.startedAt = startedAt
        let groups = IntroOrder.groups(in: library)
        timeline = IntroTimeline(groups: groups)
        let byId = Dictionary(uniqueKeysWithValues: library.annotations.map { ($0.id, $0) })
        let w = Artwork.canvasWidth, h = Artwork.canvasHeight
        subjects = groups.flatMap { $0 }.compactMap { id in
            byId[id]?.outline.map { o in
                (id, o, SmoothOutline(points: o.map { CGPoint(x: $0.x * w, y: $0.y * h) }).path(in: .zero))
            }
        }
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60)) { context in
            let t = context.date.timeIntervalSinceReferenceDate - startedAt
            ZStack(alignment: .topLeading) {
                ForEach(subjects, id: \.id) { s in
                    let glow = timeline.frame(s.id, at: t).glow
                    if glow > 0 {
                        SubjectGlow(outline: s.outline, canvas: canvas)
                            .opacity(glow * Self.glowLevel * tuning.subjectStrength)
                    }
                }
                lines(at: t)
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .allowsHitTesting(false)
    }

    /// All the lines in one Canvas: each outline trimmed to its draw progress. A wide, dim
    /// stroke under a thin bright one keeps the line slightly soft rather than hard-edged.
    private func lines(at t: Double) -> some View {
        Canvas { ctx, _ in
            ctx.addFilter(.blur(radius: 1.0))
            for s in subjects {
                let f = timeline.frame(s.id, at: t)
                guard f.drawProgress > 0, f.line > 0 else { continue }
                let path = s.path.trimmedPath(from: 0, to: f.drawProgress)
                let style = StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round, lineJoin: .round)
                let halo = StrokeStyle(lineWidth: Self.lineWidth * 3, lineCap: .round, lineJoin: .round)
                ctx.stroke(path, with: .color(Palette.gold.opacity(0.3 * f.line)), style: halo)
                ctx.stroke(path, with: .color(Self.lineColor.opacity(0.85 * f.line)), style: style)
            }
        }
    }
}
