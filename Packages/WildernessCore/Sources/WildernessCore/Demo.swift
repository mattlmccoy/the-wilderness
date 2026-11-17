import Foundation

/// The self-running portfolio demo: every feature once, about three minutes, looping, for a
/// static camera. It drives the same modes the remote does, so what is filmed is the real app.
///   intro 15 s · rest 40 s (breathing, glints, one pass of sun rays) · Explore 6 × 10 s ·
///   Unfold 4 beats × 9 s · Context 4 pages × 8 s · rest 10 s
public enum DemoScript {
    public static let introSeconds = 15.0
    // Matt, 2026-11-16: a quicker demo (about 1 min 40 s; it was 3 min 13 s). One of everything.
    public static let restSeconds = 25.0
    public static let exploreIds = ["christ", "raven", "lion"]
    public static let exploreSeconds = 8.0
    /// Beats 1 and 7 of Unfold: Eden; lord of the wild.
    public static let unfoldBeats = [0, 6]
    public static let unfoldBeatSeconds = 8.0
    /// The wilderness, then the hidden angels (the restoration reveal).
    public static let contextIds = ["wilderness", "angels"]
    public static let contextPageSeconds = 7.0
    public static let endRestSeconds = 5.0

    public static var restStart: Double { introSeconds }
    public static var exploreStart: Double { restStart + restSeconds }
    public static var unfoldStart: Double { exploreStart + Double(exploreIds.count) * exploreSeconds }
    public static var contextStart: Double { unfoldStart + Double(unfoldBeats.count) * unfoldBeatSeconds }
    public static var total: Double { contextStart + Double(contextIds.count) * contextPageSeconds + endRestSeconds }

    /// What the wall shows `t` seconds after the demo began at `start`.
    public static func mode(at t: Double, since start: Double, script: UnfoldScript, context: ContextScript) -> Mode {
        let loops = ((t - start) / total).rounded(.down)
        let cycle = start + loops * total
        let s = t - cycle
        if s < restStart { return .intro(startedAt: cycle) }
        if s < exploreStart { return .stillness }
        if s < unfoldStart {
            let k = s - exploreStart
            let i = min(Int(k / exploreSeconds), exploreIds.count - 1)
            return .explore(id: exploreIds[i], expanded: k - Double(i) * exploreSeconds >= exploreSeconds / 2)
        }
        if s < contextStart {
            let k = s - unfoldStart
            let i = min(Int(k / unfoldBeatSeconds), unfoldBeats.count - 1)
            let beat = min(unfoldBeats[i], max(script.beats.count - 1, 0))
            let f = (k - Double(i) * unfoldBeatSeconds) / unfoldBeatSeconds
            let duration = script.beats.indices.contains(beat) ? script.beats[beat].duration : 1
            return .unfold(UnfoldPlayback(beat: beat, elapsed: f * duration, paused: false))
        }
        let endRest = contextStart + Double(contextIds.count) * contextPageSeconds
        if s < endRest {
            let i = min(Int((s - contextStart) / contextPageSeconds), contextIds.count - 1)
            let page = context.pages.firstIndex { $0.id == contextIds[i] } ?? 0
            return .context(page: page)
        }
        return .stillness
    }

    /// A `since` for SunRays/PassingLight whose pass is brightest in the middle of the rest segment.
    public static func raysSince(demoSince start: Double, at t: Double) -> Double {
        let cycle = start + ((t - start) / total).rounded(.down) * total
        let passStart = cycle + restStart + restSeconds / 2 - PassingLight.duration / 2
        return passStart - (PassingLight.every - PassingLight.duration)
    }
}
