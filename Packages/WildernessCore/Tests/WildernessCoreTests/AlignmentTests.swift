import Foundation
import Testing
@testable import WildernessCore

// Eight-point alignment (docs/superpowers/plans/2026-11-15-eight-point-alignment.md).

private let output = PixelSize(width: 1920, height: 1080)
private func cal() -> Calibration { .defaultFor(artworkAspect: 1.2, output: output) }
private func near(_ a: Point<ProjectorSpace>, _ b: Point<ProjectorSpace>, _ tol: Double = 1e-9) -> Bool {
    abs(a.x - b.x) < tol && abs(a.y - b.y) < tol
}

@Test func withoutOffsetsTheMappingIsExactlyTheFourCornerPerspective() {
    let c = cal()
    for (u, v) in [(0.0, 0.0), (0.5, 0.0), (0.3, 0.7), (1.0, 1.0)] {
        let p = Point<ArtworkSpace>(x: u, y: v)
        #expect(near(c.projectorPoint(artwork: p), c.artworkToProjector!.apply(p)))
    }
    #expect(c.edgeOffsets == [.init(x: 0, y: 0), .init(x: 0, y: 0), .init(x: 0, y: 0), .init(x: 0, y: 0)])
}

@Test func anEdgeOffsetMovesItsMidpointFullyAndLeavesCornersAlone() {
    var c = cal()
    c.edgeOffsets[AlignEdge.top.rawValue] = .init(x: 0, y: 0.02)       // top edge sags 2% of the frame
    let h = c.artworkToProjector!
    let mid = Point<ArtworkSpace>(x: 0.5, y: 0)
    #expect(near(c.projectorPoint(artwork: mid), Point(x: h.apply(mid).x, y: h.apply(mid).y + 0.02)))
    for corner in [Point<ArtworkSpace>(x: 0, y: 0), Point(x: 1, y: 0), Point(x: 1, y: 1), Point(x: 0, y: 1)] {
        #expect(near(c.projectorPoint(artwork: corner), h.apply(corner)))
    }
    // The opposite edge does not move; the centre moves by half (a smooth blend).
    let bottomMid = Point<ArtworkSpace>(x: 0.5, y: 1)
    #expect(near(c.projectorPoint(artwork: bottomMid), h.apply(bottomMid)))
    let centre = Point<ArtworkSpace>(x: 0.5, y: 0.5)
    #expect(abs(c.projectorPoint(artwork: centre).y - h.apply(centre).y - 0.01) < 1e-9)
}

@Test func oldSavedCalibrationsWithoutOffsetsStillLoad() throws {
    let old = #"{"version":1,"createdAt":0,"name":"Default","artworkAspect":1.2,"output":{"width":1920,"height":1080},"corners":[{"x":0.23,"y":0.1},{"x":0.77,"y":0.1},{"x":0.77,"y":0.9},{"x":0.23,"y":0.9}]}"#
    let c = try JSONDecoder().decode(Calibration.self, from: Data(old.utf8))
    #expect(c.edgeOffsets.allSatisfy { $0.x == 0 && $0.y == 0 })
    var bent = c
    bent.edgeOffsets[AlignEdge.left.rawValue] = .init(x: -0.01, y: 0)
    #expect(try JSONDecoder().decode(Calibration.self, from: JSONEncoder().encode(bent)) == bent)
}

@Test func eightHandlesGoClockwiseFromTopLeft() {
    #expect(AlignPoint.allCases.map(\.label) == ["Top left", "Top middle", "Top right", "Right middle",
                                                 "Bottom right", "Bottom middle", "Bottom left", "Left middle"])
    var c = cal()
    c.edgeOffsets[AlignEdge.right.rawValue] = .init(x: 0.01, y: 0)
    let h = c.artworkToProjector!
    #expect(near(c.handle(.topRight), c.corners[1]))
    #expect(near(c.handle(.rightMiddle), Point(x: h.apply(.init(x: 1, y: 0.5)).x + 0.01, y: h.apply(.init(x: 1, y: 0.5)).y)))
}

@Test func nudgingAMidpointBendsItsEdgeAndIsClamped() {
    var a = CornerAdjuster(calibration: cal())
    a.select(.bottomMiddle)
    a.step = .fine
    a.nudge(.down)
    #expect(abs(a.calibration.edgeOffsets[AlignEdge.bottom.rawValue].y - 1.0 / 1080) < 1e-12)
    #expect(a.calibration.corners == cal().corners)          // corners untouched
    a.step = .coarse
    for _ in 0..<200 { a.nudge(.down) }
    #expect(a.calibration.edgeOffsets[AlignEdge.bottom.rawValue].y <= Calibration.maxEdgeOffset + 1e-12)
}

