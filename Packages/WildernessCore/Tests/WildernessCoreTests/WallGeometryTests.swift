import Foundation
import Testing
@testable import WildernessCore

private let hd = PixelSize(width: 1920, height: 1080)
private func rect(x0: Double, x1: Double, y0: Double = 0.1, y1: Double = 0.9) -> Calibration {
    var c = Calibration.defaultFor(artworkAspect: 1.2, output: hd)
    c.corners = [.init(x: x0, y: y0), .init(x: x1, y: y0), .init(x: x1, y: y1), .init(x: x0, y: y1)]
    return c
}

@Test func defaultCalibrationGivesAbout17PixelsPerInch() {
    let ppi = WallGeometry.pixelsPerInch(.defaultFor(artworkAspect: 1.2, output: hd))
    #expect(abs(ppi - 17.28) < 0.01)
}

@Test func defaultCalibrationLeavesRoomBeside() {
    let p = TextColumnLayout.place(preferred: .right, calibration: .defaultFor(artworkAspect: 1.2, output: hd))
    #expect(p == ColumnPlacement(position: .beside(.right), widthInches: 19))
}

@Test func narrowPreferredSideUsesTheOtherSide() {
    let p = TextColumnLayout.place(preferred: .right, calibration: rect(x0: 0.30, x1: 0.95))
    #expect(p.position == .beside(.left))
    #expect(p.widthInches == 19)
}

@Test func bothSidesNarrowFallsBackToLowerEdge() {
    let p = TextColumnLayout.place(preferred: .left, calibration: rect(x0: 0.05, x1: 0.95))
    #expect(p.position == .overLowerEdge)
}

@Test func widthShrinksToFitTheWall() {
    // Right wall is exactly 18 in: (1 - x1) * 60 / (x1 - 0.1) = 18  →  x1 = 61.8 / 78
    let cal = rect(x0: 0.1, x1: 61.8 / 78)
    #expect(abs(WallGeometry.wallInches(cal, side: .right) - 18) < 1e-9)
    let p = TextColumnLayout.place(preferred: .right, calibration: cal)
    #expect(p.position == .beside(.right))
    #expect(abs(p.widthInches - 15.5) < 1e-9)   // 18 - 2 gap - 0.5 margin
}

/// Matt's wall (option A): 87 in of wall, the 60 in tapestry centred, 13.5 in each side.
@Test func mattsWallKeepsTextBesideTheTapestryInAnElevenInchColumn() {
    // Tapestry spans 60 of 87 in → x0 = 13.5/87 of the frame width when the frame fills the wall.
    let cal = rect(x0: 13.5 / 87, x1: 73.5 / 87)
    #expect(abs(WallGeometry.wallInches(cal, side: .left) - 13.5) < 1e-9)
    let p = TextColumnLayout.place(preferred: .left, calibration: cal)
    #expect(p.position == .beside(.left))
    #expect(abs(p.widthInches - 11) < 1e-9)
}
