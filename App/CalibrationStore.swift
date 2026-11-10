import Foundation
import WildernessCore

/// Persists the calibration on the Apple TV so it is restored on every launch.
@MainActor
final class CalibrationStore: ObservableObject {
    private static let key = "calibration.v\(Calibration.currentVersion)"
    private let defaults: UserDefaults

    @Published private(set) var saved: Calibration?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key) {
            do {
                saved = try JSONDecoder().decode(Calibration.self, from: data)
            } catch {
                // A corrupt or old-format profile is treated as "not calibrated", never as a valid one.
                NSLog("Wilderness: discarding unreadable calibration: \(error)")
                saved = nil
            }
        }
    }

    func save(_ calibration: Calibration) {
        var c = calibration
        c.createdAt = Date()
        do {
            defaults.set(try JSONEncoder().encode(c), forKey: Self.key)
            saved = c
        } catch {
            NSLog("Wilderness: failed to save calibration: \(error)")
        }
    }
}
