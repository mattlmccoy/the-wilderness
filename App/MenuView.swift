import SwiftUI
import WildernessCore

/// The front door (Select at rest): a short list in the text column beside the tapestry, in the
/// wall's own type. No boxes or icons; the focused line is simply brighter.
struct MenuView: View {
    let focus: MenuItem
    let calibration: Calibration
    var soundOn: Bool = false
    var soundAvailable: Bool = true
    var canvasZone: TextZone? = nil

    var body: some View {
        WallColumn(placement: TextColumnLayout.place(preferred: .left, calibration: calibration, canvasZone: canvasZone), anchorY: 0.3) {
            VStack(alignment: .leading, spacing: 0) {
                VStack(alignment: .leading, spacing: 40) {
                    ForEach(MenuItem.allCases.filter { $0 != .sound }, id: \.self) { item in
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
                // Sound is a setting, not a place: one smaller line under the three modes.
                Text(soundLabel)
                    .font(Typography.text(Typography.Size.short))
                    .tracking(1)
                    .foregroundStyle(Palette.ivory.opacity(focus == .sound ? 1 : 0.4))
                    .padding(.top, 44)
                    .accessibilityAddTraits(focus == .sound ? .isSelected : [])
            }
            .animation(.easeInOut(duration: 0.3), value: focus)
        }
    }

    private var soundLabel: String {
        guard soundAvailable else { return "Sound · unavailable" }
        return soundOn ? "Sound · on" : "Sound · off"
    }
}

extension MenuItem {
    var name: String {
        switch self {
        case .explore: "Explore"
        case .unfold: "Unfold"
        case .context: "Context"
        case .sound: "Sound"
        }
    }

    var line: String {
        switch self {
        case .explore: "one figure at a time"
        case .unfold: "the story, five minutes"
        case .context: "where it came from"
        case .sound: "a quiet wind"
        }
    }
}
