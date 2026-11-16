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

// Matt, 2026-11-16: "we don't have room for any text or instructions to sit beside the tapestry!"
// Text never leaves the canvas, whatever the wall looks like and even if the calm zones are missing.

@Test func withNoCalmZoneKnownTextStillSitsOnTheCanvas() {
    for cal in [Calibration.defaultFor(artworkAspect: 1.2, output: hd), rect(x0: 0.30, x1: 0.95), rect(x0: 0.05, x1: 0.95)] {
        for side in [TextSide.left, .right] {
            let p = TextColumnLayout.place(preferred: side, calibration: cal)
            #expect(p.position == .onCanvas(TextZone.fallback))
        }
    }
}

@Test func theFallbackZoneIsOnTheTapestry() {
    let z = TextZone.fallback
    #expect(z.x >= 0 && z.y >= 0 && z.x + z.w <= 1 && z.y + z.h <= 1)
}

@Test func theAlignmentInstructionsAlwaysHaveAPlaceOnTheCanvas() {
    let lib = AnnotationLibrary(artworkAspect: 1.2, annotations: [])
    #expect(CanvasText.instructionsZone(library: lib, zones: []) == TextZone.fallback)
    let calm = TextZone(x: 0.1, y: 0.7, w: 0.34, h: 0.24, score: 0.9)
    #expect(CanvasText.instructionsZone(library: lib, zones: [calm]) == calm)
}
