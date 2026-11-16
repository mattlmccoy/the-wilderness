import SwiftUI
import WildernessCore

/// Into the Quiet on the phone (docs/superpowers/specs/2026-11-16-prayer-mode-design.md): the start
/// screen, then a dark screen naming each movement, then the closing line. The Apple TV keeps the time;
/// this only shows what the wall reports.
struct PrayerView: View {
    @ObservedObject var client: CompanionClient
    @Environment(\.dismiss) private var dismiss
    @AppStorage("prayer.minutes") private var minutes = 10

    private var screen: PrayerScreen { client.snapshot.map(PrayerScreen.for) ?? .start }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch screen {
            case .start: start
            case let .session(movement): session(movement)
            case let .closing(text): closing(text)
            }
        }
        .foregroundStyle(PhonePalette.ivory)
        .animation(.easeInOut(duration: 1.2), value: screen)
        // The screen stays on (and black) through a session, so the closing line is seen.
        .onChange(of: screen) { _, s in
            if case .session = s { UIApplication.shared.isIdleTimerDisabled = true }
            else { UIApplication.shared.isIdleTimerDisabled = false }
            if case .closing = s { Task { try? await Task.sleep(for: .seconds(20)); dismiss() } }
        }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    // MARK: Start

    private var start: some View {
        let today = client.snapshot?.prayerToday
        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text((today?.period.label ?? "").uppercased()).font(PhoneType.text(13)).tracking(3).foregroundStyle(PhonePalette.stone)
                Spacer()
                Button { dismiss() } label: { Image(systemName: "xmark") }.accessibilityLabel("Close")
            }
            Text("Into the quiet").font(PhoneType.title(38))
            if let line = today?.line {
                VStack(alignment: .leading, spacing: 6) {
                    Text(line.text).font(PhoneType.text(22, italic: true)).lineSpacing(4)
                    Text("\(line.ref.uppercased())  ·  \(line.translation.rawValue)").font(PhoneType.text(13)).tracking(1.5)
                        .foregroundStyle(PhonePalette.stone)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                movementLine("Read", "it slowly, twice.")
                movementLine("Reflect", "on the word that stays.")
                movementLine("Respond", "in your own words.")
                movementLine("Rest", "in the silence.")
            }
            .font(PhoneType.text(18))
            Text("HOW LONG").font(PhoneType.text(13)).tracking(3).foregroundStyle(PhonePalette.stone)
            HStack(spacing: 10) {
                ForEach(Prayer.lengths, id: \.self) { m in
                    Button { minutes = m } label: {
                        Text("\(m) min").font(PhoneType.text(17)).padding(.horizontal, 12).padding(.vertical, 6)
                            .overlay(Capsule().stroke(m == minutes ? PhonePalette.gold : PhonePalette.stone.opacity(0.5)))
                            .foregroundStyle(m == minutes ? PhonePalette.gold : PhonePalette.ivory)
                    }
                    .accessibilityAddTraits(m == minutes ? .isSelected : [])
                }
            }
            Spacer()
            Button { client.send(.pray(minutes: minutes)) } label: {
                Text("Begin").font(PhoneType.text(22)).frame(maxWidth: .infinity).padding(.vertical, 12)
                    .overlay(Capsule().stroke(PhonePalette.gold)).foregroundStyle(PhonePalette.gold)
            }
            .disabled(client.link != .connected)
        }
        .padding(24)
    }

    private func movementLine(_ word: String, _ rest: String) -> some View {
        (Text(word).foregroundColor(PhonePalette.gold) + Text(" " + rest)).fixedSize(horizontal: false, vertical: true)
    }

    // MARK: During

    private func session(_ movement: Prayer.Movement) -> some View {
        let status = client.snapshot?.prayer
        return VStack(spacing: 16) {
            Spacer()
            if movement == .read, let line = status?.line {
                VStack(spacing: 8) {
                    Text(line.text).font(PhoneType.text(22, italic: true)).multilineTextAlignment(.center).lineSpacing(4)
                    Text("\(line.ref.uppercased())  ·  \(line.translation.rawValue)").font(PhoneType.text(13)).tracking(1.5)
                        .foregroundStyle(PhonePalette.stone)
                }
                .padding(.horizontal, 28)
            }
            Text(movement.title.uppercased()).font(PhoneType.text(15)).tracking(4).foregroundStyle(PhonePalette.gold.opacity(0.8))
            if let s = status { Text("\(s.index) of \(s.of)").font(PhoneType.text(13)).foregroundStyle(PhonePalette.stone.opacity(0.7)) }
            Spacer()
            Button { client.send(.endPrayer) } label: {
                Text("End").font(PhoneType.text(18)).frame(maxWidth: .infinity).padding(.vertical, 10)
                    .overlay(Capsule().stroke(PhonePalette.stone.opacity(0.35))).foregroundStyle(PhonePalette.stone.opacity(0.7))
            }
            .padding(.horizontal, 24).padding(.bottom, 20)
        }
        .opacity(movement == .read ? 1 : 0.85)
    }

    // MARK: After

    private func closing(_ text: String) -> some View {
        let parts = text.split(separator: " ", maxSplits: 1).map(String.init)
        return VStack(alignment: .leading, spacing: 8) {
            Text((parts.first ?? "").uppercased()).font(PhoneType.text(14)).tracking(3).foregroundStyle(PhonePalette.gold)
            Text(parts.count > 1 ? parts[1] : "").font(PhoneType.title(34))
        }
        .padding(24)
    }
}
