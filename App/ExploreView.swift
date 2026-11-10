import SwiftUI
import WildernessCore

/// Explore, drawn in artwork canvas units (1 unit ≈ 0.05 in on the wall; 20 units ≈ 1 in).
/// Soft light rests on the selected detail (LightLayer); its text sits on the bare wall beside
/// the tapestry. Text is placed outside the canvas bounds on purpose: the same homography
/// carries it onto the wall plane, so it is perspective-correct too.
struct ExploreView: View {
    let library: AnnotationLibrary
    let state: ExploreState

    private let canvas = CGSize(width: Artwork.canvasWidth, height: Artwork.canvasHeight)
    private let column: CGFloat = 380
    private let gap: CGFloat = 70

    private var selected: (Annotation, Bool)? {
        guard case let .exploring(id, expanded) = state,
              let a = library.annotations.first(where: { $0.id == id }) else { return nil }
        return (a, expanded)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            LightLayer(library: library, tuning: .defaults, targets: targets, exploring: selected != nil)
            if case let (a, expanded)? = selected {
                text(for: a, expanded: expanded)
                    .id(a.id)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 1.4), value: state)
    }

    private var targets: Set<String> {
        if case let .exploring(id, _) = state { return [id] }
        return []
    }

    private func text(for a: Annotation, expanded: Bool) -> some View {
        let right = a.textSide == .right
        let x = right ? canvas.width + gap : -gap - column
        let y = min(max(a.anchor.y * canvas.height - 90, 0), canvas.height - 460)
        // Always left-aligned: ragged-left paragraphs are hard to read. Only the column's
        // position changes with the side, so it always hugs the tapestry.
        return VStack(alignment: .leading, spacing: 14) {
            Text(evidenceLabel(a.evidence).uppercased())
                .font(.system(size: 13, weight: .semibold)).tracking(3)
                .foregroundStyle(Palette.gold.opacity(0.85))
            Text(a.title)
                .font(Typography.title())
                .foregroundStyle(Palette.ivory)
            Text(a.short)
                .font(Typography.text(Typography.Size.short, italic: true))
                .foregroundStyle(Palette.ivory.opacity(0.8))
            if expanded {
                Text(a.extended)
                    .font(Typography.text(Typography.Size.story)).lineSpacing(6)
                    .foregroundStyle(Palette.ivory.opacity(0.7))
                    .transition(.opacity)
                Text(a.references.joined(separator: "  ·  "))
                    .font(.system(size: 13, weight: .medium)).tracking(1.2)
                    .foregroundStyle(Palette.stone.opacity(0.8))
            }
        }
        .multilineTextAlignment(.leading)
        .frame(width: column, alignment: .leading)
        .offset(x: x, y: y)
    }

    private func evidenceLabel(_ e: Evidence) -> String {
        switch e {
        case .documented: "Documented"
        case .iconographicTradition: "Christian tradition"
        case .plausible: "A likely reading"
        case .speculative: "Conjecture"
        }
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
