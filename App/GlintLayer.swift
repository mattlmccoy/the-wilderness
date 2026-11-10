import SwiftUI
import WildernessCore

/// Rare glints in the light's own colour (spec §4.1), drawn in artwork canvas units.
/// One at a time, wherever light could plausibly catch (points from glints.json).
struct GlintLayer: View {
    let points: GlintPoints
    let tuning: Tuning
    let calibration: Calibration
    /// Tuning screen: a glint every 2 s, so changes are visible right away.
    let demo: Bool

    @State private var clock = GlintClock()
    private let canvas = CGSize(width: Artwork.canvasWidth, height: Artwork.canvasHeight)
    static let unitsPerInch = 20.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            Canvas { ctx, _ in
                let now = timeline.date.timeIntervalSinceReferenceDate
                guard let g = clock.glint(at: now, points: points, tuning: tuning, demo: demo) else { return }
                draw(g, at: now, in: &ctx)
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .allowsHitTesting(false)
    }

    private func draw(_ g: Glint, at now: Double, in ctx: inout GraphicsContext) {
        let ppi = WallGeometry.pixelsPerInch(calibration)
        let coreInches = max(tuning.glintSizeInches, 0.5 / ppi)
        let r = coreInches * Self.unitsPerInch
        let i = g.intensity(at: now) * tuning.glintBrightness
        let p = CGPoint(x: g.point.x * canvas.width, y: g.point.y * canvas.height)
        let R = r * 2.2
        let gradient = Gradient(stops: [
            .init(color: Palette.ivory.opacity(i), location: 0),
            .init(color: Palette.ivory.opacity(i * 0.35), location: 0.4),
            .init(color: Palette.ivory.opacity(0), location: 1),
        ])
        var c = ctx
        c.translateBy(x: p.x, y: p.y)
        if tuning.glintStyle == .thread {
            // Light running along one thread: stretched 3:1 and sliding about 0.35 in.
            let slide = g.direction * (g.progress(at: now) - 0.5) * 0.35 * Self.unitsPerInch
            c.translateBy(x: slide, y: 0)
            c.scaleBy(x: 3, y: 1)
        }
        let rect = CGRect(x: -R, y: -R, width: 2 * R, height: 2 * R)
        c.fill(Path(ellipseIn: rect), with: .radialGradient(gradient, center: .zero, startRadius: 0, endRadius: R))
    }
}

/// Holds the scheduler across frames. A reference type because the Canvas draw closure
/// advances it as time passes.
final class GlintClock {
    private var scheduler: GlintScheduler<SplitMix64>?
    private var lastDemo = 0.0

    func glint(at now: Double, points: GlintPoints, tuning: Tuning, demo: Bool) -> Glint? {
        if scheduler == nil {
            scheduler = GlintScheduler(points: points.points, params: tuning.glintParams,
                                       rng: SplitMix64(seed: UInt64(now * 1000)), now: now)
        }
        scheduler!.params = tuning.glintParams
        if demo, now - lastDemo >= 2 {
            scheduler!.fireNow(at: now)
            lastDemo = now
        }
        return scheduler!.active(at: now)
    }
}
