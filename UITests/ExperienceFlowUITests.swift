import XCTest

/// Drives the real app with Siri Remote presses, starting calibrated and in Stillness.
final class ExperienceFlowUITests: XCTestCase {
    private func launch(skipIntro: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += SavedCalibration.args(skipIntro: skipIntro)
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

    func testBackGoesUpToTheMenuThenToRest() {
        let app = launch()
        remote.press(.right)
        XCTAssertTrue(app.staticTexts["Jesus Christ"].waitForExistence(timeout: 5))
        remote.press(.menu)
        XCTAssertTrue(app.staticTexts["Explore"].waitForExistence(timeout: 3), "Back should open the menu")
        XCTAssertFalse(app.staticTexts["Jesus Christ"].exists)
        remote.press(.menu)
        XCTAssertFalse(app.staticTexts["Explore"].waitForExistence(timeout: 2.5), "second Back should rest")
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testSelectAtRestOpensTheMenuAndEntersExploreWithAHint() {
        let app = launch()
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Explore"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["Unfold"].exists)
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Jesus Christ"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["EXPLORE"].exists, "no you-are-here line")
        XCTAssertTrue(text(app, containing: "Back to return").exists, "no hint after entering from the menu")
        sleep(8)
        XCTAssertFalse(text(app, containing: "Back to return").exists, "hint should fade after ~6 s")
    }

    func testMenuDownSelectStartsUnfoldWithItsPlace() {
        let app = launch()
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["Unfold"].waitForExistence(timeout: 3))
        remote.press(.down)
        remote.press(.select)
        XCTAssertTrue(app.staticTexts["In the Beginning"].waitForExistence(timeout: 5))
        XCTAssertTrue(text(app, containing: "UNFOLD · 1 of ").exists)
    }

    func testHoldSelectAtRestOpensSettingsNotTheMenu() {
        let app = launch()
        remote.press(.select, forDuration: 1.2)
        XCTAssertTrue(app.staticTexts["Calibrate"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.staticTexts["Unfold"].exists, "the menu opened under Settings")
        remote.press(.menu)
    }

    func testArrowShortcutSkipsTheHint() {
        let app = launch()
        remote.press(.right)
        XCTAssertTrue(app.staticTexts["Jesus Christ"].waitForExistence(timeout: 5))
        XCTAssertFalse(text(app, containing: "Back to return").exists)
    }

    /// Licensed verses replace the BSB placeholders. Checks citations only ("ref · NIV"), so the
    /// licensed wording itself is never read or printed by the test.
    func testExpandedVersesCiteTheLicensedTranslation() {
        let app = launch()
        remote.press(.right)
        XCTAssertTrue(app.staticTexts["Jesus Christ"].waitForExistence(timeout: 5))
        remote.press(.select)
        XCTAssertTrue(text(app, containing: " · NIV").waitForExistence(timeout: 3), "no NIV citation shown")
        XCTAssertFalse(text(app, containing: " · BSB").exists, "a BSB placeholder is still shown")
        remote.press(.select)   // leave the text collapsed for the next test
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
        // Directly under the column's last line (the beat's last verse citation), not far below it.
        let lastLine = text(app, containing: "Genesis 1:28 · ")
        XCTAssertTrue(lastLine.exists)
        XCTAssertGreaterThan(paused.frame.minY, lastLine.frame.maxY - 1)
        XCTAssertLessThan(paused.frame.minY - lastLine.frame.maxY, 60, "Paused is far from its text")
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

    // MARK: - Boot-up intro: any press skips it to rest, and does nothing else.

    func testSelectDuringTheIntroSkipsToRestWithoutOpeningTheMenu() {
        let app = launch(skipIntro: false)
        remote.press(.select)
        XCTAssertFalse(app.staticTexts["Explore"].waitForExistence(timeout: 2.5), "the skipping press opened the menu")
        remote.press(.right)   // at rest, an arrow explores Christ
        XCTAssertTrue(app.staticTexts["Jesus Christ"].waitForExistence(timeout: 5), "the intro was not skipped to rest")
    }

    func testArrowDuringTheIntroSkipsToRestWithoutExploring() {
        let app = launch(skipIntro: false)
        remote.press(.right)
        XCTAssertFalse(app.staticTexts["Jesus Christ"].waitForExistence(timeout: 2.5), "the skipping press entered Explore")
        remote.press(.select)  // at rest, Select opens the menu
        XCTAssertTrue(app.staticTexts["Explore"].waitForExistence(timeout: 3), "the intro was not skipped to rest")
        XCTAssertTrue(app.staticTexts["Unfold"].exists)
    }

    func testTheIntroEndsAtRestByItself() {
        let app = launch(skipIntro: false)
        sleep(17)
        remote.press(.select)  // if the intro were still playing, this would only skip it
        XCTAssertTrue(app.staticTexts["Explore"].waitForExistence(timeout: 3), "not at rest after the intro")
    }
}
