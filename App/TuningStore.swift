import Foundation
import WildernessCore

/// Persists the light tuning on the Apple TV, like the calibration. A profile saved before a
/// field existed keeps its saved values (the new field takes its default); a corrupt profile
/// falls back to the defaults and is logged, never half-applied.
@MainActor
final class TuningStore: ObservableObject {
    private let defaults: UserDefaults
    @Published var tuning: Tuning { didSet { save() } }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        var loaded = Tuning.defaults
        if let data = defaults.data(forKey: Tuning.storageKey) {
            do { loaded = try JSONDecoder().decode(Tuning.self, from: data) } catch {
                NSLog("Wilderness: discarding unreadable tuning: \(error)")
            }
        }
        tuning = loaded
    }

    private func save() {
        do { defaults.set(try JSONEncoder().encode(tuning), forKey: Tuning.storageKey) } catch {
            NSLog("Wilderness: failed to save tuning: \(error)")
        }
    }
}
