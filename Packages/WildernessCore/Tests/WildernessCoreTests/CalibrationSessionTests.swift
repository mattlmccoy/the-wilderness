import Testing
@testable import WildernessCore

private let hd = PixelSize(width: 1920, height: 1080)
private func session() -> CalibrationSession {
    CalibrationSession(start: .defaultFor(artworkAspect: 1.2, output: hd))
}

@Test func selectWalksTheFourCornersThenReview() {
    var s = session()
    var phases: [CalibrationSession.Phase] = [s.phase]
    for _ in 0..<4 { #expect(s.handle(.select) == nil); phases.append(s.phase) }
    #expect(phases == [.corner(.topLeft), .corner(.topRight), .corner(.bottomRight), .corner(.bottomLeft), .review])
}

@Test func selectOnReviewSavesTheAdjustedCalibration() {
    var s = session()
    s.handle(.move(.right))
    let adjusted = s.calibration
    for _ in 0..<4 { s.handle(.select) }
    #expect(s.handle(.select) == .save(adjusted))
}

@Test func backWhileAdjustingCancelsWithoutSaving() {
    var s = session()
    s.handle(.move(.down))
    #expect(s.handle(.back) == .cancel)
}

@Test func backOnReviewReturnsToTheLastCornerAndKeepsChanges() {
    var s = session()
    s.handle(.move(.left))
    let adjusted = s.calibration
    for _ in 0..<4 { s.handle(.select) }
    #expect(s.handle(.back) == nil)
    #expect(s.phase == .corner(.bottomLeft))
    #expect(s.calibration == adjusted)
}

@Test func arrowsDoNothingOnReview() {
    var s = session()
    for _ in 0..<4 { s.handle(.select) }
    let before = s.calibration
    s.handle(.move(.up))
    #expect(s.calibration == before)
}

@Test func playPauseTogglesFineAndCoarse() {
    var s = session()
    #expect(s.step == .coarse)
    s.handle(.playPause)
    #expect(s.step == .fine)
}

@Test func stepLabelNamesTheCornerAndProgress() {
    var s = session()
    #expect(s.stepLabel == "Top left · 1 of 4")
    for _ in 0..<3 { s.handle(.select) }
    #expect(s.stepLabel == "Bottom left · 4 of 4")
    s.handle(.select)
    #expect(s.stepLabel == "Check the outline")
}
