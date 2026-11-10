import Foundation
import Testing
@testable import WildernessCore

private func a(_ id: String, _ x: Double, _ y: Double) -> Annotation {
    Annotation(id: id, title: id, short: "", extended: "", references: [], evidence: .documented,
               anchor: .init(x: x, y: y), outline: nil, textSide: .left, geometrySource: "test")
}
private let lib = AnnotationLibrary(artworkAspect: 1.2, annotations: [
    a("christ", 0.77, 0.50), a("angels", 0.85, 0.18), a("stag", 0.19, 0.59),
])

@Test func anyArrowWakesExploreOnTheFirstDetail() {
    var s = ExploreState.idle
    let exit = s.handle(.move(.left), library: lib)
    #expect(s == .exploring(id: "christ", expanded: false) && !exit)
}

@Test func longerTextStaysOpenWhileMovingBetweenDetails() {
    var s = ExploreState.exploring(id: "christ", expanded: true)
    _ = s.handle(.move(.up), library: lib)
    #expect(s == .exploring(id: "angels", expanded: true))
}

@Test func shortTextStaysShortWhileMovingBetweenDetails() {
    var s = ExploreState.exploring(id: "christ", expanded: false)
    _ = s.handle(.move(.up), library: lib)
    #expect(s == .exploring(id: "angels", expanded: false))
}

@Test func arrowWithNoNeighbourStaysPut() {
    var s = ExploreState.exploring(id: "angels", expanded: true)
    _ = s.handle(.move(.up), library: lib)
    #expect(s == .exploring(id: "angels", expanded: true))
}

@Test func selectTogglesTheLongerText() {
    var s = ExploreState.exploring(id: "christ", expanded: false)
    _ = s.handle(.select, library: lib)
    #expect(s == .exploring(id: "christ", expanded: true))
}

@Test func backFromExploringReturnsToDarkAndBackFromDarkExits() {
    var s = ExploreState.exploring(id: "christ", expanded: false)
    #expect(s.handle(.back, library: lib) == false && s == .idle)
    #expect(s.handle(.back, library: lib) == true)
}
