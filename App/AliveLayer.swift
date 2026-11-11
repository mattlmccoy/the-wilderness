import SwiftUI
import WildernessCore

/// The wall at rest: every traced region breathes on its own slow rhythm (`Breathing`), and,
/// if switched on, a soft band of light passes now and then (`PassingLight`). Always in the
/// tree so the rhythm never restarts; it fades out over 3 s whenever text or a lit figure is up.
struct AliveLayer: View {
    let library: AnnotationLibrary
    let breathing: Breathing
    let tuning: Tuning
    let active: Bool
    let clock: AliveClock

    static let fade = 3.0
    private let canvas = CGSize(width: Artwork.canvasWidth, height: Artwork.canvasHeight)

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(library.annotations.filter { $0.outline != nil }) { a in
                let period = breathing.period(for: a.id)
                BreathingRegion(outline: a.outline!, canvas: canvas,
                                period: period, delay: breathing.phase(for: a.id) * period)
            }
            .opacity(tuning.breathing)
            if tuning.passingLight { PassingLightView(clock: clock, canvas: canvas) }
        }
        .frame(width: canvas.width, height: canvas.height)
        .opacity(active ? 1 : 0)
        .animation(.easeInOut(duration: Self.fade), value: active)
        .allowsHitTesting(false)
        .onAppear { clock.start(at: Date().timeIntervalSinceReferenceDate) }
    }
}

/// When breathing began, shared with the glints so they can follow the breath.
final class AliveClock {
    private(set) var since: Double?
    func start(at t: Double) {
        guard since == nil else { return }
        // Preview: `-passingLightDemo YES` starts a pass of sun rays right away.
        let demo = UserDefaults.standard.bool(forKey: "passingLightDemo")
        since = demo ? t - (PassingLight.every - PassingLight.duration) : t
    }
}

/// One region: its soft glow, swelling in and easing out forever. A system animation
/// (ease in-out, the same curve as `Breathing.breath`), so nothing is redrawn per frame.
private struct BreathingRegion: View {
    let outline: [Point<ArtworkSpace>]
    let canvas: CGSize
    let period: Double
    let delay: Double
    @State private var inhaled = false

    var body: some View {
        SubjectGlow(outline: outline, canvas: canvas)
            .opacity(inhaled ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: period / 2).repeatForever(autoreverses: true).delay(delay)) {
                    inhaled = true
                }
            }
    }
}

/// Sun rays: a few soft beams slanting down from above the tapestry (SunRays), added as light.
private struct PassingLightView: View {
    let clock: AliveClock
    let canvas: CGSize

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { timeline in
            Canvas { ctx, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                guard let since = clock.since, let f = SunRays.frame(at: now, since: since) else { return }
                ctx.blendMode = .plusLighter
                ctx.addFilter(.blur(radius: 9))
                let origin = CGPoint(x: f.originX * size.width, y: -size.height * 0.35)
                let length = size.height * 1.9
                for beam in f.beams {
                    let a = (f.angleDegrees + beam.offsetDegrees) * .pi / 180
                    let dir = CGPoint(x: sin(a), y: cos(a))          // 0° is straight down
                    let normal = CGPoint(x: dir.y, y: -dir.x)
                    let far = CGPoint(x: origin.x + dir.x * length, y: origin.y + dir.y * length)
                    let wFar = beam.width * size.width / 2, wNear = wFar * 0.15
                    var wedge = Path()
                    wedge.move(to: CGPoint(x: origin.x + normal.x * wNear, y: origin.y + normal.y * wNear))
                    wedge.addLine(to: CGPoint(x: far.x + normal.x * wFar, y: far.y + normal.y * wFar))
                    wedge.addLine(to: CGPoint(x: far.x - normal.x * wFar, y: far.y - normal.y * wFar))
                    wedge.addLine(to: CGPoint(x: origin.x - normal.x * wNear, y: origin.y - normal.y * wNear))
                    wedge.closeSubpath()
                    let i = f.intensity * beam.strength
                    ctx.fill(wedge, with: .linearGradient(
                        Gradient(stops: [.init(color: Palette.ivory.opacity(0), location: 0.1),
                                         .init(color: Palette.ivory.opacity(i), location: 0.4),
                                         .init(color: Palette.ivory.opacity(i * 0.6), location: 0.75),
                                         .init(color: Palette.ivory.opacity(0), location: 1)]),
                        startPoint: origin, endPoint: far))
                }
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .clipped()
    }
}
