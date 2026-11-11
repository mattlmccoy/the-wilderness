import Foundation
import Testing
@testable import WildernessCore

private func a(_ id: String) -> Annotation {
    Annotation(id: id, title: id, short: "", extended: "", references: [], evidence: .documented,
               anchor: .init(x: 0.5, y: 0.5), outline: nil, textSide: .left, geometrySource: "test")
}
private let lib = AnnotationLibrary(artworkAspect: 1.2, annotations: [a("christ"), a("fragment")])

private func json(_ pages: String) -> Data { Data(#"{"pages": [\#(pages)]}"#.utf8) }
private func page(_ id: String, light: String = "", visual: String = "null", text: String = "Words.") -> String {
    #"{"id":"\#(id)","title":"T","text":"\#(text)","light":[\#(light)],"visual":\#(visual),"textSide":"left","sources":["Met"],"draft":true}"#
}

@Test func contextDecodesPagesWithLightAndVisuals() throws {
    let s = try ContextScript.decode(json(page("a", visual: #""trueSize""#) + "," + page("b", light: #""fragment""#)), library: lib)
    #expect(s.pages.map(\.id) == ["a", "b"])
    #expect(s.pages[0].visual == .trueSize)
    #expect(s.pages[0].map == nil && s.pages[0].image == nil)
    #expect(s.pages[1].light == ["fragment"])
}

@Test func contextRejectsEmptyDuplicateBlankAndUnknownTargets() {
    #expect(throws: (any Error).self) { try ContextScript.decode(json(""), library: lib) }
    #expect(throws: (any Error).self) { try ContextScript.decode(json(page("a") + "," + page("a")), library: lib) }
    #expect(throws: (any Error).self) { try ContextScript.decode(json(page("a", text: "  ")), library: lib) }
    #expect(throws: (any Error).self) { try ContextScript.decode(json(page("a", light: #""unicorn""#)), library: lib) }
}

@Test func theRealContextFileDecodesAgainstTheRealLibrary() throws {
    let content = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
        .appendingPathComponent("../../../../App/Content").standardized
    let library = try AnnotationLibrary.decode(Data(contentsOf: content.appendingPathComponent("annotations.json")))
    let maps = try ContextMaps.decode(Data(contentsOf: content.appendingPathComponent("maps.json")))
    let s = try ContextScript.decode(Data(contentsOf: content.appendingPathComponent("context.json")),
                                     library: library, maps: maps)
    #expect(s.pages.count >= 5)
    #expect(s.pages.allSatisfy { !$0.sources.isEmpty }, "every page cites where its facts come from")
}

@Test func trueSizeFrameIsTheMetCanvasCentredOnTheTapestry() {
    // Met: oil on canvas, 18 x 21 3/4 in. Canvas units: 20 per inch, tapestry 1200 x 1000.
    let f = OriginalCanvas.trueSizeFrame(canvasWidth: 1200, canvasHeight: 1000, unitsPerInch: 20)
    #expect(f.width == 435 && f.height == 360)
    #expect(f.x == 382.5 && f.y == 320)
}
