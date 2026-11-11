import SwiftUI
import UIKit
import WildernessCore

/// A real map (maps.json): coast, lakes and rivers as thin lines of light, places as points,
/// the page's own place in gold. A route, if any, draws itself as a great-circle arc.
struct ContextMapView: View {
    let map: ContextMap
    @State private var shown = false
    @State private var routeDrawn: CGFloat = 0
    /// The column's width, measured; the map fills it.
    @State private var width: CGFloat = 0
    /// Never taller than this share of the width, so tall maps don't push the text off the wall.
    static let maxAspect: CGFloat = 0.85

    var body: some View {
        Color.clear.frame(height: 1)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .overlay(alignment: .topLeading) { if width > 0 { drawn(width) } }
            .frame(height: width > 0 ? MapProjection(box: map.bbox, width: Double(width), height: Double(width * Self.maxAspect)).height : 1,
                   alignment: .topLeading)
    }

    private func drawn(_ width: CGFloat) -> some View {
        let proj = MapProjection(box: map.bbox, width: Double(width), height: Double(width * Self.maxAspect))
        return ZStack(alignment: .topLeading) {
            Canvas { ctx, _ in draw(proj, in: &ctx) }
            if let route = routePath(proj) {
                route.trim(from: 0, to: routeDrawn)
                    .stroke(Palette.gold.opacity(0.8), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, dash: [5, 5]))
            }
        }
        .frame(width: proj.width, height: proj.height)
        .opacity(shown ? 1 : 0)
        .onAppear {
            withAnimation(.easeIn(duration: 1.6).delay(LightTiming.textDelay)) { shown = true }
            withAnimation(.easeInOut(duration: 3).delay(LightTiming.textDelay + 1.2)) { routeDrawn = 1 }
        }
        .accessibilityLabel("Map: " + map.places.map(\.name).joined(separator: ", "))
    }

    private func draw(_ proj: MapProjection, in ctx: inout GraphicsContext) {
        func cg(_ lon: Double, _ lat: Double) -> CGPoint { let p = proj.point(lon: lon, lat: lat); return CGPoint(x: p.x, y: p.y) }
        ctx.clip(to: Path(CGRect(x: 0, y: 0, width: proj.width, height: proj.height)))
        for line in map.lines {
            var path = Path()
            path.addLines(line.points.map { cg($0[0], $0[1]) })
            if line.closed { path.closeSubpath() }
            switch line.kind {
            case "lake":
                if line.closed { ctx.fill(path, with: .color(Palette.ivory.opacity(0.10))) }
                ctx.stroke(path, with: .color(Palette.ivory.opacity(0.42)), lineWidth: 1)
            case "river":
                ctx.stroke(path, with: .color(Palette.ivory.opacity(0.26)), lineWidth: 1)
            default:
                ctx.stroke(path, with: .color(Palette.ivory.opacity(0.5)), lineWidth: 1.2)
            }
        }
        for label in map.labels {
            ctx.draw(Text(label.text).font(Typography.text(Typography.Size.citation * 0.8, italic: true))
                        .foregroundStyle(Palette.ivory.opacity(0.42)),
                     at: cg(label.lon, label.lat), anchor: .center)
        }
        for place in map.places {
            let at = cg(place.lon, place.lat)
            let r: CGFloat = place.home ? 5.5 : 3.5
            if place.home {
                ctx.fill(Path(ellipseIn: CGRect(x: at.x - 12, y: at.y - 12, width: 24, height: 24)),
                         with: .radialGradient(Gradient(colors: [Palette.gold.opacity(0.45), .clear]),
                                               center: at, startRadius: 0, endRadius: 12))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: at.x - r, y: at.y - r, width: 2 * r, height: 2 * r)),
                     with: .color(place.home ? Palette.gold : Palette.ivory.opacity(0.75)))
            // Labels sit right of the point, or left when the point is near the right edge.
            let right = at.x < proj.width * 0.72
            ctx.draw(Text(place.name).font(Typography.text(Typography.Size.citation * 0.85, italic: !place.home))
                        .foregroundStyle(Palette.ivory.opacity(place.home ? 0.95 : 0.7)),
                     at: CGPoint(x: at.x + (right ? 9 : -9), y: at.y), anchor: right ? .leading : .trailing)
        }
    }

    private func routePath(_ proj: MapProjection) -> Path? {
        guard let r = map.route, let a = map.places.first(where: { $0.name == r[0] }),
              let b = map.places.first(where: { $0.name == r[1] }) else { return nil }
        var path = Path()
        let pts = MapProjection.greatCircle(lat1: a.lat, lon1: a.lon, lat2: b.lat, lon2: b.lon, steps: 48)
            .map { proj.point(lon: $0.lon, lat: $0.lat) }
        path.addLines(pts.map { CGPoint(x: $0.x, y: $0.y) })
        return path
    }
}

/// A photograph under the page's text: slightly muted, its edges dissolving into the dark wall,
/// with a caption and the credit its licence asks for.
struct ContextPhoto: View {
    let image: ContextImage
    @State private var shown = false
    static let maxHeight: CGFloat = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let ui = Self.load(image.file) {
                Image(uiImage: ui).resizable().aspectRatio(contentMode: .fit)
                    .frame(maxHeight: Self.maxHeight, alignment: .leading)
                    .saturation(0.8)
                    .mask(feather)
                    .opacity(0.92)
            } else {
                // Visible and distinct: never a silent gap that looks like "no photo intended".
                Text("Photo missing: \(image.file)").font(Typography.text(Typography.Size.citation)).foregroundStyle(Palette.gold)
            }
            if let caption = image.caption {
                Text(caption).font(Typography.text(Typography.Size.citation, italic: true))
                    .foregroundStyle(Palette.ivory.opacity(0.7))
            }
            Text(image.credit).font(Typography.text(Typography.Size.citation * 0.7))
                .foregroundStyle(Palette.ivory.opacity(0.4))
        }
        .opacity(shown ? 1 : 0)
        .onAppear { withAnimation(.easeIn(duration: 1.8).delay(LightTiming.textDelay + 0.4)) { shown = true } }
    }

    /// Soft on all four edges.
    private var feather: some View {
        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.08),
                               .init(color: .black, location: 0.92), .init(color: .clear, location: 1)],
                       startPoint: .leading, endPoint: .trailing)
            .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.1),
                                         .init(color: .black, location: 0.9), .init(color: .clear, location: 1)],
                                 startPoint: .top, endPoint: .bottom))
    }

    static func load(_ file: String) -> UIImage? {
        let name = (file as NSString).deletingPathExtension, ext = (file as NSString).pathExtension
        return Bundle.main.path(forResource: name, ofType: ext).flatMap(UIImage.init(contentsOfFile:))
    }
}
