import Foundation

/// Quiet sound (approved 2026-11-10): an optional, quiet ethereal pad (was a wind bed, which small speakers could not play), off by default. It dips
/// under Unfold so the words lead, is silent while calibrating, and always fades rather than
/// starting or stopping abruptly.
public enum Soundscape {
    /// Player volume (0…1) at rest, in Explore, Context and the menu.
    public static let ambient = 0.35
    /// Under Unfold: present, but well beneath the reading.
    public static let underUnfold = 0.15
    /// Seconds to fade from silence to `ambient`.
    public static let fadeSeconds = 3.0

    public static func target(mode: Mode, on: Bool) -> Double {
        guard on else { return 0 }
        switch mode {
        case .calibrating: return 0
        case .unfold: return underUnfold
        default: return ambient
        }
    }

    /// Moves `current` toward `target` at a steady rate, never past it.
    public static func step(current: Double, target: Double, dt: Double) -> Double {
        let maxStep = ambient / fadeSeconds * dt
        let d = target - current
        return abs(d) <= maxStep ? target : current + (d > 0 ? maxStep : -maxStep)
    }
}
