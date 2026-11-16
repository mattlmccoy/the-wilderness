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
                    // Two columns, so every row fits on the canvas: the light, then the year.
                    HStack(alignment: .top, spacing: 60) {
                        VStack(alignment: .leading, spacing: 18) {
                            ForEach(TuningRow.lightRows, id: \.self) { r in row(TuningSession.label(r, t.tuning), focused: r == t.row) }
                        }
                        VStack(alignment: .leading, spacing: 18) {
                            hint("THROUGH THE YEAR")
                            ForEach(TuningRow.yearRows, id: \.self) { r in row(TuningSession.label(r, t.tuning), focused: r == t.row) }
                        }
                    }
                    hint("↑ ↓ choose   ·   ← → change   ·   ‹ done")
                }
            case .about:
                // Two columns, every credit wrapped in full (Matt, 2026-11-16: lines were cut off).
                LazyVGrid(columns: [GridItem(.fixed(500), spacing: 50, alignment: .topLeading),
                                    GridItem(.fixed(500), alignment: .topLeading)],
                          alignment: .leading, spacing: 16) {
                    ForEach(aboutLines, id: \.self) { hint($0) }
                }
            default:
                EmptyView()
            }
        }
        .frame(width: mode == .about || mode == .tuning ? 1060 : 560, alignment: .leading)
        .padding(.leading, 60).padding(.top, 140)
    }

    static func title(_ item: SettingsItem) -> String {
        switch item {
        case .calibrate: "Calibrate"
        case .tune: "Tune light"
        case .pattern: "Alignment pattern"
        case .painting: "Show painting"
        case .about: "About"
        case .demo: "Demo"
        }
    }

    private func row(_ s: String, focused: Bool) -> some View {
        Text(s)
            .font(Typography.text(Typography.Size.row))
            .foregroundStyle(Palette.ivory.opacity(focused ? 1 : 0.55))
    }

    private var aboutLines: [String] {
        let n = notices.notices.keys.sorted().map { notices.notices[$0]! }
        return (n.isEmpty ? ["Bible translation notices: none yet (no translation is quoted)."] : n)
            + ["Image: The Metropolitan Museum of Art, 11.53, public domain.",
               "Fonts: Cormorant Garamond and EB Garamond, SIL Open Font License.",
               "Sound: CC0 recordings from Freesound (zazz.sound.design, PhonZz, dersinnsspace)."]
            + credits
    }

    private func hint(_ s: String) -> some View {
        Text(s)
            .fixedSize(horizontal: false, vertical: true)
            .font(Typography.text(Typography.Size.citation + 2)).tracking(0.5).lineSpacing(4)
            .foregroundStyle(Palette.ivory.opacity(0.8))
    }
}
