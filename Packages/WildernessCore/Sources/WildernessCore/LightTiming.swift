/// How long the light takes to change (spec §4.2). All durations live here.
public enum LightTiming {
    public static let wake = 3.0, toStillness = 6.0, crossFade = 1.6
    public static let textOut = 0.6, textIn = 1.0, textDelay = 1.0
    /// Lights left over from earlier quick presses fade this fast, so at most the outgoing and
    /// incoming lights show at once.
    public static let staleFade = 0.25

    public static func staleLights(visible: Set<String>, old: Set<String>, new: Set<String>) -> Set<String> {
        visible.subtracting(old).subtracting(new)
    }

    public static func duration(from old: Set<String>, to new: Set<String>) -> Double {
        if old.isEmpty && !new.isEmpty { return wake }
        if !old.isEmpty && new.isEmpty { return toStillness }
        return crossFade
    }
}
