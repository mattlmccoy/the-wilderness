import SwiftUI
import WildernessCore

/// Places a column of wall text beside the tapestry (or over its lower edge on a narrow wall),
/// in artwork canvas units. Shared by WallText and the menu so both sit in the same place.
struct WallColumn<Content: View>: View {
    let placement: ColumnPlacement
    /// Vertical position to start level with, 0…1 in the artwork.
    let anchorY: Double
    @ViewBuilder let content: Content

    @State private var columnHeight: CGFloat = 0
    private let canvas = CGSize(width: Artwork.canvasWidth, height: Artwork.canvasHeight)
    static var unitsPerInch: CGFloat { 20 }
    private var column: CGFloat { placement.widthInches * Self.unitsPerInch }

    var body: some View {
        switch placement.position {
        case .beside(let side):
            let x = side == .right ? canvas.width + TextColumnLayout.gap * Self.unitsPerInch
                                   : -TextColumnLayout.gap * Self.unitsPerInch - column
            // Start level with the anchor, but move up as far as needed to keep the whole
            // column on the tapestry's height (bigger type makes it tall).
            content
                .frame(width: column, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { columnHeight = $0 }
                .offset(x: x, y: max(0, min(anchorY * canvas.height - 90, canvas.height - columnHeight)))
        case .onCanvas(let z):
            // On the painting, in a calm dark zone; kept wholly on the tapestry if the text is tall.
            content
                .frame(width: column, alignment: .leading)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { columnHeight = $0 }
                .offset(x: z.x * canvas.width,
                        y: max(0, min(z.y * canvas.height, canvas.height - columnHeight - Self.unitsPerInch)))
        case .overLowerEdge:
            content
                .frame(width: column, alignment: .leading)
                .frame(width: canvas.width - 2 * Self.unitsPerInch, height: canvas.height - Self.unitsPerInch,
                       alignment: .bottomLeading)
                .offset(x: Self.unitsPerInch, y: 0)
        }
    }
}

/// The small faint lines that tell a guest where they are and what the remote does.
enum Wayfinding {
    static func header(_ s: String) -> some View {
        Text(s).font(Typography.text(Typography.Size.citation)).tracking(3)
            .foregroundStyle(Palette.ivory.opacity(0.6))
    }

    static func hint(_ s: String) -> some View {
        Text(s).font(Typography.text(Typography.Size.citation, italic: true)).tracking(1)
            .foregroundStyle(Palette.ivory.opacity(0.7))
    }

    static let exploreHint = "Arrows to move  ·  Select for more\nBack to return"
    static let unfoldHint = "Play/Pause to pause  ·  Arrows to skip\nBack to return"
    static let contextHint = "Arrows to turn the page\nBack to return"
}
