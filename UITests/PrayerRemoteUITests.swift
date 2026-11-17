import Network
import XCTest

/// Into the Quiet: the remote's Menu button during a session must reach the app and end the session,
/// never fall through to tvOS (which would put the Home screen on the tapestry). Final review, 2026-11-16.
final class PrayerRemoteUITests: XCTestCase {
    static let port: UInt16 = 52790

    /// Sends phone commands to the wall (newline JSON over TCP) and returns the snapshot it answers
    /// to a trailing hello.
    func askWall(_ commands: [String]) -> [String: Any] {
        let conn = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: Self.port)!, using: .tcp)
        let answered = expectation(description: "snapshot")
        var reply = Data()
        func receive() {
            conn.receive(minimumIncompleteLength: 1, maximumLength: 1 << 20) { data, _, done, _ in
                if let data { reply.append(data) }
                if reply.contains(0x0A) || done { answered.fulfill() } else { receive() }
            }
        }
        conn.stateUpdateHandler = { state in
            if case .ready = state {
                let out = (commands + [#"{"hello":{}}"#]).joined(separator: "\n") + "\n"
                conn.send(content: Data(out.utf8), completion: .contentProcessed { _ in receive() })
            }
        }
        conn.start(queue: .main)
        wait(for: [answered], timeout: 10)
        conn.cancel()
        let line = reply.split(separator: 0x0A).last.map { Data($0) } ?? Data()
        return (try? JSONSerialization.jsonObject(with: line)) as? [String: Any] ?? [:]
    }

    func testMenuDuringPrayerReachesTheAppAndEndsTheSession() {
        let app = XCUIApplication()
        app.launchArguments += SavedCalibration.args() + ["-companionPort", "\(Self.port)"]
        app.launch()
        sleep(3)
        _ = askWall([#"{"pray":{"minutes":5}}"#])
        sleep(2)
        XCTAssertNotNil(askWall([])["prayer"], "the session did not start")
        XCUIRemote.shared.press(.menu)
        sleep(2)
        XCTAssertEqual(app.state, .runningForeground, "Menu during prayer left the app")
        XCTAssertNil(askWall([])["prayer"], "Menu did not reach the app: the session is still running")
    }

    /// Matt, 2026-11-16: "if dreamcoat is run, there's no way to turn it off unless you fully close out the app".
    func testMenuDuringTheDreamcoatEndsItAndStaysInTheApp() {
        let app = XCUIApplication()
        app.launchArguments += SavedCalibration.args() + ["-companionPort", "\(Self.port)"]
        app.launch()
        sleep(3)
        _ = askWall([#"{"dreamcoat":{"_0":true}}"#])
        sleep(2)
        XCTAssertEqual(askWall([])["dreamcoat"] as? Bool, true, "the dreamcoat did not start")
        XCUIRemote.shared.press(.menu)
        sleep(2)
        XCTAssertEqual(app.state, .runningForeground, "Menu during the dreamcoat left the app")
        XCTAssertEqual(askWall([])["dreamcoat"] as? Bool, false, "Menu did not end the dreamcoat")
    }
}
