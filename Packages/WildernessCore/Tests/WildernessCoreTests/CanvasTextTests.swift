import Foundation
import Testing
@testable import WildernessCore

// Text on the canvas (Matt, 2026-11-15: no room beside the tapestry; place it near each figure).

private func a(_ id: String, _ x0: Double, _ y0: Double, _ x1: Double, _ y1: Double) -> Annotation {
    Annotation(id: id, title: id, short: "", extended: "", references: [], evidence: .documented,
               anchor: .init(x: (x0 + x1) / 2, y: (y0 + y1) / 2),
               outline: [.init(x: x0, y: y0), .init(x: x1, y: y0), .init(x: x1, y: y1), .init(x: x0, y: y1)],
               textSide: .left, geometrySource: "test")
}
private let lib = AnnotationLibrary(artworkAspect: 1.2, annotations: [
    a("christ", 0.62, 0.25, 0.88, 0.75), a("raven", 0.16, 0.17, 0.27, 0.24), a("lion", 0.85, 0.75, 0.99, 0.9),
])
private let zones = [
    TextZone(x: 0.0, y: 0.76, w: 0.34, h: 0.24, score: 0.81),   // bottom-left bush
    TextZone(x: 0.14, y: 0.30, w: 0.34, h: 0.24, score: 0.80),  // rock face, left of centre
    TextZone(x: 0.66, y: 0.64, w: 0.34, h: 0.24, score: 0.79),  // over Christ's knees: never used
    TextZone(x: 0.20, y: 0.06, w: 0.34, h: 0.24, score: 0.73),  // sky, upper left
]

@Test func textNeverCoversTheFigureItDescribesOrChrist() {
    for id in ["christ", "raven", "lion"] {
        let z = CanvasText.zone(for: id, library: lib, zones: zones)!
        #expect(z != zones[2], "\(id) would put text over Christ")
        let o = lib.annotations.first { $0.id == id }!.outline!
        #expect(!CanvasText.overlaps(z, o), "\(id)'s text covers \(id)")
    }
}

@Test func textGoesToTheNearestCalmPlace() {
    // The raven (upper left): the sky zone overlaps it, so the rock face below is nearest.
    #expect(CanvasText.zone(for: "raven", library: lib, zones: zones) == zones[1])
    // The lion (lower right): the zones near it cover Christ, so the nearest allowed is the
    // rock face (0.73 away) just ahead of the bottom-left bush (0.75).
    #expect(CanvasText.zone(for: "lion", library: lib, zones: zones) == zones[1])
}

@Test func readingModesUseOneSteadyPlace() {
    // Context and Unfold: the best zone that does not cover Christ.
    #expect(CanvasText.readingZone(library: lib, zones: zones) == zones[0])
}

@Test func theShippedZonesDecode() throws {
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../../../../App/Content/textzones.json").standardized
    let z = try TextZones.decode(Data(contentsOf: url))
    #expect(z.zones.count >= 5)
}

@Test func withNoRoomBesideTheTapestryTextGoesOnTheCanvas() {
    // Matt's wall: the tapestry fills the frame side to side.
    let full = Calibration(artworkAspect: 1.2, output: PixelSize(width: 1920, height: 1080), corners: [
        .init(x: 0.01, y: 0.02), .init(x: 0.99, y: 0.02), .init(x: 0.99, y: 0.98), .init(x: 0.01, y: 0.98)])
    let z = TextZone(x: 0.14, y: 0.3, w: 0.34, h: 0.24, score: 0.8)
    #expect(TextColumnLayout.place(preferred: .left, calibration: full, canvasZone: z).position == .onCanvas(z))
    // A wall with room beside it keeps the side column.
    let roomy = Calibration.defaultFor(artworkAspect: 1.2, output: PixelSize(width: 1920, height: 1080))
    if case .beside = TextColumnLayout.place(preferred: .left, calibration: roomy, canvasZone: z).position {} else {
        Issue.record("a wall with room beside the tapestry should keep the side column")
    }
}
