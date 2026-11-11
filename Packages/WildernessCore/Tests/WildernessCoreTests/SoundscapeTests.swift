import Testing
@testable import WildernessCore

@Test func soundIsSilentWhenOff() {
    for m: Mode in [.stillness, .menu(focus: .explore), .unfold(.start), .context(page: 0)] {
        #expect(Soundscape.target(mode: m, on: false) == 0, "\(m)")
    }
}

@Test func soundDipsUnderUnfoldSoTheWordsLead() {
    let rest = Soundscape.target(mode: .stillness, on: true)
    #expect(rest == Soundscape.ambient)
    #expect(Soundscape.target(mode: .unfold(.start), on: true) < rest)
    #expect(Soundscape.target(mode: .unfold(.start), on: true) > 0)
    #expect(Soundscape.target(mode: .explore(id: "christ", expanded: false), on: true) == rest)
    #expect(Soundscape.target(mode: .context(page: 2), on: true) == rest)
}

@Test func soundIsSilentWhileCalibrating() {
    #expect(Soundscape.target(mode: .calibrating, on: true) == 0)
}

@Test func volumeEasesTowardItsTargetWithoutOvershoot() {
    var v = 0.0
    v = Soundscape.step(current: v, target: 0.3, dt: 1)        // fade takes about 3 s from silence to full
    #expect(v > 0 && v < 0.3)
    for _ in 0..<20 { v = Soundscape.step(current: v, target: 0.3, dt: 0.25) }
    #expect(v == 0.3)
    v = Soundscape.step(current: v, target: 0, dt: 10)
    #expect(v == 0)
}
