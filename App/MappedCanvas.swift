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
            content()
                .frame(width: canvas.width, height: canvas.height, alignment: .topLeading)
                .projectionEffect(ProjectionTransform(h.rowVectorElements))
                .frame(width: screen.width, height: screen.height, alignment: .topLeading)
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
