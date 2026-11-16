import SwiftUI
import WildernessCore

/// Explore, drawn in artwork canvas units (1 unit ≈ 0.05 in on the wall; 20 units ≈ 1 in).
/// Explore's text (WallText) on the bare wall beside the tapestry; the light itself is the
/// root LightLayer. Text is placed outside the canvas bounds on purpose: the same
/// homography carries it onto the wall plane, so it is perspective-correct too.
struct ExploreView: View {
    let library: AnnotationLibrary
    let state: ExploreState
    let calibration: Calibration
    var showsHint: Bool = false
    /// Tune light → Edge line (0 = off).
    var edgeLine: Double = 0
    /// Where this figure's text goes when there is no room beside the tapestry.
    var canvasZone: TextZone? = nil
    /// Light only: double-press Play/Pause (or the phone) hides the text while exploring.
    var textHidden = false

    private var selected: (Annotation, Bool)? {
        guard case let .exploring(id, expanded) = state,
              let a = library.annotations.first(where: { $0.id == id }) else { return nil }
        return (a, expanded)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            if case let (a, _)? = selected, a.outline != nil {
                EdgeLineView(annotation: a, strength: edgeLine)
                    .id(a.id + "-edge")
                    .transition(.opacity.animation(.easeOut(duration: LightTiming.textOut)))
            }
            if !textHidden, case let (a, expanded)? = selected {
                WallText(title: a.title, short: a.short, more: a.more,
                         expanded: expanded,
                         placement: TextColumnLayout.place(preferred: a.textSide, calibration: calibration, canvasZone: canvasZone),
                         anchorY: a.anchor.y, header: "EXPLORE",
                         hint: showsHint ? Wayfinding.exploreHint : nil)
                    .id(a.id)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeIn(duration: LightTiming.textIn).delay(LightTiming.textDelay)),
                        removal: .opacity.animation(.easeOut(duration: LightTiming.textOut))))
            }
        }
        .animation(.easeInOut(duration: LightTiming.textOut), value: state)
        .animation(.easeInOut(duration: LightTiming.textOut), value: textHidden)
    }

}

/// Everything the app reads from its bundle.
struct AppContent {
    let library: AnnotationLibrary
    let script: UnfoldScript
    let context: ContextScript
    let maps: ContextMaps
    /// Calm places on the painting for text when there is no room beside it.
    let zones: [TextZone]
    let glints: GlintPoints
    let notices: Notices
    /// Hand-marked hats, the raven's eye and the star (seasons and Easter eggs).
    let delights: DelightsContent

    /// Each traced region's breathing rhythm (cheap: a handful of entries).
    var breathing: Breathing { Breathing(ids: library.annotations.filter { $0.outline != nil }.map(\.id)) }
}

enum ContentLoader {
    /// Loads and validates the bundled content. Failure is surfaced, never replaced with placeholders.
    static func load() -> Result<AppContent, Error> {
        Result {
            // Verse wording pasted in from Matt's licensed Bible replaces the free placeholders.
            let licensed = try LicensedVerses.decode(data("licensed-verses"))
            let library = try AnnotationLibrary.decode(data("annotations"))
            let maps = try ContextMaps.decode(data("maps"))
            return AppContent(library: library.applying(licensed),
                              script: try UnfoldScript.decode(data("unfold"), library: library).applying(licensed),
                              context: try ContextScript.decode(data("context"), library: library, maps: maps),
                              maps: maps,
                              zones: try TextZones.decode(data("textzones")).zones,
                              glints: try GlintPoints.decode(data("glints")),
                              notices: try Notices.decode(data("notices")),
                              delights: try DelightsContent.decode(data("delights")))
        }
    }

    private static func data(_ name: String) throws -> Data {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            throw AnnotationLibrary.ValidationError.invalid("\(name).json missing from app bundle")
        }
        return try Data(contentsOf: url)
    }
}
