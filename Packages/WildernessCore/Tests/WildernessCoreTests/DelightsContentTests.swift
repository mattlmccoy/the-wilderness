import Foundation
import Testing
@testable import WildernessCore

// Hats and the raven's eye are marked by hand on the painting (App/Content/delights.json); each must sit on
// its own animal, and the star must sit on the canvas, clear of the edges.

private let content = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("App/Content")

@Test func hatsAndTheRavensEyeSitOnTheirAnimals() throws {
    let lib = try AnnotationLibrary.decode(Data(contentsOf: content.appendingPathComponent("annotations.json")))
    let d = try DelightsContent.decode(Data(contentsOf: content.appendingPathComponent("delights.json")))
    #expect(Set(d.hats.map(\.id)).isSuperset(of: ["lion", "stag", "beast"]))
    #expect(d.ravenEye.id == "raven")
    for p in d.hats + [d.ravenEye] {
        let o = try #require(lib.annotations.first { $0.id == p.id }?.outline, "\(p.id) has no outline")
        let xs = o.map(\.x), ys = o.map(\.y)
        #expect(p.x >= xs.min()! - 0.03 && p.x <= xs.max()! + 0.03, "\(p.id) x off its animal")
        #expect(p.y >= ys.min()! - 0.04 && p.y <= ys.max()! + 0.03, "\(p.id) y off its animal")
    }
    #expect(d.star.x > 0.05 && d.star.x < 0.95 && d.star.y > 0.03 && d.star.y < 0.3)
}

@Test func placerOutputDecodesFlipAndStarSize() throws {
    // The shape scripts/placer_template.html writes.
    let json = #"{"hats":[{"id":"lion","x":0.88,"y":0.74,"size":0.05,"tilt":-12,"flip":true},{"id":"fox","x":0.5,"y":0.54,"size":0.026,"tilt":10}],"ravenEye":{"id":"raven","x":0.262,"y":0.195},"star":{"x":0.7,"y":0.07,"size":0.03}}"#
    let d = try DelightsContent.decode(Data(json.utf8))
    #expect(d.hats[0].flip == true)
    #expect(d.hats[1].flip == nil)
    #expect(d.star.size == 0.03)
}

@Test func theCrownSitsOnChristsHeadAndTheCrossStandsClearOfTheFigures() throws {
    let lib = try AnnotationLibrary.decode(Data(contentsOf: content.appendingPathComponent("annotations.json")))
    let d = try DelightsContent.decode(Data(contentsOf: content.appendingPathComponent("delights.json")))
    let halo = try #require(d.halo), cross = try #require(d.cross)
    let christ = try #require(lib.annotations.first { $0.id == "christ" }?.outline)
    // The crown's centre is on Christ's head: inside the top fifth of his outline's box.
    let x0 = christ.map(\.x).min()!, x1 = christ.map(\.x).max()!, y0 = christ.map(\.y).min()!, y1 = christ.map(\.y).max()!
    #expect(halo.x > x0 && halo.x < x1 && halo.y >= y0 - 0.03 && halo.y < y0 + (y1 - y0) * 0.2)
    // The cross stands on open hill: its base point is inside no figure's outline.
    #expect(FigureHitTest.figure(at: .init(x: cross.x, y: cross.y - 0.01), in: lib) == nil)
    #expect((cross.size ?? 0) > 0.02)
}
