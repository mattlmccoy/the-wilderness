import SwiftUI
import WildernessCore

/// The front door (Select at rest): a short list in the text column beside the tapestry, in the
/// wall's own type. No boxes or icons; the focused line is simply brighter.
struct MenuView: View {
    let focus: MenuItem
    let calibration: Calibration

    var body: some View {
        WallColumn(placement: TextColumnLayout.place(preferred: .left, calibration: calibration), anchorY: 0.3) {
            VStack(alignment: .leading, spacing: 40) {
                ForEach(MenuItem.allCases, id: \.self) { item in
                    let on = item == focus
                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.name)
                            .font(Typography.title())
                            .foregroundStyle(Palette.ivory.opacity(on ? 1 : 0.4))
                        Text(item.line)
                            .font(Typography.text(Typography.Size.story, italic: true))
                            .foregroundStyle(Palette.ivory.opacity(on ? 0.85 : 0.3))
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .animation(.easeInOut(duration: 0.3), value: focus)
        }
    }
}

extension MenuItem {
    var name: String {
        switch self {
        case .explore: "Explore"
        case .unfold: "Unfold"
        }
    }

    var line: String {
        switch self {
        case .explore: "one figure at a time"
        case .unfold: "the story, five minutes"
        }
    }
}
