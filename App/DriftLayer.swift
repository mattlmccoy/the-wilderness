import SwiftUI
import WildernessCore

/// Light drifting slowly from figure to figure (Drift): at rest, gently and round and round; in
/// Be still, along its seven-minute walk. Drawn from the clock every frame, so the cross-fades are
/// continuous rather than animation steps (docs/superpowers/plans/2026-11-16-drift-and-parity.md).
struct DriftLayer: View {
    let library: AnnotationLibrary
    /// The walk, and when it began (reference-date seconds); nil draws nothing.
    let path: [String]
    let since: Double?
    let dwell: Double
    let fade: Double
    let loops: Bool
    /// Peak opacity of a figure's light.
    let strength: Double

    private let canvas = CGSize(width: Artwork.canvasWidth, height: Artwork.canvasHeight)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20, paused: since == nil || strength <= 0)) { timeline in
            let w = since.map { Drift.weights(at: timeline.date.timeIntervalSinceReferenceDate - $0, path: path,
                                               dwell: dwell, fade: fade, loops: loops) } ?? [:]
            ZStack(alignment: .topLeading) {
                ForEach(library.annotations.filter { $0.outline != nil && w[$0.id] != nil }) { a in
                    SubjectGlow(outline: a.outline!, canvas: canvas)
                        .opacity((w[a.id] ?? 0) * strength)
                }
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .allowsHitTesting(false)
    }
}
