import XCTest

/// Visual check of the phone screens (no verse text: rest, Context and Settings only).
/// Skipped unless TEST_RUNNER_SCREENSHOT_DIR is set. Needs the Apple TV app on `-companionPort 52741`.
final class PhoneScreenshotTour: XCTestCase {
    func testPhoneScreens() throws {
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty else {
            throw XCTSkip("set TEST_RUNNER_SCREENSHOT_DIR to run the phone screenshot tour")
        }
        func shot(_ name: String) {
            try? XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(dir)/\(name).png"))
        }
        let app = XCUIApplication()
        app.launchArguments += CompanionRoundTripUITests.direct
        app.launch()
        XCTAssertTrue(app.buttons["Context"].waitForExistence(timeout: 20))
        sleep(3); shot("phone-0-rest")
        app.buttons["Context"].tap()
        XCTAssertTrue(app.staticTexts["Into the Wilderness"].waitForExistence(timeout: 8))
        sleep(2); shot("phone-1-context")
        app.buttons["Settings"].tap()
        sleep(2); shot("phone-2-settings")
    }
}
