import SwiftUI
import WildernessCore

/// Text drawn as light on the wall beside the tapestry (spec §5.2, §6.1, §7), in artwork canvas
/// units. Title, short line, and on the second press the story and its verses (Old Testament
/// first), each verse with its own small citation. No labels, no other references.
struct WallText: View {
    let title: String
    let short: String
    let more: More?
    /// Temporary until the copy pass: shown as the story when `more` is missing.
    let fallbackExtended: String?
    let expanded: Bool
    let placement: ColumnPlacement
    /// Vertical position of the subject, 0…1 in the artwork.
    let anchorY: Double

    private let canvas = CGSize(width: Artwork.canvasWidth, height: Artwork.canvasHeight)
    private static let unitsPerInch: CGFloat = 20
    private var column: CGFloat { placement.widthInches * Self.unitsPerInch }

    var body: some View {
        switch placement.position {
        case .beside(let side):
            let x = side == .right ? canvas.width + TextColumnLayout.gap * Self.unitsPerInch
                                   : -TextColumnLayout.gap * Self.unitsPerInch - column
            content
                .frame(width: column, alignment: .leading)
                .offset(x: x, y: min(max(anchorY * canvas.height - 90, 0), canvas.height - 460))
        case .overLowerEdge:
            content
                .frame(width: column, alignment: .leading)
                .frame(width: canvas.width - 2 * Self.unitsPerInch, height: canvas.height - Self.unitsPerInch,
                       alignment: .bottomLeading)
                .offset(x: Self.unitsPerInch, y: 0)
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(Typography.title())
                .foregroundStyle(Palette.ivory.opacity(0.9))
            Text(short)
                .font(Typography.text(Typography.Size.short, italic: true))
                .foregroundStyle(Palette.ivory.opacity(0.8))
            if expanded {
                VStack(alignment: .leading, spacing: 22) {
                    if let story = more?.story ?? fallbackExtended {
                        Text(story)
                            .font(Typography.text(Typography.Size.story)).lineSpacing(6)
                            .foregroundStyle(Palette.ivory.opacity(0.72))
                    }
                    ForEach(orderedVerses, id: \.ref) { v in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(v.text)
                                .font(Typography.text(Typography.Size.verse)).lineSpacing(5)
                                .foregroundStyle(Palette.ivory.opacity(0.82))
                            Text("\(v.ref) · \(v.translation.rawValue)")
                                .font(Typography.text(Typography.Size.citation)).tracking(1.5)
                                .foregroundStyle(Palette.ivory.opacity(0.55))
                        }
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.animation(.easeInOut(duration: LightTiming.textIn)))
            }
        }
        .multilineTextAlignment(.leading)
    }

    private var orderedVerses: [Verse] {
        (more?.verses ?? []).sorted { ($0.testament == .old ? 0 : 1) < ($1.testament == .old ? 0 : 1) }
    }
}
