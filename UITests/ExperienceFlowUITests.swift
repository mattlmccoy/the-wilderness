import XCTest

/// Drives the real app with Siri Remote presses, starting calibrated and in Stillness.
final class ExperienceFlowUITests: XCTestCase {
    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += SavedCalibration.args()
        app.launch()
        return app
    }
    private let remote = XCUIRemote.shared
    private func text(_ app: XCUIApplication, containing s: String) -> XCUIElement {
        app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", s)).firstMatch
    }

    func testArrowWakesExploreOnChrist() {
        let app = launch()
        remote.press(.right)
        XCTAssertTrue(app.staticTexts["Jesus Christ"].waitForExistence(timeout: 5))
    }

    func testSelectTogglesStoryAndItPersistsAcrossSubjects() {
        let app = launch()
        remote.press(.right)
        XCTAssertTrue(app.staticTexts["Jesus Christ"].waitForExistence(timeout: 5))
        remote.press(.select)
        XCTAssertTrue(text(app, containing: "He chose this weakness for us").waitForExistence(timeout: 4))
        remote.press(.up)
        XCTAssertTrue(text(app, containing: "Satan tempted Him with the promise of angels").waitForExistence(timeout: 5),
                      "the longer text should stay open on the next subject")
    }

    func testHoldSelectOpensSettingsWithoutTogglingText() {
        let app = launch()
        remote.press(.right)
        XCTAssertTrue(app.staticTexts["Jesus Christ"].waitForExistence(timeout: 5))
        remote.press(.select, forDuration: 1.2)
        XCTAssertTrue(app.staticTexts["Calibrate"].waitForExistence(timeout: 3))
        // If the release also counted as a Select, Settings would have opened Calibrate.
        XCTAssertFalse(app.staticTexts["Top left · 1 of 4"].waitForExistence(timeout: 1.5))
        XCTAssertTrue(app.staticTexts["Tune light"].exists && app.staticTexts["About"].exists)
    }

    func testPlayPauseStartsUnfold() {
        let app = launch()
        remote.press(.playPause)
        XCTAssertTrue(app.staticTexts["In the Beginning"].waitForExistence(timeout: 5))
    }

    func testBackReturnsToStillness() {
        let app = launch()
        remote.press(.right)
        XCTAssertTrue(app.staticTexts["Jesus Christ"].waitForExistence(timeout: 5))
        remote.press(.menu)
        XCTAssertFalse(app.staticTexts["Jesus Christ"].waitForExistence(timeout: 2.5))
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testPausedLineSitsUnderTheBeatTextOnScreen() {
        let app = launch()
        remote.press(.playPause)
        let title = app.staticTexts["In the Beginning"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        remote.press(.playPause)
        let paused = app.staticTexts["Paused"]
        XCTAssertTrue(paused.waitForExistence(timeout: 3))
        XCTAssertTrue(app.frame.contains(paused.frame), "Paused is off the frame: \(paused.frame)")
        XCTAssertLessThan(paused.frame.minY - title.frame.maxY, 250, "Paused is far from its text")
        XCTAssertGreaterThan(paused.frame.minY, title.frame.maxY)
    }

    func testShowPaintingToggles() {
        let app = launch()
        remote.press(.select, forDuration: 1.2)
        XCTAssertTrue(app.staticTexts["Calibrate"].waitForExistence(timeout: 3))
        for _ in 0..<3 { remote.press(.down) }
        let startsOn = app.staticTexts["Show painting · on"].exists
        let flipped = startsOn ? "Show painting · off" : "Show painting · on"
        let original = startsOn ? "Show painting · on" : "Show painting · off"
        remote.press(.select)
        XCTAssertTrue(app.staticTexts[flipped].waitForExistence(timeout: 2))
        remote.press(.select)   // restore what the viewer had
        XCTAssertTrue(app.staticTexts[original].waitForExistence(timeout: 2))
    }
}
