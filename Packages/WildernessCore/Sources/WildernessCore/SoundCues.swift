import Foundation

/// A bowl note to ring: semitones from the bowl's tuned D, and how loud (0…1).
public struct SoundCue: Equatable, Sendable {
    public var semitones: Int
    public var gain: Double
    public init(semitones: Int, gain: Double) { self.semitones = semitones; self.gain = gain }
}

/// When the living sound speaks (docs/superpowers/plans/2026-11-15-living-sound.md).
/// Moving to a figure rings a recorded singing bowl, tuned so every figure has its own note of
/// D major pentatonic: Christ is home (D) and the others rise from left to right across the
/// painting. Unfold beats and Context pages ring softly. The bed swells with Christ's breath.
public struct SoundCues: Sendable {
    /// Pitch classes of D major pentatonic, relative to D.
    public static let pentatonic: Set<Int> = [0, 2, 4, 7, 9]
    /// The notes figures may use: A below to D above, so the bowl is never pitched far.
    public static let ladder = [-5, -3, 2, 4, 7, 9, 12]
    public static let figureGain = 1.0
    public static let softGain = 0.55

    private let notes: [String: Int]

    public init(library: AnnotationLibrary) {
        let others = library.annotations.filter { $0.id != "christ" }.sorted { $0.anchor.x < $1.anchor.x }
        var n: [String: Int] = ["christ": 0]
        let last = Double(max(others.count - 1, 1)), top = Double(Self.ladder.count - 1)
        for (rank, a) in others.enumerated() {
            n[a.id] = Self.ladder[Int((Double(rank) / last * top).rounded())]
        }
        notes = n
    }

    public func note(for id: String) -> Int? { notes[id] }

    /// The cue for a change of mode, or nil when nothing new is on the wall.
    public func cue(from old: Mode, to new: Mode, script: UnfoldScript) -> SoundCue? {
        switch (old, new) {
        case let (.explore(a, _), .explore(b, _)) where a == b:
            return nil
        case let (_, .explore(id, _)):
            return note(for: id).map { SoundCue(semitones: $0, gain: Self.figureGain) }
        case let (.unfold(p), .unfold(q)) where p.beat == q.beat:
            return nil
        case let (_, .unfold(q)):
            guard script.beats.indices.contains(q.beat),
                  let first = script.beats[q.beat].light.first?.first, let n = note(for: first) else { return nil }
            return SoundCue(semitones: n, gain: Self.softGain)
        case let (.context(p), .context(q)) where p != q:
            return SoundCue(semitones: 0, gain: Self.softGain)
        default:
            return nil
        }
    }

    /// How far into its breath the bed is, 0…1: Christ's own 12 s breath.
    public static func swell(breathing: Breathing, at t: Double, since start: Double) -> Double {
        breathing.breath(id: "christ", at: t, since: start)
    }
}
