import AppIntents
import Foundation
import WildernessCore

/// Siri and Shortcuts on the phone (2026-11-16): "Start the Wilderness demo", "Wilderness light
/// only", "Wilderness flashlight". Each opens the app, which sends the command to the wall as soon
/// as it is connected (PhoneRootView reads `IntentInbox`).
@MainActor
final class IntentInbox {
    static let shared = IntentInbox()
    static let arrived = Notification.Name("WildernessIntentArrived")
    enum Request: Equatable { case demo, lightOnly, flashlight }
    var pending: Request?

    func post(_ r: Request) {
        pending = r
        NotificationCenter.default.post(name: Self.arrived, object: nil)
    }
}

struct StartDemoIntent: AppIntent {
    static let title: LocalizedStringResource = "Start the demo"
    static let description = IntentDescription("Starts the demo on the wall (about a minute and a half).")
    static let openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult { IntentInbox.shared.post(.demo); return .result() }
}

struct LightOnlyIntent: AppIntent {
    static let title: LocalizedStringResource = "Light only"
    static let description = IntentDescription("Hides the wall's text while exploring.")
    static let openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult { IntentInbox.shared.post(.lightOnly); return .result() }
}

struct FlashlightIntent: AppIntent {
    static let title: LocalizedStringResource = "Flashlight"
    static let description = IntentDescription("Turns the phone into a flashlight for the painting.")
    static let openAppWhenRun = true
    @MainActor func perform() async throws -> some IntentResult { IntentInbox.shared.post(.flashlight); return .result() }
}

struct WildernessShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: StartDemoIntent(), phrases: ["Start the \(.applicationName) demo", "Start \(.applicationName)"],
                    shortTitle: "Start the demo", systemImageName: "play.circle")
        AppShortcut(intent: LightOnlyIntent(), phrases: ["\(.applicationName) light only", "Hide the text in \(.applicationName)"],
                    shortTitle: "Light only", systemImageName: "eye.slash")
        AppShortcut(intent: FlashlightIntent(), phrases: ["\(.applicationName) flashlight"],
                    shortTitle: "Flashlight", systemImageName: "flashlight.on.fill")
    }
}