@Test func theRemoteWalksAllEightHandlesThenReviews() {
    var s = CalibrationSession(start: cal())
    #expect(s.stepLabel == "Top left · 1 of 8")
    for _ in 0..<7 { s.handle(.select) }
    #expect(s.phase == .point(.leftMiddle) && s.stepLabel == "Left middle · 8 of 8")
    s.handle(.select)
    #expect(s.phase == .review)
    #expect(s.handle(.select) == .save(s.calibration))
}

@Test func thePhoneCanPickAHandleDirectly() {
    var s = CalibrationSession(start: cal())
    s.handle(.pick(.rightMiddle))
    #expect(s.phase == .point(.rightMiddle))
    s.handle(.move(.right))
    #expect(s.calibration.edgeOffsets[AlignEdge.right.rawValue].x > 0)
}

@Test func theShaderCanMapAScreenPointBackToTheArtwork() throws {
    let c = cal(), screen = PixelSize(width: 1920, height: 1080)
    let rows = try #require(c.screenToArtworkRows(screen: screen))
    func back(_ x: Double, _ y: Double) -> (Double, Double) {
        let p = SIMD3(x, y, 1), w = (rows[2] * p).sum()
        return ((rows[0] * p).sum() / w, (rows[1] * p).sum() / w)
    }
    let tl = c.corners[0], br = c.corners[2]
    let a = back(tl.x * 1920, tl.y * 1080), b = back(br.x * 1920, br.y * 1080)
    #expect(abs(a.0) < 1e-9 && abs(a.1) < 1e-9)
    #expect(abs(b.0 - 1) < 1e-9 && abs(b.1 - 1) < 1e-9)
}

// MARK: Aligning from the phone

@Test func alignCommandsTravelOverTheWire() throws {
    let all: [PhoneCommand] = [.align(.start), .align(.pick(.bottomMiddle)), .align(.move(.left)),
                               .align(.toggleFine), .align(.save), .align(.cancel)]
    for c in all {
        let back = try JSONDecoder().decode(PhoneCommand.self, from: LineFramer.frame(c).dropLast())
        #expect(back == c)
    }
}

@Test func theSessionTellsThePhoneWhereEveryHandleIs() {
    var s = CalibrationSession(start: cal())
    s.handle(.pick(.rightMiddle)); s.handle(.playPause)
    let a = s.alignmentState
    #expect(a.handles.count == 8 && a.selected == .rightMiddle && a.fine && !a.reviewing)
    #expect(near(a.handles[AlignPoint.topLeft.rawValue], cal().corners[0]))
}

@Test func thePhoneCanStartAlignmentFromAnywhereButSettingsFlowsStayIntact() {
    var m = ModeMachine(calibrated: true, now: 0, intro: false)
    m.beginCalibration()
    #expect(m.mode == .calibrating)
    var e = ModeMachine(calibrated: true, now: 0, intro: false)
    e.handle(.move(.right), now: 1, library: AnnotationLibrary(artworkAspect: 1.2, annotations: []),
             script: UnfoldScript(beats: []), context: .empty)
    e.beginCalibration()
    #expect(e.mode == .calibrating)
}

// MARK: Dragging handles on the phone (Matt, 2026-11-15)

@Test func draggingACornerPutsItExactlyThere() {
    var s = CalibrationSession(start: cal())
    s.handle(.place(.topLeft, Point(x: 0.2, y: 0.12)))
    #expect(s.phase == .point(.topLeft))
    #expect(near(s.calibration.corners[0], Point(x: 0.2, y: 0.12)))
}

@Test func draggingAMidpointBendsItsEdgeSoTheHandleLandsUnderTheFinger() {
    var s = CalibrationSession(start: cal())
    let straight = cal().handle(.topMiddle)
    let target = Point<ProjectorSpace>(x: straight.x, y: straight.y + 0.03)
    s.handle(.place(.topMiddle, target))
    #expect(near(s.calibration.handle(.topMiddle), target, 1e-9))
    #expect(s.calibration.corners == cal().corners)
}

@Test func aDragCannotFoldTheOutlineOrBendTooFar() {
    var s = CalibrationSession(start: cal())
    let before = s.calibration
    s.handle(.place(.topLeft, Point(x: 0.95, y: 0.95)))          // past the opposite corner
    #expect(s.calibration.corners == before.corners)
    s.handle(.place(.bottomMiddle, Point(x: 0.5, y: 2.0)))       // far off the frame
    #expect(abs(s.calibration.edgeOffsets[AlignEdge.bottom.rawValue].y) <= Calibration.maxEdgeOffset + 1e-12)
}

@Test func placeTravelsOverTheWire() throws {
    let c = PhoneCommand.align(.place(.rightMiddle, Point(x: 0.81, y: 0.5)))
    #expect(try JSONDecoder().decode(PhoneCommand.self, from: LineFramer.frame(c).dropLast()) == c)
}
