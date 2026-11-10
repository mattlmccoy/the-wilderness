import XCTest

/// Drives the real app with Siri Remote presses. Each test starts with no saved calibration:
/// the empty argument-domain value makes the stored profile unreadable, so the app treats it as absent.
final class CalibrationFlowUITests: XCTestCase {
    private func launchUncalibrated() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-calibration.v1", ""]
        app.launch()
        return app
    }

    func testSelectWalksCornersThenSaves() {
        let app = launchUncalibrated()
        let remote = XCUIRemote.shared
        XCTAssertTrue(app.staticTexts["Top left · 1 of 4"].waitForExistence(timeout: 10))
        for _ in 0..<4 { remote.press(.select) }
        XCTAssertTrue(app.staticTexts["Check the outline"].waitForExistence(timeout: 3))
        remote.press(.select)
        XCTAssertFalse(app.staticTexts["Check the outline"].waitForExistence(timeout: 2), "Select on review should save and close")
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testBackOnReviewReturnsToLastCorner() {
        let app = launchUncalibrated()
        let remote = XCUIRemote.shared
        XCTAssertTrue(app.staticTexts["Top left · 1 of 4"].waitForExistence(timeout: 10))
        for _ in 0..<4 { remote.press(.select) }
        XCTAssertTrue(app.staticTexts["Check the outline"].waitForExistence(timeout: 3))
        remote.press(.menu)
        XCTAssertTrue(app.staticTexts["Bottom left · 4 of 4"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.state, .runningForeground)
    }
}
