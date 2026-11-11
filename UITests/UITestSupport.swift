import Foundation

/// Launch arguments that preload a saved calibration (UserDefaults argument domain, as an
/// old-style plist data literal of the Calibration JSON). The tapestry spans x0…x1 of the frame.
/// By default the boot-up intro is skipped, so a test's first press acts at rest; pass
/// `skipIntro: false` to test the intro itself.
enum SavedCalibration {
    static func args(x0: Double = 0.23, x1: Double = 0.77, skipIntro: Bool = true) -> [String] {
        let json = #"{"version":1,"createdAt":0,"name":"Default","artworkAspect":1.2,"output":{"width":1920,"height":1080},"corners":[{"x":\#(x0),"y":0.1},{"x":\#(x1),"y":0.1},{"x":\#(x1),"y":0.9},{"x":\#(x0),"y":0.9}]}"#
        let hex = json.utf8.map { String(format: "%02x", $0) }.joined()
        return ["-calibration.v1", "<\(hex)>"] + (skipIntro ? ["-skipIntro", "YES"] : [])
    }
}
