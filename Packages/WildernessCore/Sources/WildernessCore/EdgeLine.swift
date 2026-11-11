import Foundation

/// Explore's edge line (Matt, 2026-11-10): when a figure is chosen, a thin line draws itself
/// around Matt's traced outline, then settles to a quieter line while the figure stays chosen.
/// Same stroke as the boot-up intro. Strength comes from Tuning.edgeLine (0 turns it off).
public enum EdgeLine {
    /// Wait for the subject light to begin warming before drawing.
    public static let delay = 0.2
    public static let drawSeconds = 0.9
    /// After drawing, the line eases down to this fraction over `settleSeconds`.
    public static let restOpacity = 0.6
    public static let settleSeconds = 1.0

    /// `progress` 0…1 is how much of the outline is drawn; `opacity` 0…1 its brightness.
    public static func frame(at t: Double) -> (progress: Double, opacity: Double) {
        let x = min(max((t - delay) / drawSeconds, 0), 1)
        let progress = x * x * (3 - 2 * x)                       // smoothstep: eases in and out
        let s = min(max((t - delay - drawSeconds) / settleSeconds, 0), 1)
        let opacity = 1 - (1 - restOpacity) * s * s * (3 - 2 * s)
        return (progress, opacity)
    }
}
