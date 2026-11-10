import SwiftUI

@main
struct WildernessApp: App {
    init() { Typography.registerBundledFonts() }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
