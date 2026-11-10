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
}
