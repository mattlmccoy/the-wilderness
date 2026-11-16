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
        XCTAssertTrue(app.staticTexts["Top left · 1 of 8"].waitForExistence(timeout: 10))
        for _ in 0..<8 { remote.press(.select) }
        XCTAssertTrue(app.staticTexts["Check the outline"].waitForExistence(timeout: 3))
        remote.press(.select)
        XCTAssertFalse(app.staticTexts["Check the outline"].waitForExistence(timeout: 2), "Select on review should save and close")
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testBackOnReviewReturnsToLastCorner() {
        let app = launchUncalibrated()
        let remote = XCUIRemote.shared
        XCTAssertTrue(app.staticTexts["Top left · 1 of 8"].waitForExistence(timeout: 10))
        for _ in 0..<8 { remote.press(.select) }
        XCTAssertTrue(app.staticTexts["Check the outline"].waitForExistence(timeout: 3))
        remote.press(.menu)
        XCTAssertTrue(app.staticTexts["Left middle · 8 of 8"].waitForExistence(timeout: 3))
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// Recalibrating from Settings must hand the remote back: after the save (which plays the
    /// boot-up intro, so the intro is not skipped here) the arrows reach Explore again.
    func testRecalibratingFromSettingsThenArrowsReachExplore() {
        let app = XCUIApplication()
        app.launchArguments += SavedCalibration.args(skipIntro: false)
        app.launch()
        let remote = XCUIRemote.shared
        remote.press(.select)   // skips the launch intro to rest
        sleep(1)
        remote.press(.select, forDuration: 1.2)
        XCTAssertTrue(app.staticTexts["Calibrate"].waitForExistence(timeout: 3), "Settings did not open")
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Top left · 1 of 8"].waitForExistence(timeout: 5), "Calibrate did not open")
        for _ in 0..<8 { remote.press(.select) }
        let review = app.staticTexts["Check the outline"]
        XCTAssertTrue(review.waitForExistence(timeout: 3))
        remote.press(.select)   // save
        let closed = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: review)
        wait(for: [closed], timeout: 5)

        // The save plays the intro; the first press only skips it, so it must not explore.
        remote.press(.right)
        XCTAssertFalse(app.staticTexts["Jesus Christ"].waitForExistence(timeout: 2.5),
                       "the first press after saving should only skip the intro")
        remote.press(.right)
        XCTAssertTrue(app.staticTexts["Jesus Christ"].waitForExistence(timeout: 5),
                      "after recalibrating, an arrow no longer reaches Explore")
    }
}
