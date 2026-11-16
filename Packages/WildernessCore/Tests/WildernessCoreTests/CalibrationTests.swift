import Foundation
import Testing
@testable import WildernessCore

private let hd = PixelSize(width: 1920, height: 1080)

@Test func canvasToScreenScalesThroughNormalizedSpaces() throws {
    var cal = Calibration.defaultFor(artworkAspect: 1.2, output: hd)
    cal.corners = [.init(x: 0.25, y: 0.05), .init(x: 0.75, y: 0.05), .init(x: 0.75, y: 0.95), .init(x: 0.25, y: 0.95)]
    let h = try #require(cal.canvasToScreen(canvas: .init(width: 600, height: 500), screen: .init(width: 1920, height: 1080)))
    let p = h.apply(Point<CanvasSpace>(x: 600, y: 500)) // bottom-right of canvas
    #expect(abs(p.x - 1440) < 1e-6 && abs(p.y - 1026) < 1e-6)
}

@Test func defaultCornersAreCenteredWithArtworkAspectOnTheWall() {
    let cal = Calibration.defaultFor(artworkAspect: 1.2, output: hd)
    let c = cal.corners
    let widthPx = (c[1].x - c[0].x) * 1920, heightPx = (c[3].y - c[0].y) * 1080
    #expect(abs(widthPx / heightPx - 1.2) < 1e-9)
    #expect(abs((c[0].x + c[1].x) / 2 - 0.5) < 1e-9 && abs((c[0].y + c[3].y) / 2 - 0.5) < 1e-9)
}

@Test func calibrationSurvivesEncodeDecode() throws {
    let cal = Calibration.defaultFor(artworkAspect: 1.2, output: hd)
    let data = try JSONEncoder().encode(cal)
    #expect(try JSONDecoder().decode(Calibration.self, from: data) == cal)
}

@Test func calibrationIsStaleWhenOutputResolutionChanges() {
    let cal = Calibration.defaultFor(artworkAspect: 1.2, output: hd)
    #expect(cal.matches(output: hd))
    #expect(cal.matches(output: .init(width: 3840, height: 2160))) // same aspect: corners are normalized, still valid
    #expect(!cal.matches(output: .init(width: 1280, height: 1024)))
}

@Test func nudgeMovesOnlyTheSelectedCornerByOnePixelInFineMode() {
    var adj = CornerAdjuster(calibration: .defaultFor(artworkAspect: 1.2, output: hd))
    let before = adj.calibration.corners
    adj.step = .fine
    adj.selected = .bottomRight
    adj.nudge(.right)
    let after = adj.calibration.corners
    #expect(abs((after[2].x - before[2].x) * 1920 - 1) < 1e-9)
    #expect(after[0] == before[0] && after[1] == before[1] && after[3] == before[3])
}

@Test func coarseStepIsTenPixels() {
    var adj = CornerAdjuster(calibration: .defaultFor(artworkAspect: 1.2, output: hd))
    let y0 = adj.calibration.corners[0].y
    adj.nudge(.up)
    #expect(abs((y0 - adj.calibration.corners[0].y) * 1080 - 10) < 1e-9)
}

@Test func selectNextCyclesClockwise() {
    var adj = CornerAdjuster(calibration: .defaultFor(artworkAspect: 1.2, output: hd))
    let order = (0..<9).map { _ in defer { adj.selectNext() }; return adj.selected }
    #expect(order == [.topLeft, .topMiddle, .topRight, .rightMiddle, .bottomRight, .bottomMiddle,
                      .bottomLeft, .leftMiddle, .topLeft])
}

@Test func nudgeThatWouldFoldTheQuadIsRefused() {
    var adj = CornerAdjuster(calibration: .defaultFor(artworkAspect: 1.2, output: hd))
    adj.selected = .topLeft
    for _ in 0..<500 { adj.nudge(.right) } // drive TL past TR
    #expect(adj.calibration.isConvex)
    #expect(adj.calibration.corners[0].x < adj.calibration.corners[1].x)
}

@Test func cornersAreClampedToTheOutputFrame() {
    var adj = CornerAdjuster(calibration: .defaultFor(artworkAspect: 1.2, output: hd))
    adj.selected = .topLeft
    for _ in 0..<500 { adj.nudge(.up) }
    #expect(adj.calibration.corners[0].y == 0)
}
