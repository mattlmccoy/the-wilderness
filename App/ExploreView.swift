import SwiftUI
import WildernessCore

/// Explore, drawn in artwork canvas units (1 unit ≈ 0.05 in on the wall; 20 units ≈ 1 in).
/// A pool of warm light rests on the selected detail; its text sits on the bare wall beside
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
            Color.clear.frame(width: canvas.width, height: canvas.height)
            if case let (a, expanded)? = selected {
                lightPool(at: a.anchor)
                text(for: a, expanded: expanded)
                    .id(a.id)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 1.4), value: state)
    }

    private func lightPool(at p: Point<ArtworkSpace>) -> some View {
        let r: CGFloat = 150
        return Circle()
            .fill(RadialGradient(colors: [Palette.ivory.opacity(0.42), Palette.ivory.opacity(0.12), .clear],
                                 center: .center, startRadius: 0, endRadius: r))
            .frame(width: 2 * r, height: 2 * r)
            .position(x: p.x * canvas.width, y: p.y * canvas.height)
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
                .font(.system(size: 40, weight: .regular, design: .serif))
                .foregroundStyle(Palette.ivory)
            Text(a.short)
                .font(.system(size: 22, design: .serif)).italic()
                .foregroundStyle(Palette.ivory.opacity(0.8))
            if expanded {
                Text(a.extended)
                    .font(.system(size: 19, design: .serif)).lineSpacing(6)
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

enum ContentLoader {
    /// Loads the bundled annotations. Failure is surfaced, never replaced with placeholder content.
    static func load() -> Result<AnnotationLibrary, Error> {
        guard let url = Bundle.main.url(forResource: "annotations", withExtension: "json") else {
            return .failure(AnnotationLibrary.ValidationError.invalid("annotations.json missing from app bundle"))
        }
        return Result { try AnnotationLibrary.decode(Data(contentsOf: url)) }
    }
}
