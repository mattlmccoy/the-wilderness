import Foundation

/// The light drifting slowly between subjects, at rest and in Be still
/// (docs/superpowers/plans/2026-11-16-drift-and-parity.md).
public enum Drift {
    /// A walk over the traced figures that always steps to the nearest one not yet visited,
    /// starting at Christ, so the light travels across the painting instead of jumping about.
    public static func tour(_ library: AnnotationLibrary) -> [String] {
        let figures = library.annotations.compactMap { a -> (String, Double, Double)? in
            guard let o = a.outline, !o.isEmpty else { return nil }
            let n = Double(o.count)
            return (a.id, o.map(\.x).reduce(0, +) / n * library.artworkAspect, o.map(\.y).reduce(0, +) / n)
        }
        guard var here = figures.first(where: { $0.0 == "christ" }) ?? figures.first else { return [] }
        var left = figures.filter { $0.0 != here.0 }, out = [here.0]
        while !left.isEmpty {
            let i = left.indices.min { hypot(left[$0].1 - here.1, left[$0].2 - here.2) < hypot(left[$1].1 - here.1, left[$1].2 - here.2) }!
            here = left.remove(at: i)
            out.append(here.0)
        }
        return out
    }

    /// Light per subject, 0…1: it holds on each subject for `dwell` seconds and cross-fades to the
    /// next over `fade` seconds, centred on the boundary (smoothstep, so it eases in and out).
    /// A walk that does not loop fades in from nothing at the start and out to nothing at the end.
    public static func weights(at t: Double, path: [String], dwell: Double, fade: Double, loops: Bool) -> [String: Double] {
        let n = path.count
        guard n > 0, dwell > 0 else { return [:] }
        let total = Double(n) * dwell
        if !loops, t < 0 || t >= total { return [:] }
        var u = t
        if loops { u = t.truncatingRemainder(dividingBy: total); if u < 0 { u += total } }
        let i = min(Int(u / dwell), n - 1), local = u - Double(i) * dwell, h = fade / 2
        func ease(_ x: Double) -> Double { let c = min(max(x, 0), 1); return c * c * (3 - 2 * c) }
        func blend(_ a: String, _ wa: Double, _ b: String, _ wb: Double) -> [String: Double] {
            a == b ? [a: wa + wb] : [a: wa, b: wb]
        }
        if h > 0, local < h {
            let prev: Int? = i > 0 ? i - 1 : (loops ? n - 1 : nil)
            guard let p = prev else { return [path[i]: ease(local / h)] }
            let f = ease(0.5 + local / fade)
            return blend(path[i], f, path[p], 1 - f)
        }
        if h > 0, local > dwell - h {
            let next: Int? = i < n - 1 ? i + 1 : (loops ? 0 : nil)
            guard let q = next else { return [path[i]: ease((dwell - local) / h)] }
            let f = ease(0.5 - (dwell - local) / fade)
            return blend(path[i], 1 - f, path[q], f)
        }
        return [path[i]: 1]
    }

    /// At rest: 40 s on each figure, 15 s to drift to the next, round and round.
    public static let restDwell = 40.0, restFade = 15.0
    /// Be still: the walk's own 35 s per figure, with 12 s drifts.
    public static let stillFade = 12.0
}
