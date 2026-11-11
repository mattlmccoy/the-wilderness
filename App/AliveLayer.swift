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
    func start(at t: Double) { if since == nil { since = t } }
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

/// A wide, very soft band of light drifting left to right across the tapestry.
private struct PassingLightView: View {
    let clock: AliveClock
    let canvas: CGSize

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { timeline in
            Canvas { ctx, size in
                let now = timeline.date.timeIntervalSinceReferenceDate
                guard let since = clock.since, let s = PassingLight.state(at: now, since: since) else { return }
                let ry = size.height * 0.9, rx = size.width * 0.22
                let g = Gradient(stops: [
                    .init(color: Palette.ivory.opacity(s.intensity), location: 0),
                    .init(color: Palette.ivory.opacity(s.intensity * 0.5), location: 0.45),
                    .init(color: Palette.ivory.opacity(0), location: 1),
                ])
                var c = ctx
                c.translateBy(x: s.x * size.width, y: size.height / 2)
                c.scaleBy(x: rx / ry, y: 1)
                c.fill(Path(ellipseIn: CGRect(x: -ry, y: -ry, width: 2 * ry, height: 2 * ry)),
                       with: .radialGradient(g, center: .zero, startRadius: 0, endRadius: ry))
            }
        }
        .frame(width: canvas.width, height: canvas.height)
    }
}
