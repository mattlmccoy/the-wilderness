import XCTest

/// Drives the remote for the demo clips of the interactive delights while the simulator screen is
/// recorded from outside. Writes "<name> <unix seconds>" to marks.txt when each clip's action begins.
/// Skipped unless SCREENSHOT_DIR is set (TEST_RUNNER_SCREENSHOT_DIR=... xcodebuild test ...).
final class DemoClips: XCTestCase {
    var out = ""

    override func setUpWithError() throws {
        guard let dir = ProcessInfo.processInfo.environment["SCREENSHOT_DIR"], !dir.isEmpty else {
            throw XCTSkip("set TEST_RUNNER_SCREENSHOT_DIR to record the demo clips")
        }
        out = dir
    }

    func mark(_ name: String) {
        let line = "\(name) \(Date().timeIntervalSince1970)\n"
        let url = URL(fileURLWithPath: "\(out)/marks.txt")
        if let h = try? FileHandle(forWritingTo: url) { h.seekToEndOfFile(); h.write(Data(line.utf8)); h.closeFile() }
        else { try? line.write(to: url, atomically: true, encoding: .utf8) }
    }

    func launch(_ extra: [String] = []) {
        let app = XCUIApplication()
        app.launchArguments += SavedCalibration.args() + extra
        app.launch()
        sleep(3)
    }

    func test1Dreamcoat() {
        launch()
        let r = XCUIRemote.shared
        mark("dreamcoat")
        for b: XCUIRemote.Button in [.up, .up, .down, .down, .left, .right, .left, .right, .select] { r.press(b) }
        sleep(10)
    }

    func test2BeStill() {
        launch()
        let r = XCUIRemote.shared
        r.press(.select); sleep(1)
        mark("bestill")
        r.press(.down); r.press(.down); r.press(.down); sleep(1); r.press(.select)
        sleep(42)
    }

    func test3Reveal() {
        launch()
        let r = XCUIRemote.shared
        r.press(.select); sleep(1)
        r.press(.down); r.press(.down); r.press(.select); sleep(2)
        for _ in 0..<6 { r.press(.right); sleep(1) }
        mark("reveal")
        r.press(.right)
        sleep(9)
    }
}
