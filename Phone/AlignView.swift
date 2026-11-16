import SwiftUI
import WildernessCore

/// Align the projection to the tapestry from the phone: the wall shows its alignment pattern,
/// this screen shows the eight handles (4 corners, 4 edge midpoints). Tap a handle, nudge it
/// with the arrows, Save. The wall's remote drives the very same session.
struct AlignView: View {
    @ObservedObject var client: CompanionClient
    @Environment(\.dismiss) private var dismiss
    /// While dragging: the handle follows the finger here at once; the wall follows over Wi-Fi.
    @State private var dragging: (point: AlignPoint, at: CGPoint)?
    @State private var lastSent = Date.distantPast

    private var state: AlignmentState? { client.snapshot?.alignment }

    var body: some View {
        VStack(spacing: 18) {
            Text(title).font(PhoneType.title(24))
            diagram
                .aspectRatio(16.0 / 9.0, contentMode: .fit)
                .padding(.horizontal, 12)
            Text("Drag the points onto the edge of the cloth; the diamonds bend an edge. If the gold outlines miss the printed figures, trim that edge below.")
                .font(PhoneType.text(15, italic: true)).foregroundStyle(PhonePalette.stone)
                .multilineTextAlignment(.center).padding(.horizontal, 24)
            arrows
            trim
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
            var pts = (state?.handles ?? []).map { CGPoint(x: $0.x * w, y: $0.y * h) }
            let _ = { if let d = dragging, pts.count == 8 { pts[d.point.rawValue] = d.at } }()
            ZStack {
                Rectangle().stroke(PhonePalette.stone.opacity(0.4), lineWidth: 1)
                    .contentShape(Rectangle())
                if pts.count == 8 {
                    // Each edge as the wall draws it: a smooth curve through its midpoint handle.
                    Path { p in
                        p.move(to: pts[0])
                        for i in stride(from: 0, to: 8, by: 2) {
                            let a = pts[i], m = pts[i + 1], b = pts[(i + 2) % 8]
                            p.addQuadCurve(to: b, control: CGPoint(x: 2 * m.x - (a.x + b.x) / 2, y: 2 * m.y - (a.y + b.y) / 2))
                        }
                    }
                    .stroke(PhonePalette.ivory.opacity(0.6), lineWidth: 1.2)
                    ForEach(AlignPoint.allCases, id: \.self) { point in
                        let selected = state?.selected == point
                        handle(point, selected: selected || dragging?.point == point)
                            .position(pts[point.rawValue])
                            .gesture(drag(point, size: geo.size))
                    }
                }
            }
            .coordinateSpace(name: "diagram")
        }
    }

    /// Drag a handle: it follows the finger here, and the wall moves with it (~20 updates a second).
    private func drag(_ point: AlignPoint, size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named("diagram"))
            .onChanged { g in
                let at = CGPoint(x: min(max(g.location.x, 0), size.width), y: min(max(g.location.y, 0), size.height))
                if dragging == nil { client.send(.align(.pick(point))) }
                dragging = (point, at)
                if Date().timeIntervalSince(lastSent) > 0.05 { send(point, at, size); lastSent = Date() }
            }
            .onEnded { g in
                if let d = dragging { send(point, d.at, size) }
                dragging = nil
            }
    }

    private func send(_ point: AlignPoint, _ at: CGPoint, _ size: CGSize) {
        client.send(.align(.place(point, Point(x: at.x / size.width, y: at.y / size.height))))
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

    /// Painting trim: how much painting the print lost at each edge. The handles stay on the
    /// cloth; this fits the painting inside it. Watch the gold outlines on the wall meet the print.
    private var trim: some View {
        let inches = state?.trimInches ?? Calibration.noTrim
        return VStack(spacing: 6) {
            Text("Painting trim").font(PhoneType.text(15, italic: true)).foregroundStyle(PhonePalette.stone)
            Grid(horizontalSpacing: 18, verticalSpacing: 6) {
                ForEach([[AlignEdge.top, .bottom], [.left, .right]], id: \.self) { row in
                    GridRow {
                        ForEach(row, id: \.self) { edge in trimStepper(edge, inches: inches[edge.rawValue]) }
                    }
                }
            }
        }
    }

    private func trimStepper(_ edge: AlignEdge, inches: Double) -> some View {
        HStack(spacing: 8) {
            Text(["Top", "Right", "Bottom", "Left"][edge.rawValue]).frame(width: 56, alignment: .leading)
            Button { client.send(.align(.trim(edge, -1))) } label: { Image(systemName: "minus.circle") }
                .buttonRepeatBehavior(.enabled)
                .accessibilityLabel("Less \(edge) trim")
            Text(String(format: "%.2f\u{2033}", inches)).monospacedDigit().frame(width: 50)
            Button { client.send(.align(.trim(edge, 1))) } label: { Image(systemName: "plus.circle") }
                .buttonRepeatBehavior(.enabled)
                .accessibilityLabel("More \(edge) trim")
        }
        .font(PhoneType.text(16))
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
