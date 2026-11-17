import SwiftUI
import WildernessCore

/// Be still (Matt, 2026-11-16): the slow rotation of Christ's words, and Old Testament verses that point
/// to Him, set large in the reading zone while Christ alone is lit. Drawn from the clock.
struct StillWordsLayer: View {
    let words: StillWords
    let licensed: LicensedVerses
    /// When the words begin (reference-date seconds): after the opening line.
    let since: Double
    let day: CivilDate
    let placement: ColumnPlacement

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 15)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate - since
            // Top-left aligned: WallColumn offsets from the canvas's corner (a centred container
            // pushed the words off the text zone; found 2026-11-16, nothing was drawn where it should be).
            ZStack(alignment: .topLeading) {
            Color.clear.frame(width: Artwork.canvasWidth, height: Artwork.canvasHeight)
            if let shown = StillRotation.line(at: t, day: day, words: words, licensed: licensed) {
                WallColumn(placement: placement, anchorY: 0) {
                    VStack(alignment: .leading, spacing: 18) {
                        Text(shown.line.text)
                            .font(Typography.text(Typography.Size.title * 0.72, italic: true))
                            .foregroundStyle(Palette.ivory)
                            .lineSpacing(6)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("\(shown.line.ref.uppercased())  ·  \(shown.line.translation.rawValue)")
                            .font(Typography.text(Typography.Size.citation)).tracking(2)
                            .foregroundStyle(shown.kind == .prophecy ? Palette.gold : Palette.stone)
                    }
                }
                .opacity(shown.alpha)
            }
            }
        }
        .frame(width: Artwork.canvasWidth, height: Artwork.canvasHeight)
        .allowsHitTesting(false)
    }
}
