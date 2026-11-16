import SwiftUI
import WildernessCore

/// Align the projection to the tapestry from the phone: the wall shows its alignment pattern,
/// this screen shows the eight handles (4 corners, 4 edge midpoints). Tap a handle, nudge it
/// with the arrows, Save. The wall's remote drives the very same session.
struct AlignView: View {
    @ObservedObject var client: CompanionClient
    @Environment(\.dismiss) private var dismiss

    private var state: AlignmentState? { client.snapshot?.alignment }

    var body: some View {
        VStack(spacing: 18) {
            Text(title).font(PhoneType.title(24))
            diagram
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .padding(.horizontal, 12)
            Text("Tap a point, then nudge it until the line sits on the edge of the weave. The diamonds bend an edge.")
                .font(PhoneType.text(15, italic: true)).foregroundStyle(PhonePalette.stone)
                .multilineTextAlignment(.center).padding(.horizontal, 24)
            arrows
            Toggle("Fine steps", isOn: Binding(get: { state?.fine ?? false },
                                               set: { _ in client.send(.align(.toggleFine)) }))
                .padding(.horizontal, 40)
            HStack(spacing: 40) {
                Button("Cancel") { client.send(.align(.cancel)); dismiss() }
                Button("Save") { client.send(.align(.save)); dismiss() }.bold()
            }
            .font(PhoneType.text(20))
        }
        .padding(.vertical, 20)
        .tint(PhonePalette.gold)
        .foregroundStyle(PhonePalette.ivory)
        .background(Color.black.ignoresSafeArea())
        .disabled(state == nil)
        .onAppear { client.send(.align(.start)) }
    }

    private var title: String {
        guard let s = state, let p = s.selected else { return "Align" }
        return "\(p.label) · \(p.rawValue + 1) of 8"
    }

    /// The wall's frame in miniature: the outline through the eight handles, and the handles.
    private var diagram: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let pts = (state?.handles ?? []).map { CGPoint(x: $0.x * w, y: $0.y * h) }
            ZStack {
                Rectangle().stroke(PhonePalette.stone.opacity(0.4), lineWidth: 1)
                if pts.count == 8 {
                    Path { p in p.addLines(pts); p.closeSubpath() }
                        .stroke(PhonePalette.ivory.opacity(0.6), lineWidth: 1.2)
                    ForEach(AlignPoint.allCases, id: \.self) { point in
                        let selected = state?.selected == point
                        handle(point, selected: selected)
                            .position(pts[point.rawValue])
                            .onTapGesture { client.send(.align(.pick(point))) }
                    }
                }
            }
        }
    }

    private func handle(_ point: AlignPoint, selected: Bool) -> some View {
        let color = selected ? PhonePalette.gold : PhonePalette.ivory.opacity(0.7)
        return ZStack {
            Color.clear.frame(width: 44, height: 44).contentShape(Rectangle())   // easy to tap
            if point.edge == nil {
                Circle().stroke(color, lineWidth: selected ? 2.5 : 1.5).frame(width: selected ? 22 : 14)
            } else {
                Rectangle().stroke(color, lineWidth: selected ? 2.5 : 1.5)
                    .frame(width: selected ? 16 : 10, height: selected ? 16 : 10).rotationEffect(.degrees(45))
            }
        }
        .accessibilityLabel(point.label)
    }

    private var arrows: some View {
        let b = { (d: NudgeDirection, icon: String) in
            Button { client.send(.align(.move(d))) } label: {
                Image(systemName: icon).font(.system(size: 28)).frame(width: 64, height: 56)
            }
            .buttonRepeatBehavior(.enabled)   // hold to keep nudging
            .accessibilityLabel("Move \(icon.replacingOccurrences(of: "arrow.", with: ""))")
        }
        return VStack(spacing: 4) {
            b(.up, "arrow.up")
            HStack(spacing: 40) { b(.left, "arrow.left"); b(.right, "arrow.right") }
            b(.down, "arrow.down")
        }
    }
}
