import SwiftUI
import WildernessCore

/// Into the Quiet on the wall (docs/superpowers/specs/2026-11-16-prayer-mode-design.md): at Read, the
/// day's line on the canvas; throughout, Christ's light alone, breathing once every 14 s, never dark and
/// never bright. Drawn from the clock so nothing steps.
struct PrayerLayer: View {
    let library: AnnotationLibrary
    let session: PrayerSession
    let placement: ColumnPlacement
    let strength: Double

    private let canvas = CGSize(width: Artwork.canvasWidth, height: Artwork.canvasHeight)
    private var christ: [Point<ArtworkSpace>]? { library.annotations.first { $0.id == "christ" }?.outline }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20)) { timeline in
            let now = timeline.date.timeIntervalSinceReferenceDate
            let t = now - session.startedAt
            let rise = min(max(t / 6, 0), 1)                       // the light rises over 6 s
            let breath = 0.55 + 0.25 * sin(2 * .pi * t / Prayer.breathSeconds)
            ZStack(alignment: .topLeading) {
                if let o = christ {
                    SubjectGlow(outline: o, canvas: canvas).opacity(strength * breath * rise)
                }
                if let m = session.movement(at: now), m.movement == .read, let line = session.line {
                    // In over 4 s, out over the last 8 s of Read.
                    let alpha = min(1, m.elapsed / 4) * min(1, max(0, (m.length - m.elapsed) / 8))
                    WallColumn(placement: placement, anchorY: 0) {
                        VStack(alignment: .leading, spacing: 18) {
                            Text(line.text)
                                .font(Typography.text(Typography.Size.title * 0.8, italic: true))
                                .foregroundStyle(Palette.ivory)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(line.ref.uppercased())  ·  \(line.translation.rawValue)")
                                .font(Typography.text(Typography.Size.citation)).tracking(2)
                                .foregroundStyle(Palette.stone)
                        }
                    }
                    .opacity(alpha)
                }
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .allowsHitTesting(false)
    }
}
