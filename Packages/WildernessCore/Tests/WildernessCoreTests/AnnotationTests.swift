import Foundation
import Testing
@testable import WildernessCore

private func a(_ id: String, _ x: Double, _ y: Double) -> Annotation {
    Annotation(id: id, title: id, short: "", extended: "", references: [], evidence: .documented,
               anchor: .init(x: x, y: y), outline: nil, textSide: .left, geometrySource: "test")
}

// Anchors estimated from the Met reference image (see content/annotations.json).
private let stag = a("stag", 0.19, 0.59), fox = a("fox", 0.48, 0.59), christ = a("christ", 0.77, 0.52)
private let angels = a("angels", 0.85, 0.18), lion = a("lion", 0.91, 0.75), basilisk = a("basilisk", 0.41, 0.64)
private let all = [stag, fox, christ, angels, lion, basilisk]

@Test func rightFromStagPrefersTheNearestDetailInLine() {
    #expect(SpatialNavigator.next(from: stag, direction: .right, among: all, artworkAspect: 1.2)?.id == "basilisk")
}

@Test func upFromChristReachesTheAngels() {
    #expect(SpatialNavigator.next(from: christ, direction: .up, among: all, artworkAspect: 1.2)?.id == "angels")
}

@Test func nothingInThatDirectionReturnsNil() {
    #expect(SpatialNavigator.next(from: lion, direction: .right, among: all, artworkAspect: 1.2) == nil)
}

@Test func libraryDecodesAndKeepsOrder() throws {
    let json = #"""
    {"artworkAspect": 1.2, "annotations": [
      {"id":"christ","title":"Christ","short":"s","extended":"e","references":["Mark 1:13"],
       "evidence":"documented","anchor":{"x":0.77,"y":0.52},"textSide":"left","geometrySource":"met-reference-estimate"}
    ]}
    """#
    let lib = try AnnotationLibrary.decode(Data(json.utf8))
    #expect(lib.annotations.map(\.id) == ["christ"])
    #expect(lib.annotations[0].outline == nil)
}

@Test func libraryRejectsAnchorsOutsideTheArtwork() {
    let json = #"{"artworkAspect":1.2,"annotations":[{"id":"x","title":"","short":"","extended":"","references":[],"evidence":"plausible","anchor":{"x":1.4,"y":0.5},"textSide":"left","geometrySource":"t"}]}"#
    #expect(throws: AnnotationLibrary.ValidationError.self) { try AnnotationLibrary.decode(Data(json.utf8)) }
}

@Test func libraryRejectsDuplicateIDs() {
    let one = #"{"id":"x","title":"","short":"","extended":"","references":[],"evidence":"plausible","anchor":{"x":0.4,"y":0.5},"textSide":"left","geometrySource":"t"}"#
    let json = #"{"artworkAspect":1.2,"annotations":[\#(one),\#(one)]}"#
    #expect(throws: AnnotationLibrary.ValidationError.self) { try AnnotationLibrary.decode(Data(json.utf8)) }
}
