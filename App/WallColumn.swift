import SwiftUI
import WildernessCore
import os

private let canvasTextLog = Logger(subsystem: "com.mattmccoy.wilderness", category: "text")

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
            // On the painting, in a calm dark zone, clear of the tapestry's edges; type shrinks
            // when the text is taller than the tapestry allows (CanvasTextFrame), so it all fits.
            let u = Self.unitsPerInch
            let f = CanvasTextFrame.place(zone: z, tapestry: (Double(canvas.width / u), Double(canvas.height / u)),
                                          naturalHeight: Double(columnHeight / u))
            content
                .frame(width: f.width * u, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { h in
                    columnHeight = h
                    let s = CanvasTextFrame.place(zone: z, tapestry: (Double(canvas.width / u), Double(canvas.height / u)),
                                                  naturalHeight: Double(h / u)).scale
                    canvasTextLog.debug("canvas text: \(Double(h / u), format: .fixed(precision: 1)) in tall, scale \(s, format: .fixed(precision: 2))")
                }
                .scaleEffect(f.scale, anchor: .topLeading)
                .offset(x: f.x * u, y: f.y * u)
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
