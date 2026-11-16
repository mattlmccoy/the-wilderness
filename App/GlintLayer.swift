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
    /// Preference for where the next glint lands (the breath of the region under it); nil = anywhere.
    var bias: ((Point<ArtworkSpace>, Double) -> Double)? = nil

    @State private var clock = GlintClock()
    private let canvas = CGSize(width: Artwork.canvasWidth, height: Artwork.canvasHeight)
    static let unitsPerInch = 20.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            Canvas { ctx, _ in
                let now = timeline.date.timeIntervalSinceReferenceDate
                guard let g = clock.glint(at: now, points: points, tuning: tuning, demo: demo, bias: bias) else { return }
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
        let at = g.position(at: now)   // drifting, like a small star shifting
        let p = CGPoint(x: at.x * canvas.width, y: at.y * canvas.height)
        var c = ctx
        // Light adds to what is already lit (the tapestry, or the painting in preview); it never
        // just tints it. Without this a glint over a bright passage barely shows.
        c.blendMode = .plusLighter
        c.translateBy(x: p.x, y: p.y)
        // Soft halo, stretched along the thread for that style.
        var halo = c
        if tuning.glintStyle == .thread { halo.scaleBy(x: 3, y: 1) }
        let R = r * 2.2
        halo.fill(Path(ellipseIn: CGRect(x: -R, y: -R, width: 2 * R, height: 2 * R)),
                  with: .radialGradient(Gradient(stops: [
                    .init(color: Palette.ivory.opacity(i * 0.55), location: 0),
                    .init(color: Palette.ivory.opacity(i * 0.18), location: 0.45),
                    .init(color: Palette.ivory.opacity(0), location: 1)]),
                                        center: .zero, startRadius: 0, endRadius: R))
        // A small hard core: the point of light the eye actually catches.
        let k = r * 0.32
        c.fill(Path(ellipseIn: CGRect(x: -k, y: -k, width: 2 * k, height: 2 * k)), with: .color(.white.opacity(i)))
        // A faint four-point twinkle, only near the peak.
        let t = max(0, i - 0.5) * 2
        if t > 0 {
            var star = Path()
            let L = r * 2.6
            star.move(to: CGPoint(x: -L, y: 0)); star.addLine(to: CGPoint(x: L, y: 0))
            star.move(to: CGPoint(x: 0, y: -L * 0.7)); star.addLine(to: CGPoint(x: 0, y: L * 0.7))
            c.stroke(star, with: .linearGradient(Gradient(colors: [.clear, Palette.ivory.opacity(0.6 * t), .clear]),
                                                 startPoint: CGPoint(x: -L, y: 0), endPoint: CGPoint(x: L, y: 0)),
                     lineWidth: max(0.6, r * 0.12))
        }
    }
}

/// Holds the scheduler across frames. A reference type because the Canvas draw closure
/// advances it as time passes.
final class GlintClock {
    private var scheduler: GlintScheduler<SplitMix64>?
    private var lastDemo = 0.0

    func glint(at now: Double, points: GlintPoints, tuning: Tuning, demo: Bool,
               bias: ((Point<ArtworkSpace>, Double) -> Double)?) -> Glint? {
        if scheduler == nil {
            scheduler = GlintScheduler(points: points.points, params: tuning.glintParams,
                                       rng: SplitMix64(seed: UInt64(now * 1000)), now: now)
        }
        scheduler!.params = tuning.glintParams
        scheduler!.weight = bias
        if demo, now - lastDemo >= 2 {
            scheduler!.fireNow(at: now)
            lastDemo = now
        }
        return scheduler!.active(at: now)
    }
}
