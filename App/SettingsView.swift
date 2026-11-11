import SwiftUI
import WildernessCore

/// The hidden Settings list and its screens (spec §5.4), drawn small and plain on the wall in
/// artwork canvas units. Only visible while open.
struct SettingsView: View {
    let mode: Mode
    let tuning: TuningSession?
    let notices: Notices
    let showPainting: Bool
    /// Context: the map data's source and every photograph's licence credit.
    var credits: [String] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            switch mode {
            case .settings(let focus):
                ForEach(SettingsItem.allCases, id: \.self) { item in
                    row(item == .painting ? "Show painting · \(showPainting ? "on" : "off")" : Self.title(item),
                        focused: item == focus)
                }
            case .tuning:
                if let t = tuning {
                    ForEach(TuningRow.allCases, id: \.self) { r in
                        row(TuningSession.label(r, t.tuning), focused: r == t.row)
                    }
                    hint("↑ ↓ choose   ·   ← → change   ·   ‹ done")
                }
            case .about:
                ForEach(notices.notices.keys.sorted(), id: \.self) { k in hint(notices.notices[k]!) }
                if notices.notices.isEmpty { hint("Bible translation notices: none yet (no translation is quoted).") }
                hint("Image: The Metropolitan Museum of Art, 11.53, public domain.")
                hint("Fonts: Cormorant Garamond and EB Garamond, SIL Open Font License.")
                ForEach(credits, id: \.self) { hint($0) }
            default:
                EmptyView()
            }
        }
        .frame(width: 560, alignment: .leading)
        .padding(.leading, 60).padding(.top, 140)
    }

    static func title(_ item: SettingsItem) -> String {
        switch item {
        case .calibrate: "Calibrate"
        case .tune: "Tune light"
        case .pattern: "Alignment pattern"
        case .painting: "Show painting"
        case .about: "About"
        }
    }

    private func row(_ s: String, focused: Bool) -> some View {
        Text(s)
            .font(Typography.text(Typography.Size.short))
            .foregroundStyle(Palette.ivory.opacity(focused ? 0.92 : 0.4))
    }

    private func hint(_ s: String) -> some View {
        Text(s)
            .font(Typography.text(Typography.Size.citation + 2)).tracking(0.5).lineSpacing(4)
            .foregroundStyle(Palette.ivory.opacity(0.55))
    }
}
