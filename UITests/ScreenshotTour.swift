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

    static var calibratedArgs: [String] {
        let json = #"{"version":1,"createdAt":0,"name":"Default","artworkAspect":1.2,"output":{"width":1920,"height":1080},"corners":[{"x":0.23,"y":0.1},{"x":0.77,"y":0.1},{"x":0.77,"y":0.9},{"x":0.23,"y":0.9}]}"#
        let hex = json.utf8.map { String(format: "%02x", $0) }.joined()
        return ["-calibration.v1", "<\(hex)>"]
    }

    func shot(_ name: String) {
        let png = XCUIScreen.main.screenshot().pngRepresentation
        try? png.write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
    }

    func launch(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += Self.calibratedArgs + extra
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
}
