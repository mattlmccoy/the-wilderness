import Foundation
import Testing
@testable import WildernessCore

// Living sound (docs/superpowers/plans/2026-11-15-living-sound.md): a bowl rings in key when the
// wall moves to a new figure, and the bed swells with Christ's breath.

private func a(_ id: String, x: Double) -> Annotation {
    Annotation(id: id, title: id, short: "", extended: "", references: [], evidence: .documented,
               anchor: .init(x: x, y: 0.5), outline: nil, textSide: .left, geometrySource: "test")
}
private let lib = AnnotationLibrary(artworkAspect: 1.2, annotations: [
    a("lion", x: 0.9), a("raven", x: 0.2), a("christ", x: 0.75), a("stag", x: 0.1), a("angels", x: 0.85),
])
private let cues = SoundCues(library: lib)
private func beat(_ light: [[String]]) -> UnfoldBeat {
    UnfoldBeat(id: "b", duration: 30, light: light, textSide: .left, title: "", short: "", more: nil, draft: true)
}
private let script = UnfoldScript(beats: [beat([["christ"]]), beat([["raven"], ["lion"]])])

@Test func christIsHome() {
    #expect(cues.note(for: "christ") == 0)
}

@Test func otherFiguresRiseInKeyFromLeftToRight() {
    let order = ["stag", "raven", "angels", "lion"]          // by x, Christ excluded
    let notes = order.map { cues.note(for: $0)! }
    #expect(notes == notes.sorted() && Set(notes).count == notes.count)
    for n in notes { #expect(SoundCues.pentatonic.contains(((n % 12) + 12) % 12)) }
    #expect(cues.note(for: "nobody") == nil)
}

@Test func movingToAnotherFigureRingsItsNote() {
    let c = cues.cue(from: .explore(id: "raven", expanded: false), to: .explore(id: "lion", expanded: false), script: script)
    #expect(c == SoundCue(semitones: cues.note(for: "lion")!, gain: SoundCues.figureGain))
    #expect(cues.cue(from: .menu(focus: .explore), to: .explore(id: "christ", expanded: false), script: script)?.semitones == 0)
}

@Test func openingTheStoryOrTheMenuStaysQuiet() {
    #expect(cues.cue(from: .explore(id: "lion", expanded: false), to: .explore(id: "lion", expanded: true), script: script) == nil)
    #expect(cues.cue(from: .stillness, to: .menu(focus: .explore), script: script) == nil)
    #expect(cues.cue(from: .explore(id: "lion", expanded: false), to: .calibrating, script: script) == nil)
}

@Test func unfoldRingsSoftlyOnEachNewBeat() {
    let p0 = UnfoldPlayback(beat: 0, elapsed: 20, paused: false), p1 = UnfoldPlayback(beat: 1, elapsed: 0, paused: false)
    let c = cues.cue(from: .unfold(p0), to: .unfold(p1), script: script)
    #expect(c == SoundCue(semitones: cues.note(for: "raven")!, gain: SoundCues.softGain))
    // Time passing inside a beat is not a new beat.
    #expect(cues.cue(from: .unfold(p1), to: .unfold(UnfoldPlayback(beat: 1, elapsed: 3, paused: false)), script: script) == nil)
}

@Test func turningAContextPageRingsHomeSoftly() {
    #expect(cues.cue(from: .context(page: 0), to: .context(page: 1), script: script) == SoundCue(semitones: 0, gain: SoundCues.softGain))
}

@Test func theBedSwellsWithChristsBreath() {
    let b = Breathing(ids: ["christ", "lion"])
    for t in stride(from: 0.0, through: 24, by: 1.5) {
        #expect(abs(SoundCues.swell(breathing: b, at: 100 + t, since: 100) - b.breath(id: "christ", at: 100 + t, since: 100)) < 1e-12)
    }
}
