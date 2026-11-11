import Foundation
import Testing
@testable import WildernessCore

private func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> [Point<ArtworkSpace>] {
    // In a 1200 x 1000 canvas.
    [.init(x: x / 1200, y: y / 1000), .init(x: (x + w) / 1200, y: y / 1000),
     .init(x: (x + w) / 1200, y: (y + h) / 1000), .init(x: x / 1200, y: (y + h) / 1000)]
}

@Test func largeFiguresKeepTheFullSoftEdge() {
    #expect(SubjectFeather.radius(outline: rect(100, 100, 400, 400), canvasWidth: 1200, canvasHeight: 1000) == 22)
}

@Test func thinFiguresGetASharperEdgeSoTheyStayBright() {
    // The serpent: long and about 12 units wide. A 22-unit blur would leave almost nothing.
    let r = SubjectFeather.radius(outline: rect(100, 100, 240, 12), canvasWidth: 1200, canvasHeight: 1000)
    #expect(r >= SubjectFeather.minimum && r <= 10)
}

@Test func featherNeverDropsBelowTheMinimum() {
    #expect(SubjectFeather.radius(outline: rect(100, 100, 3, 3), canvasWidth: 1200, canvasHeight: 1000) == SubjectFeather.minimum)
}
