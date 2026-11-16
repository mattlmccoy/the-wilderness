import XCTest

/// End to end: the Apple TV app must already be running (on a simulator or device on this
/// network). The phone finds it, taps Christ on the painting, and the wall's answer comes back.
/// Checks titles only: the read-along also shows licensed verse text, which tests never read.
final class CompanionRoundTripUITests: XCTestCase {
    /// Simulators cannot advertise over Bonjour on this Mac, so tests connect directly to the
    /// Apple TV simulator launched with `-companionPort 52741`. Real devices use Bonjour.
    static let direct = ["-companionHost", "127.0.0.1:52741"]

    func testTappingChristOnThePhoneShowsHimOnTheWallAndBack() throws {
        let app = XCUIApplication()
        app.launchArguments += Self.direct
        app.launch()
        let looking = app.staticTexts["Looking for The Wilderness…"]
        let connected = NSPredicate(format: "exists == false")
        expectation(for: connected, evaluatedWith: looking)
        waitForExpectations(timeout: 20)
        let painting = app.otherElements["The painting. Tap a figure to show it on the wall."].firstMatch
        let target = painting.exists ? painting : app.images.firstMatch
        XCTAssertTrue(target.waitForExistence(timeout: 5), "painting not shown")
        // Christ sits at about (0.75, 0.55) of the painting (Matt's trace: x 0.58–0.91, y 0.26–0.76).
        target.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.55)).tap()
        XCTAssertTrue(app.staticTexts["Jesus Christ"].waitForExistence(timeout: 8),
                      "the wall's answer did not come back")
        XCTAssertTrue(app.staticTexts["EXPLORE"].exists)
    }

    func testContextFromThePhoneComesBackAsAPage() throws {
        let app = XCUIApplication()
        app.launchArguments += Self.direct
        app.launch()
        XCTAssertTrue(app.buttons["Context"].waitForExistence(timeout: 20))
        let enabled = NSPredicate(format: "isEnabled == true")
        expectation(for: enabled, evaluatedWith: app.buttons["Context"])
        waitForExpectations(timeout: 20)
        app.buttons["Context"].tap()
        XCTAssertTrue(app.staticTexts["Into the Wilderness"].waitForExistence(timeout: 8))
    }
}
