/// How long the light takes to change (spec §4.2). All durations live here.
public enum LightTiming {
    public static let wake = 3.0, toStillness = 6.0, crossFade = 1.6
    public static let textOut = 0.6, textIn = 1.0, textDelay = 1.0
    /// Lights left over from earlier quick presses fade this fast, so at most the outgoing and
    /// incoming lights show at once.
    public static let staleFade = 0.25

    /// An outgoing light animates to this, not 0, so a later quick press still sees it as
    /// visible and can speed its fade up (`staleLights`).
    public static let fadingOut = 0.0001

    /// Once the fades have finished: lights that faded out (or were snuffed to 0) leave the
    /// levels, so they are drawn at exactly 0 instead of composited at `fadingOut` forever.
    public static func settled(_ levels: [String: Double]) -> [String: Double] {
        levels.filter { $0.value > fadingOut }
    }

    public static func staleLights(visible: Set<String>, old: Set<String>, new: Set<String>) -> Set<String> {
        visible.subtracting(old).subtracting(new)
    }

    public static func duration(from old: Set<String>, to new: Set<String>) -> Double {
        if old.isEmpty && !new.isEmpty { return wake }
        if !old.isEmpty && new.isEmpty { return toStillness }
        return crossFade
    }
}
