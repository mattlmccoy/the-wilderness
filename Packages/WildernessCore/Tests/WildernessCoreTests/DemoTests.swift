import Foundation
import Testing
@testable import WildernessCore

// Self-running portfolio demo (docs/superpowers/plans/2026-11-15-demo-and-writeup.md).

private func beat(_ id: String) -> UnfoldBeat {
    UnfoldBeat(id: id, duration: 35, light: [["christ"]], textSide: .left, title: id, short: "s", more: nil, draft: true)
}
private let unfold = UnfoldScript(beats: (0..<8).map { beat("b\($0)") })
private func page(_ id: String) -> ContextPage {
    ContextPage(id: id, title: id, text: "t", light: [], visual: nil, textSide: .left, sources: ["s"], draft: true)
}
private let context = ContextScript(pages: ["wilderness", "desert", "mountain", "painter", "sack", "far", "size"].map(page))
private let s0 = 1000.0
private func mode(_ t: Double) -> Mode { DemoScript.mode(at: s0 + t, since: s0, script: unfold, context: context) }

@Test func theDemoOpensWithTheIntroThenRests() {
    #expect(mode(0) == .intro(startedAt: s0))
    #expect(mode(14) == .intro(startedAt: s0))
    #expect(mode(20) == .stillness)
}

@Test func theDemoExploresSixFiguresShortThenExpanded() {
    let e = DemoScript.exploreStart
    #expect(mode(e + 2) == .explore(id: "christ", expanded: false))
    #expect(mode(e + 7) == .explore(id: "christ", expanded: true))
    #expect(mode(e + 10 + 2) == .explore(id: "raven", expanded: false))
    #expect(mode(e + 59) == .explore(id: "beast", expanded: true))
}

@Test func theDemoPlaysFourUnfoldBeatsCompressed() {
    let u = DemoScript.unfoldStart
    guard case let .unfold(p) = mode(u + 1) else { Issue.record("not unfolding"); return }
    #expect(p.beat == DemoScript.unfoldBeats[0] && !p.paused)
    // Halfway through the second demo beat = halfway through that beat's real 35 s, so lights step.
    guard case let .unfold(q) = mode(u + DemoScript.unfoldBeatSeconds * 1.5) else { Issue.record("not unfolding"); return }
    #expect(q.beat == DemoScript.unfoldBeats[1] && abs(q.elapsed - 17.5) < 1e-9)
}

@Test func theDemoTurnsContextPagesByName() {
    let c = DemoScript.contextStart
    #expect(mode(c + 1) == .context(page: 0))                               // wilderness
    #expect(mode(c + DemoScript.contextPageSeconds + 1) == .context(page: 2)) // mountain
}

@Test func theDemoLoopsForever() {
    #expect(DemoScript.total > 150 && DemoScript.total < 240)
    #expect(mode(DemoScript.total + 1) == .intro(startedAt: s0 + DemoScript.total))
    #expect(mode(DemoScript.total * 3 + 25) == .stillness)
}

@Test func theDemoShowsOnePassOfSunRaysWhileResting() {
    // During the rest segment, the rays pass at their brightest.
    let mid = s0 + DemoScript.restStart + 5 + PassingLight.duration / 2
    let f = SunRays.frame(at: mid, since: DemoScript.raysSince(demoSince: s0, at: mid))
    #expect(f != nil && f!.intensity > 0.25)
}

@Test func anyInputEndsTheDemoAndLeavesTheWallAtRest() {
    let lib = AnnotationLibrary(artworkAspect: 1.2, annotations: [])
    var m = ModeMachine(calibrated: true, now: 0, intro: false)
    m.startDemo(now: 10)
    #expect(m.isDemo)
    m.tick(now: 10 + DemoScript.exploreStart + 1, dt: 0.25, script: unfold, context: context)
    #expect(m.mode == .explore(id: "christ", expanded: false))
    m.handle(.back, now: 80, library: lib, script: unfold, context: context)
    #expect(!m.isDemo && m.mode == .stillness)
}

@Test func theDemoStartsFromTheHiddenSettings() {
    let lib = AnnotationLibrary(artworkAspect: 1.2, annotations: [])
    var m = ModeMachine(calibrated: true, now: 0, intro: false)
    m.handle(.holdSelect, now: 1, library: lib, script: unfold, context: context)
    while m.mode != .settings(focus: .demo) { m.handle(.move(.down), now: 2, library: lib, script: unfold, context: context) }
    m.handle(.select, now: 3, library: lib, script: unfold, context: context)
    #expect(m.isDemo)
    #expect(m.mode == .intro(startedAt: 3))
}

@Test func thePhoneCanStartAndStopTheDemo() throws {
    #expect(try JSONDecoder().decode(PhoneCommand.self, from: LineFramer.frame(PhoneCommand.demo(true)).dropLast()) == .demo(true))
}
