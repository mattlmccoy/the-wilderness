import SwiftUI
import WildernessCore

/// Context (spec addendum 2026-11-10): one page about the painting itself, in artwork canvas units.
/// Text sits in the wall column; a page may add the three-city map under its text, or a frame of
/// light on the tapestry at the original canvas's true size. Light on subjects comes from the
/// root LightLayer (`ContextView.targets`).
struct ContextView: View {
    let script: ContextScript
    var maps: ContextMaps = .empty
    let page: Int
    let calibration: Calibration
    var header: String? = nil
    var showsHint: Bool = false
    var canvasZone: TextZone? = nil

    private var p: ContextPage { script.pages[min(page, script.pages.count - 1)] }

    static func targets(_ script: ContextScript, page: Int) -> Set<String> {
        guard script.pages.indices.contains(page) else { return [] }
        return Set(script.pages[page].light)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if p.visual == .trueSize {
                TrueSizeFrame().id(p.id + "-frame")
                    .transition(.opacity.animation(.easeInOut(duration: LightTiming.textOut)))
            }
            let placement = TextColumnLayout.place(preferred: p.textSide, calibration: calibration, canvasZone: canvasZone)
            // On the painting the page must fit within the tapestry: smaller map and photo.
            let compact: Bool = { if case .onCanvas = placement.position { return true }; return false }()
            WallColumn(placement: placement, anchorY: 0.3) {
                VStack(alignment: .leading, spacing: 14) {
                    if let header { Wayfinding.header(header) }
                    Text(p.title).font(Typography.title()).foregroundStyle(Palette.ivory)
                    Text(p.text)
                        .font(Typography.text(Typography.Size.story)).lineSpacing(6)
                        .foregroundStyle(Palette.ivory.opacity(0.9))
                    if let id = p.map, let map = maps.map(id) {
                        ContextMapView(map: map, maxAspect: compact ? 0.45 : ContextMapView.maxAspect).id(p.id + "-map").padding(.top, compact ? 10 : 18)
                    }
                    if let img = p.image { ContextPhoto(image: img, maxHeight: compact ? 110 : ContextPhoto.maxHeight).id(p.id + "-photo").padding(.top, compact ? 10 : 18) }
                    if showsHint {
                        Wayfinding.hint(Wayfinding.contextHint).padding(.top, 10).transition(.opacity)
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.easeInOut(duration: LightTiming.textOut), value: showsHint)
            }
            .id(p.id)
            .transition(.asymmetric(
                insertion: .opacity.animation(.easeIn(duration: LightTiming.textIn).delay(LightTiming.textDelay)),
                removal: .opacity.animation(.easeOut(duration: LightTiming.textOut))))
        }
        .animation(.easeInOut(duration: LightTiming.textOut), value: page)
    }
}

/// A thin frame of light at the Met canvas's true size (18 × 21¾ in), centred on the tapestry.
private struct TrueSizeFrame: View {
    @State private var drawn: CGFloat = 0

    var body: some View {
        let f = OriginalCanvas.trueSizeFrame(canvasWidth: Artwork.canvasWidth, canvasHeight: Artwork.canvasHeight,
                                             unitsPerInch: Double(WallColumn<EmptyView>.unitsPerInch))
        Rectangle()
            .trim(from: 0, to: drawn)
            .stroke(Palette.gold.opacity(0.9), lineWidth: 2.5)
            .shadow(color: Palette.gold.opacity(0.6), radius: 6)
            .frame(width: f.width, height: f.height)
            .offset(x: f.x, y: f.y)
            .onAppear { withAnimation(.easeInOut(duration: 2.5).delay(LightTiming.textDelay)) { drawn = 1 } }
            .accessibilityLabel("True size of the original painting")
    }
}
