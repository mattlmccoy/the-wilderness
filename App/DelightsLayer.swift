import SwiftUI
import WildernessCore

/// The seasons, the rare moments, the dreamcoat and the phone's flashlight, all drawn as light
/// in artwork canvas units (docs/superpowers/plans/2026-11-16-delights.md). The projector can only
/// add light, so hats are soft red light with a bright brim, the star and snow are glints, and
/// candle flames, eyes and the dawn are glows.
struct DelightsLayer: View {
    let library: AnnotationLibrary
    let delights: DelightsContent
    /// nil when Seasons is switched off.
    let seasons: SeasonEffects?
    /// The wall at rest: counters, snow, the dawn and the moments show only then.
    let atRest: Bool
    let zone: TextZone
    /// The dreamcoat runs until this time (reference-date seconds), if at all.
    let dreamcoatUntil: Double?
    let flashlight: Point<ArtworkSpace>?
    /// Wall time = real time + this (the simulator's -previewDate), for the moments.
    let wallOffset: TimeInterval
    /// The restoration page: when the angels began revealing (reference-date seconds).
    let revealSince: Double?

    private let canvas = CGSize(width: Artwork.canvasWidth, height: Artwork.canvasHeight)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24)) { timeline in
            Canvas { ctx, size in
                // Everything time-dependent is read from this clock, so it moves even while the
                // rest of the wall is still (the root view redraws only when something changes).
                let t = timeline.date.timeIntervalSinceReferenceDate
                let wall = timeline.date.addingTimeInterval(wallOffset)
                let moment = Moments.active(at: wall).map { m -> (Moment.Kind, Double) in
                    let start = Calendar.current.startOfDay(for: wall).addingTimeInterval(Double(m.minute * 60))
                    return (m.kind, wall.timeIntervalSince(start) / Moment.duration)
                }
                ctx.blendMode = .plusLighter
                if let s = seasons {
                    if s.christmas { hats(&ctx, size); if atRest { snow(&ctx, size, t) } }
                    if s.star { star(&ctx, size, t) }
                    if atRest, s.adventCandles > 0 { candles(&ctx, size, t, lit: s.adventCandles) }
                    if atRest, let day = s.lentDay { lentLine(&ctx, size, day: day) }
                    if atRest, s.easterDawn { dawn(&ctx, size, t) }
                    if s.halloween { eyes(&ctx, size, t) }
                }
                if atRest, let m = moment { self.moment(&ctx, size, m.0, m.1) }
                if let r = revealSince { revealAngels(&ctx, size, seconds: t - r) }
                if let until = dreamcoatUntil, t < until { coat(&ctx, size, t) }
                if let f = flashlight { torch(&ctx, size, f) }
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .allowsHitTesting(false)
    }

    // MARK: Christmas

    private func hats(_ ctx: inout GraphicsContext, _ size: CGSize) {
        for h in delights.hats {
            let w = (h.size ?? 0.03) * size.width, base = CGPoint(x: h.x * size.width, y: h.y * size.height)
            var c = ctx
            c.translateBy(x: base.x, y: base.y)
            c.rotate(by: .degrees(h.tilt ?? 0))
            var cone = Path()
            cone.move(to: CGPoint(x: -w / 2, y: 0))
            cone.addQuadCurve(to: CGPoint(x: w * 0.55, y: -w * 0.95), control: CGPoint(x: -w * 0.1, y: -w * 1.1))
            cone.addQuadCurve(to: CGPoint(x: w / 2, y: 0), control: CGPoint(x: w * 0.5, y: -w * 0.4))
            cone.closeSubpath()
            c.fill(cone, with: .color(Color(red: 0.95, green: 0.18, blue: 0.16).opacity(0.55)))
            c.stroke(cone, with: .color(Color(red: 1, green: 0.5, blue: 0.45).opacity(0.6)), lineWidth: 1.5)
            let brim = Path(roundedRect: CGRect(x: -w * 0.58, y: -w * 0.1, width: w * 1.16, height: w * 0.24), cornerRadius: w * 0.12)
            c.fill(brim, with: .color(Palette.ivory.opacity(0.85)))
            c.fill(Path(ellipseIn: CGRect(x: w * 0.45, y: -w * 1.07, width: w * 0.24, height: w * 0.24)), with: .color(Palette.ivory.opacity(0.9)))
        }
    }

    private func snow(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        var c = ctx
        c.addFilter(.blur(radius: 1.5))
        for i in 0..<70 {
            let r = { (k: Int) in Double((i * 7919 + k * 104_729) % 1000) / 1000 }
            let fall = 0.012 + 0.02 * r(1)
            let y = (r(2) + t * fall).truncatingRemainder(dividingBy: 1.08) - 0.04
            let x = r(3) + 0.012 * sin(t * (0.3 + 0.4 * r(4)) + Double(i))
            let d = 4 + 5 * r(5)
            c.fill(Path(ellipseIn: CGRect(x: x * size.width - d / 2, y: y * size.height - d / 2, width: d, height: d)),
                   with: .color(Palette.ivory.opacity(0.45 + 0.4 * r(6))))
        }
    }

    private func star(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let p = CGPoint(x: delights.star.x * size.width, y: delights.star.y * size.height)
        let twinkle = 0.85 + 0.15 * sin(t * 2.1)
        var halo = ctx
        halo.addFilter(.blur(radius: 26))
        halo.fill(Path(ellipseIn: CGRect(x: p.x - 50, y: p.y - 50, width: 100, height: 100)), with: .color(Color(red: 1, green: 0.93, blue: 0.75).opacity(0.5 * twinkle)))
        var star = Path()
        for k in 0..<16 {
            let a = Double(k) * .pi / 8 - .pi / 2, r = k % 2 == 0 ? (k % 4 == 0 ? 46.0 : 26.0) * twinkle : 7.0
            let q = CGPoint(x: p.x + cos(a) * r, y: p.y + sin(a) * r)
            k == 0 ? star.move(to: q) : star.addLine(to: q)
        }
        star.closeSubpath()
        ctx.fill(star, with: .color(Color(red: 1, green: 0.96, blue: 0.85).opacity(0.95)))
    }

    // MARK: Advent and Lent

    private func candles(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double, lit: Int) {
        let f = zoneFrame(size)
        for i in 0..<4 {
            let x = f.minX + 20 + CGFloat(i) * 34, bottom = f.maxY - 10
            ctx.stroke(Path { p in p.move(to: CGPoint(x: x, y: bottom)); p.addLine(to: CGPoint(x: x, y: bottom - 46)) },
                       with: .color(Palette.ivory.opacity(i < lit ? 0.6 : 0.25)), lineWidth: 6)
            guard i < lit else { continue }
            let flicker = 0.85 + 0.15 * sin(t * 9 + Double(i) * 1.7) * sin(t * 3.3 + Double(i))
            var glow = ctx
            glow.addFilter(.blur(radius: 10))
            glow.fill(Path(ellipseIn: CGRect(x: x - 14, y: bottom - 80, width: 28, height: 36)),
                      with: .color(Color(red: 1, green: 0.7, blue: 0.3).opacity(0.7 * flicker)))
            ctx.fill(Path(ellipseIn: CGRect(x: x - 4, y: bottom - 70 + 2 * (1 - flicker), width: 8, height: 18)),
                     with: .color(Color(red: 1, green: 0.93, blue: 0.7).opacity(flicker)))
        }
    }

    private func lentLine(_ ctx: inout GraphicsContext, _ size: CGSize, day: Int) {
        let f = zoneFrame(size)
        ctx.draw(Text("LENT · DAY \(day) OF 40").font(Typography.text(Typography.Size.citation)).tracking(3)
                    .foregroundStyle(Palette.ivory.opacity(0.75)),
                 at: CGPoint(x: f.minX + 12, y: f.maxY - 16), anchor: .bottomLeading)
    }

    /// The calm zone, inside the edge margin: where the counters sit.
    private func zoneFrame(_ size: CGSize) -> CGRect {
        let u = size.width / Calibration.tapestryInches.w
        let m = CanvasTextFrame.edgeMarginInches * u
        return CGRect(x: max(zone.x * size.width, m), y: zone.y * size.height,
                      width: zone.w * size.width, height: min(zone.h * size.height, size.height - m - zone.y * size.height))
    }

    // MARK: Easter, Halloween

    private func dawn(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let cycle = t.truncatingRemainder(dividingBy: 180)
        guard cycle < 40 else { return }
        let k = cycle / 40, x = (k * 1.6 - 0.3) * size.width, w = size.width * 0.35
        let fade = sin(k * .pi)
        ctx.fill(Path(CGRect(x: x - w, y: 0, width: 2 * w, height: size.height)),
                 with: .linearGradient(Gradient(stops: [.init(color: .clear, location: 0),
                                                        .init(color: Color(red: 1, green: 0.78, blue: 0.4).opacity(0.28 * fade), location: 0.5),
                                                        .init(color: .clear, location: 1)]),
                                       startPoint: CGPoint(x: x - w, y: 0), endPoint: CGPoint(x: x + w, y: 0)))
    }

    private func eyes(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        var c = ctx
        c.addFilter(.blur(radius: 3))
        for (i, e) in delights.eyes.enumerated() {
            let blink = sin(t * 0.7 + Double(i) * 2.3) > -0.95 ? 1.0 : 0.0
            let p = CGPoint(x: e.x * size.width, y: e.y * size.height)
            c.fill(Path(ellipseIn: CGRect(x: p.x - 6, y: p.y - 4, width: 12, height: 8)),
                   with: .color(Color(red: 1, green: 0.6, blue: 0.15).opacity(0.85 * blink)))
        }
    }

    // MARK: Moments, the restoration, the dreamcoat, the flashlight

    private func outline(_ id: String, _ size: CGSize, dy: CGFloat = 0) -> Path? {
        guard let o = library.annotations.first(where: { $0.id == id })?.outline, o.count > 2 else { return nil }
        var p = Path()
        p.addLines(o.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height + dy) })
        p.closeSubpath()
        return p
    }

    private func moment(_ ctx: inout GraphicsContext, _ size: CGSize, _ kind: Moment.Kind, _ k: Double) {
        let swell = sin(min(max(k, 0), 1) * .pi)
        switch kind {
        case .stagLeaps:
            // Two light bounds of the stag's outline, rising and settling.
            let hop = abs(sin(k * 2 * .pi)) * 28
            if let p = outline("stag", size, dy: -hop) {
                ctx.stroke(p, with: .color(Palette.ivory.opacity(0.7 * swell)), lineWidth: 2.5)
            }
        case .ravenGlints:
            if let e = delights.eyes.first(where: { $0.id == "raven" }) {
                let p = CGPoint(x: e.x * size.width, y: e.y * size.height), r = 4 + 22 * swell
                var g = ctx; g.addFilter(.blur(radius: 4))
                g.fill(Path(ellipseIn: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r)), with: .color(Palette.ivory.opacity(0.8 * swell)))
            }
        case .angelsBrighten:
            if let p = outline("angels", size) {
                var g = ctx; g.addFilter(.blur(radius: 14))
                g.fill(p, with: .color(Palette.ivory.opacity(0.6 * swell)))
                ctx.stroke(p, with: .color(Palette.ivory.opacity(0.8 * swell)), lineWidth: 2.5)
            }
        }
    }

    private func revealAngels(_ ctx: inout GraphicsContext, _ size: CGSize, seconds: Double) {
        guard let p = outline("angels", size) else { return }
        let draw = min(seconds / 6, 1)
        ctx.stroke(p.trimmedPath(from: 0, to: draw), with: .color(Palette.ivory.opacity(0.85)), lineWidth: 2.5)
        if seconds > 6 {
            var g = ctx; g.addFilter(.blur(radius: 16))
            g.fill(p, with: .color(Palette.ivory.opacity(0.3 * min((seconds - 6) / 3, 1))))
        }
    }

    private func coat(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let figures = library.annotations.filter { $0.outline != nil }
        for (i, a) in figures.enumerated() {
            guard let p = outline(a.id, size) else { continue }
            let hue = (Double(i) / Double(max(figures.count, 1)) + t * 0.15).truncatingRemainder(dividingBy: 1)
            let c = Color(hue: hue, saturation: 0.8, brightness: 1)
            var g = ctx; g.addFilter(.blur(radius: 12))
            g.fill(p, with: .color(c.opacity(0.35)))
            ctx.stroke(p, with: .color(c.opacity(0.9)), lineWidth: 3)
        }
    }

    private func torch(_ ctx: inout GraphicsContext, _ size: CGSize, _ f: Point<ArtworkSpace>) {
        let c = CGPoint(x: f.x * size.width, y: f.y * size.height), r = size.width * 0.09
        ctx.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)),
                 with: .radialGradient(Gradient(colors: [Palette.ivory.opacity(0.75), Palette.ivory.opacity(0.25), .clear]),
                                       center: c, startRadius: 0, endRadius: r))
    }
}
