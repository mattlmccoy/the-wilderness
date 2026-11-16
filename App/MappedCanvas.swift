import SwiftUI
import WildernessCore

/// Draws `content` in artwork canvas coordinates (Artwork.canvasWidth × canvasHeight)
/// and warps the whole layer with one homography so it lands on the physical tapestry.
/// Everything placed inside — highlights, masks, type — is perspective-correct for free.
struct MappedCanvas<Content: View>: View {
    let calibration: Calibration
    let screen: CGSize
    @ViewBuilder var content: () -> Content

    var body: some View {
        let canvas = PixelSize(width: Artwork.canvasWidth, height: Artwork.canvasHeight)
        let screenSize = PixelSize(width: screen.width, height: screen.height)
        if let h = calibration.canvasToScreen(canvas: canvas, screen: screenSize) {
            // A full-screen box under the warped layer, so the bend (which redraws only the layer's
            // own box) sees everything the perspective put on screen, not just the canvas's box.
            ZStack(alignment: .topLeading) {
                Color.clear
                content()
                    .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
                    .projectionEffect(ProjectionTransform(h.rowVectorElements))
            }
            .frame(width: screen.width, height: screen.height, alignment: .topLeading)
            .modifier(BendEffect(calibration: calibration, screen: screenSize))
        }
    }
}

/// Eight-point alignment: bows each edge through its midpoint (Bend.metal). Skipped entirely
/// while every edge is straight, so a 4-corner calibration renders exactly as before.
private struct BendEffect: ViewModifier {
    let calibration: Calibration
    let screen: PixelSize

    func body(content: Content) -> some View {
        if calibration.isBent, let rows = calibration.screenToArtworkRows(screen: screen) {
            let o = calibration.edgeOffsets
            let f3 = { (r: SIMD3<Double>) in Shader.Argument.float3(Float(r.x), Float(r.y), Float(r.z)) }
            let shader = ShaderLibrary.wildernessBend(
                f3(rows[0]), f3(rows[1]), f3(rows[2]),
                .float2(Float(screen.width), Float(screen.height)),
                .float4(Float(o[0].x), Float(o[0].y), Float(o[2].x), Float(o[2].y)),
                .float4(Float(o[1].x), Float(o[1].y), Float(o[3].x), Float(o[3].y)))
            let m = Calibration.maxEdgeOffset
            // Flattened first, so the bend sees everything the perspective drew (Canvas views included).
            content.drawingGroup().distortionEffect(shader, maxSampleOffset: CGSize(width: m * screen.width, height: m * screen.height))
        } else {
            content
        }
    }
}

extension ProjectionTransform {
    init(_ e: ProjectiveElements) {
        self.init()
        m11 = e.m11; m12 = e.m12; m13 = e.m13
        m21 = e.m21; m22 = e.m22; m23 = e.m23
        m31 = e.m31; m32 = e.m32; m33 = e.m33
    }
}

/// The prototype's test shape: a hairline on the tapestry's woven border plus a centre mark.
/// On the wall, the line should sit exactly on the edge of the weave all the way round.
struct RegistrationTestPattern: View {
    var strength: Double = 1

    var body: some View {
        Canvas { ctx, size in
            let rect = CGRect(origin: .zero, size: size)
            ctx.stroke(Path(rect.insetBy(dx: 2, dy: 2)), with: .color(Palette.ivory.opacity(0.85 * strength)), lineWidth: 3)
            var thirds = Path()
            for f in [1.0 / 3, 2.0 / 3] {
                thirds.move(to: CGPoint(x: size.width * f, y: 0)); thirds.addLine(to: CGPoint(x: size.width * f, y: size.height))
                thirds.move(to: CGPoint(x: 0, y: size.height * f)); thirds.addLine(to: CGPoint(x: size.width, y: size.height * f))
            }
            ctx.stroke(thirds, with: .color(Palette.stone.opacity(0.35 * strength)), lineWidth: 1.5)
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            var cross = Path()
            cross.move(to: CGPoint(x: c.x - 24, y: c.y)); cross.addLine(to: CGPoint(x: c.x + 24, y: c.y))
            cross.move(to: CGPoint(x: c.x, y: c.y - 24)); cross.addLine(to: CGPoint(x: c.x, y: c.y + 24))
            ctx.stroke(cross, with: .color(Palette.gold.opacity(0.9 * strength)), lineWidth: 2)
        }
    }
}
