import Foundation
import Testing
@testable import WildernessCore

// Hats and eyes are marked by hand on the painting (App/Content/delights.json); each must sit on
// its own animal, and the star must sit on the canvas, clear of the edges.

private let content = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("App/Content")

@Test func hatsAndEyesSitOnTheirAnimals() throws {
    let lib = try AnnotationLibrary.decode(Data(contentsOf: content.appendingPathComponent("annotations.json")))
    let d = try DelightsContent.decode(Data(contentsOf: content.appendingPathComponent("delights.json")))
    #expect(Set(d.hats.map(\.id)).isSuperset(of: ["lion", "stag", "beast"]))
    #expect(d.eyes.count >= 4)
    for p in d.hats + d.eyes {
        let o = try #require(lib.annotations.first { $0.id == p.id }?.outline, "\(p.id) has no outline")
        let xs = o.map(\.x), ys = o.map(\.y)
        #expect(p.x >= xs.min()! - 0.03 && p.x <= xs.max()! + 0.03, "\(p.id) x off its animal")
        #expect(p.y >= ys.min()! - 0.04 && p.y <= ys.max()! + 0.03, "\(p.id) y off its animal")
    }
    #expect(d.star.x > 0.05 && d.star.x < 0.95 && d.star.y > 0.03 && d.star.y < 0.3)
}
