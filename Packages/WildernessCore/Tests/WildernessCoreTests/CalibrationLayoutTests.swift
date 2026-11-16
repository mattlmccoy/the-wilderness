import Foundation
import Testing
@testable import WildernessCore

// The alignment screen's instructions never sit on the tapestry (Matt, 2026-11-16: they overlapped
// the box at the bottom).

private func quad(top: Double, bottom: Double, left: Double = 0.2, right: Double = 0.8) -> [Point<ProjectorSpace>] {
    [.init(x: left, y: top), .init(x: right, y: top), .init(x: right, y: bottom), .init(x: left, y: bottom)]
}

@Test func instructionsGoBelowWhenThereIsRoom() {
    #expect(CalibrationLayout.instructions(handles: quad(top: 0.1, bottom: 0.7), height: 0.12, width: 0.3) == .below)
}

@Test func instructionsGoAboveWhenTheTapestryFillsTheBottom() {
    #expect(CalibrationLayout.instructions(handles: quad(top: 0.25, bottom: 0.97), height: 0.12, width: 0.3) == .above)
}

@Test func withNoRoomEitherWayTheyTakeTheBiggerGap() {
    #expect(CalibrationLayout.instructions(handles: quad(top: 0.06, bottom: 0.96), height: 0.12, width: 0.3) == .above)
    #expect(CalibrationLayout.instructions(handles: quad(top: 0.02, bottom: 0.93), height: 0.12, width: 0.3) == .below)
}

@Test func aBentEdgeCountsToo() {
    // The bottom midpoint bows down into the room the corners leave.
    var h = quad(top: 0.2, bottom: 0.8)
    h.append(.init(x: 0.5, y: 0.93))
    #expect(CalibrationLayout.instructions(handles: h, height: 0.12, width: 0.3) == .above)
}

@Test func aTallTapestryPutsThemBesideIt() {
    // The cloth fills the height (the simulator, and Matt's wall): the side with more room.
    #expect(CalibrationLayout.instructions(handles: quad(top: 0.1, bottom: 0.9, left: 0.24, right: 0.7),
                                           height: 0.13, width: 0.2) == .right)
    #expect(CalibrationLayout.instructions(handles: quad(top: 0.1, bottom: 0.9, left: 0.3, right: 0.77),
                                           height: 0.13, width: 0.2) == .left)
}
