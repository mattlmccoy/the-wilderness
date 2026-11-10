import SwiftUI
import WildernessCore

/// Explore, drawn in artwork canvas units (1 unit ≈ 0.05 in on the wall; 20 units ≈ 1 in).
/// Soft light rests on the selected detail (LightLayer); its text (WallText) sits on the bare
/// wall beside the tapestry. Text is placed outside the canvas bounds on purpose: the same
/// homography carries it onto the wall plane, so it is perspective-correct too.
struct ExploreView: View {
    let library: AnnotationLibrary
    let state: ExploreState
    let calibration: Calibration

    private var selected: (Annotation, Bool)? {
        guard case let .exploring(id, expanded) = state,
              let a = library.annotations.first(where: { $0.id == id }) else { return nil }
        return (a, expanded)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            LightLayer(library: library, tuning: .defaults, targets: targets, exploring: selected != nil)
            if case let (a, expanded)? = selected {
                WallText(title: a.title, short: a.short, more: a.more, fallbackExtended: a.extended,
                         expanded: expanded,
                         placement: TextColumnLayout.place(preferred: a.textSide, calibration: calibration),
                         anchorY: a.anchor.y)
                    .id(a.id)
                    .transition(.asymmetric(
                        insertion: .opacity.animation(.easeIn(duration: LightTiming.textIn).delay(LightTiming.textDelay)),
                        removal: .opacity.animation(.easeOut(duration: LightTiming.textOut))))
            }
        }
        .animation(.easeInOut(duration: LightTiming.textOut), value: state)
    }

    private var targets: Set<String> {
        if case let .exploring(id, _) = state { return [id] }
        return []
    }
}

/// Everything the app reads from its bundle.
struct AppContent {
    let library: AnnotationLibrary
    let script: UnfoldScript
    let glints: GlintPoints
}

enum ContentLoader {
    /// Loads and validates the bundled content. Failure is surfaced, never replaced with placeholders.
    static func load() -> Result<AppContent, Error> {
        Result {
            let library = try AnnotationLibrary.decode(data("annotations"))
            return AppContent(library: library,
                              script: try UnfoldScript.decode(data("unfold"), library: library),
                              glints: try GlintPoints.decode(data("glints")))
        }
    }

    private static func data(_ name: String) throws -> Data {
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            throw AnnotationLibrary.ValidationError.invalid("\(name).json missing from app bundle")
        }
        return try Data(contentsOf: url)
    }
}
