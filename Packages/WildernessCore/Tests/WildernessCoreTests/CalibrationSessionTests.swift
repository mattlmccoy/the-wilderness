import Testing
@testable import WildernessCore

private let hd = PixelSize(width: 1920, height: 1080)
private func session() -> CalibrationSession {
    CalibrationSession(start: .defaultFor(artworkAspect: 1.2, output: hd))
}

@Test func selectWalksTheEightHandlesThenReview() {
    var s = session()
    var phases: [CalibrationSession.Phase] = [s.phase]
    for _ in 0..<8 { #expect(s.handle(.select) == nil); phases.append(s.phase) }
    #expect(phases == AlignPoint.allCases.map { .point($0) } + [.review])
}

@Test func selectOnReviewSavesTheAdjustedCalibration() {
    var s = session()
    s.handle(.move(.right))
    let adjusted = s.calibration
    for _ in 0..<8 { s.handle(.select) }
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
    for _ in 0..<8 { s.handle(.select) }
    #expect(s.handle(.back) == nil)
    #expect(s.phase == .point(.leftMiddle))
    #expect(s.calibration == adjusted)
}

@Test func arrowsDoNothingOnReview() {
    var s = session()
    for _ in 0..<8 { s.handle(.select) }
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
    #expect(s.stepLabel == "Top left · 1 of 8")
    for _ in 0..<7 { s.handle(.select) }
    #expect(s.stepLabel == "Left middle · 8 of 8")
    s.handle(.select)
    #expect(s.stepLabel == "Check the outline")
}
