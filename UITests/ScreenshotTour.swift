import XCTest

/// Visual checks: drives the remote and saves screenshots for review. Skipped unless a folder is
/// given in the environment:  TEST_RUNNER_SCREENSHOT_DIR=/path/to/folder xcodebuild test ... -only-testing:WildernessUITests/ScreenshotTour
final class ScreenshotTour: XCTestCase {
    var out = ""

    override func setUpWithError() throws {
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty else {
            throw XCTSkip("set TEST_RUNNER_SCREENSHOT_DIR to run the screenshot tour")
        }
        out = dir
    }

    static var calibratedArgs: [String] { SavedCalibration.args() }
    static func args(x0: Double, x1: Double) -> [String] { SavedCalibration.args(x0: x0, x1: x1) }

    func shot(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
    }

    func launch(_ extra: [String] = [], calibration: [String] = ScreenshotTour.calibratedArgs) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += calibration + extra
        app.launch()
        sleep(2)
        return app
    }

    /// The boot-up intro, launched without -skipIntro: outlines drawing, softening, fading.
    func testIntro() {
        let app = XCUIApplication()
        app.launchArguments += SavedCalibration.args(skipIntro: false)
        app.launch()
        let start = Date()
        // Times are from launch() returning; the intro itself began about a second earlier.
        for (name, at) in [("intro-00s", 0.0), ("intro-01s", 1.0), ("intro-03s", 3.0), ("intro-07s", 7.0),
                           ("intro-10s", 10.0), ("intro-11s", 11.0), ("intro-14s", 14.0), ("intro-17s", 17.0)] {
            let wait = at - Date().timeIntervalSince(start)
            if wait > 0 { usleep(UInt32(wait * 1_000_000)) }
            shot(name)
        }
    }

    /// The menu and the first seconds of Explore (collapsed: no verse text in these shots).
    func testMenu() {
        _ = launch()
        let r = XCUIRemote.shared
        r.press(.select); sleep(2); shot("menu-0-explore")
        r.press(.down); sleep(1); shot("menu-1-unfold")
        r.press(.up); r.press(.select); sleep(4); shot("menu-2-explore-hint")
        sleep(5); shot("menu-3-hint-faded")
    }

    /// Every Context page (no verse text on these screens).
    func testContext() {
        _ = launch()
        let r = XCUIRemote.shared
        r.press(.select); sleep(1)
        r.press(.down); r.press(.down); r.press(.select); sleep(4); shot("context-1")
        for i in 2...5 { r.press(.right); sleep(i == 2 ? 5 : 4); shot("context-\(i)") }
    }

    func testLight() {
        _ = launch()
        let r = XCUIRemote.shared
        shot("light-0-stillness")
        r.press(.right); sleep(4); shot("light-1-christ")
        r.press(.up); sleep(3); shot("light-2-angels")
        for _ in 0..<5 { r.press(.left) }
        usleep(500_000); shot("light-3-rapid")
        sleep(3); shot("light-4-rapid-settled")
    }

    func testText() {
        _ = launch()
        let r = XCUIRemote.shared
        r.press(.right); sleep(4); shot("text-1-christ")
        r.press(.select); sleep(2); shot("text-2-christ-expanded")
    }

    func testNarrowWall() {
        _ = launch(calibration: Self.args(x0: 0.05, x1: 0.95))
        XCUIRemote.shared.press(.right); sleep(4); shot("text-3-narrow")
    }

    func testSettings() {
        _ = launch()
        let r = XCUIRemote.shared
        r.press(.select, forDuration: 1.2); sleep(1); shot("settings-1-list")
        r.press(.down); r.press(.select); sleep(3); shot("settings-2-tuning")
        r.press(.menu); r.press(.down); r.press(.down); r.press(.select); sleep(1); shot("settings-3-about")
    }

    func testUnfold() {
        _ = launch()
        XCUIRemote.shared.press(.playPause)
        sleep(2); shot("unfold-1-2s")
        sleep(38); shot("unfold-2-40s")
        sleep(35); shot("unfold-3-75s")
    }

    func testPainting() {
        _ = launch()
        let r = XCUIRemote.shared
        r.press(.select, forDuration: 1.2); sleep(1)
        for _ in 0..<3 { r.press(.down) }
        r.press(.select); r.press(.menu); sleep(2)
        r.press(.right); sleep(4); shot("painting-1-christ")
        r.press(.select, forDuration: 1.2); sleep(1)
        for _ in 0..<3 { r.press(.down) }
        r.press(.select)   // leave it off afterwards
    }

    /// Matt's wall: 87 in wide, tapestry 60 in centred (13.5 in each side).
    func testMattsWall() {
        _ = launch(calibration: Self.args(x0: 13.5 / 87, x1: 73.5 / 87))
        let r = XCUIRemote.shared
        r.press(.right); sleep(4); r.press(.select); sleep(3); shot("wall-1-christ-expanded")
        r.press(.left); sleep(4); shot("wall-2-left-expanded")
    }

    /// Matt's wall, largest texts expanded: Jesus Christ, then the pelican and the serpent.
    func testBigText() {
        _ = launch(calibration: Self.args(x0: 13.5 / 87, x1: 73.5 / 87))
        let r = XCUIRemote.shared
        r.press(.right); sleep(4); r.press(.select); sleep(3); shot("big-1-christ")
        r.press(.up); sleep(4); shot("big-2-next")
        r.press(.down); r.press(.down); sleep(4); shot("big-3-down")
    }
}
