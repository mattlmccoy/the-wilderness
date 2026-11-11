import SwiftUI
import WildernessCore

/// Text drawn as light on the wall beside the tapestry (spec §5.2, §6.1, §7), in artwork canvas
/// units. Title, short line, and on the second press the story and its verses (Old Testament
/// first), each verse with its own small citation. No labels, no other references.
struct WallText: View {
    let title: String
    let short: String
    let more: More?
    /// Temporary until the copy pass: shown as the story when `more` is missing.
    let fallbackExtended: String?
    let expanded: Bool
    let placement: ColumnPlacement
    /// Vertical position of the subject, 0…1 in the artwork.
    let anchorY: Double
    /// Unfold only: a small "Paused" line under the text.
    var paused: Bool = false
    /// Faint "you are here" line above the title, e.g. "UNFOLD · 2 of 8".
    var header: String? = nil
    /// One-line remote hint under the text, shown for a few seconds after entering from the menu.
    var hint: String? = nil

    var body: some View {
        WallColumn(placement: placement, anchorY: anchorY) { content }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let header { Wayfinding.header(header) }
            Text(title)
                .font(Typography.title())
                .foregroundStyle(Palette.ivory)
            Text(short)
                .font(Typography.text(Typography.Size.short, italic: true))
                .foregroundStyle(Palette.ivory.opacity(0.95))
            if expanded {
                VStack(alignment: .leading, spacing: 22) {
                    if let story = more?.story ?? fallbackExtended {
                        Text(story)
                            .font(Typography.text(Typography.Size.story)).lineSpacing(6)
                            .foregroundStyle(Palette.ivory.opacity(0.9))
                    }
                    ForEach(orderedVerses, id: \.ref) { v in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(v.text)
                                .font(Typography.text(Typography.Size.verse)).lineSpacing(5)
                                .foregroundStyle(Palette.ivory.opacity(0.95))
                            Text("\(v.ref) · \(v.translation.rawValue)")
                                .font(Typography.text(Typography.Size.citation)).tracking(1.5)
                                .foregroundStyle(Palette.ivory.opacity(0.75))
                        }
                    }
                }
                .padding(.top, 8)
                .transition(.opacity.animation(.easeInOut(duration: LightTiming.textIn)))
            }
            if paused {
                Text("Paused")
                    .font(Typography.text(Typography.Size.citation)).tracking(1.5)
                    .foregroundStyle(Palette.ivory.opacity(0.75))
                    .padding(.top, 6)
                    .transition(.opacity)
            }
            if let hint {
                Wayfinding.hint(hint)
                    .padding(.top, 10)
                    .transition(.opacity.animation(.easeInOut(duration: LightTiming.textOut)))
            }
        }
        .animation(.easeInOut(duration: LightTiming.textOut), value: hint)
        .multilineTextAlignment(.leading)
        // Never truncate wall text: take the full height the words need.
        .fixedSize(horizontal: false, vertical: true)
    }

    private var orderedVerses: [Verse] {
        (more?.verses ?? []).sorted { ($0.testament == .old ? 0 : 1) < ($1.testament == .old ? 0 : 1) }
    }
}
