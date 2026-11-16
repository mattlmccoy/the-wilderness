import SwiftUI
import WildernessCore

/// The seasons, the rare moments, the dreamcoat and the phone's flashlight, all drawn as light
/// in artwork canvas units (docs/superpowers/plans/2026-11-16-delights.md). The projector can only
/// add light, so hats are soft red light with a bright brim, the star and snow are glints, and
/// candle flames and the dawn are glows.
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

    /// Mirrors drawHat() in scripts/placer_template.html: cloth in the painting's vermilion, lit
    /// from the upper left like the figures, a fold, a soft fur trim and a pompom, edges softened.
    private func hats(_ ctx: inout GraphicsContext, _ size: CGSize) {
        func rgba(_ r: Double, _ g: Double, _ b: Double, _ a: Double) -> Color { Color(red: r / 255, green: g / 255, blue: b / 255).opacity(a) }
        for h in delights.hats {
            let w = (h.size ?? 0.03) * size.width
            var c = ctx
            c.translateBy(x: h.x * size.width, y: h.y * size.height)
            c.rotate(by: .degrees(h.tilt ?? 0))
            if h.flip == true { c.scaleBy(x: -1, y: 1) }
            c.addFilter(.blur(radius: max(0.4, w * 0.012)))
            var cone = Path()
            cone.move(to: CGPoint(x: -0.5 * w, y: 0))
            cone.addCurve(to: CGPoint(x: 0.42 * w, y: -1.02 * w), control1: CGPoint(x: -0.46 * w, y: -0.62 * w), control2: CGPoint(x: -0.05 * w, y: -1.12 * w))
            cone.addQuadCurve(to: CGPoint(x: 0.68 * w, y: -0.74 * w), control: CGPoint(x: 0.6 * w, y: -0.97 * w))
            cone.addCurve(to: CGPoint(x: 0.5 * w, y: 0), control1: CGPoint(x: 0.52 * w, y: -0.8 * w), control2: CGPoint(x: 0.44 * w, y: -0.42 * w))
            cone.closeSubpath()
            c.fill(cone, with: .linearGradient(Gradient(stops: [.init(color: rgba(196, 70, 48, 0.92), location: 0),
                                                                 .init(color: rgba(158, 42, 32, 0.92), location: 0.45),
                                                                 .init(color: rgba(92, 22, 18, 0.92), location: 1)]),
                                               startPoint: CGPoint(x: -0.5 * w, y: -0.9 * w), endPoint: CGPoint(x: 0.55 * w, y: -0.1 * w)))
            var fold = Path(); fold.move(to: CGPoint(x: 0.12 * w, y: -0.05 * w)); fold.addQuadCurve(to: CGPoint(x: 0.42 * w, y: -0.9 * w), control: CGPoint(x: 0.2 * w, y: -0.55 * w))
            c.stroke(fold, with: .color(rgba(60, 12, 10, 0.35)), style: StrokeStyle(lineWidth: w * 0.05, lineCap: .round))
            var shine = Path(); shine.move(to: CGPoint(x: -0.32 * w, y: -0.1 * w)); shine.addQuadCurve(to: CGPoint(x: 0.05 * w, y: -0.92 * w), control: CGPoint(x: -0.3 * w, y: -0.6 * w))
            c.stroke(shine, with: .color(rgba(255, 190, 160, 0.22)), style: StrokeStyle(lineWidth: w * 0.07, lineCap: .round))
            func tuft(_ x: Double, _ y: Double, _ r: Double, edge: Color) {
                c.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                       with: .radialGradient(Gradient(stops: [.init(color: rgba(246, 238, 222, 0.95), location: 0),
                                                              .init(color: rgba(222, 208, 184, 0.9), location: 0.7),
                                                              .init(color: edge, location: 1)]),
                                             center: CGPoint(x: x - r * 0.3, y: y - r * 0.4), startRadius: r * 0.1, endRadius: r))
            }
            for i in 0..<13 {
                let k = Double(i) / 12
                tuft((-0.58 + 1.16 * k) * w, -0.02 * w + sin(Double(i) * 2.1) * 0.025 * w, (0.115 + 0.025 * sin(Double(i) * 1.7)) * w, edge: rgba(170, 150, 124, 0))
            }
            for i in 0..<5 {
                let a = Double(i) * 1.26
                tuft(0.68 * w + cos(a) * 0.04 * w, -0.72 * w + sin(a) * 0.04 * w, 0.085 * w, edge: rgba(190, 172, 146, 0))
            }
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

    /// Mirrors drawStar() in scripts/placer_template.html: a warm glint with a soft halo.
    private func star(_ ctx: inout GraphicsContext, _ size: CGSize, _ t: Double) {
        let p = CGPoint(x: delights.star.x * size.width, y: delights.star.y * size.height)
        let twinkle = 0.9 + 0.1 * sin(t * 2.1)
        let L = (delights.star.size ?? 0.028) * size.width * twinkle
        ctx.fill(Path(ellipseIn: CGRect(x: p.x - L * 1.3, y: p.y - L * 1.3, width: L * 2.6, height: L * 2.6)),
                 with: .radialGradient(Gradient(colors: [Color(red: 1, green: 0.94, blue: 0.8).opacity(0.55), Color(red: 1, green: 0.9, blue: 0.7).opacity(0)]),
                                       center: p, startRadius: 0, endRadius: L * 1.3))
        var c = ctx
        c.addFilter(.blur(radius: max(0.5, L * 0.03)))
        for k in 0..<8 {
            let len = k % 2 == 1 ? L * 0.45 : L, wd = k % 2 == 1 ? L * 0.05 : L * 0.075
            var r = c
            r.translateBy(x: p.x, y: p.y)
            r.rotate(by: .radians(Double(k) * .pi / 4 - .pi / 2))
            var ray = Path(); ray.move(to: CGPoint(x: 0, y: -wd)); ray.addLine(to: CGPoint(x: len, y: 0)); ray.addLine(to: CGPoint(x: 0, y: wd)); ray.closeSubpath()
            r.fill(ray, with: .linearGradient(Gradient(colors: [Color(red: 1, green: 0.97, blue: 0.89).opacity(0.95), Color(red: 1, green: 0.93, blue: 0.77).opacity(0)]),
                                              startPoint: .zero, endPoint: CGPoint(x: len, y: 0)))
        }
        c.fill(Path(ellipseIn: CGRect(x: p.x - L * 0.09, y: p.y - L * 0.09, width: L * 0.18, height: L * 0.18)), with: .color(Color(red: 1, green: 0.99, blue: 0.94)))
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

    // MARK: Easter

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
            do {
                let e = delights.ravenEye
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
