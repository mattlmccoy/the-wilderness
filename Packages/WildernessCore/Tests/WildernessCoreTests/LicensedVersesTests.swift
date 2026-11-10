import Foundation
import Testing
@testable import WildernessCore

// Fixture text is placeholder wording, never real licensed Bible text.
private func lib(_ verses: [Verse]) -> AnnotationLibrary {
    let more = More(story: "s", verses: verses, connection: .inScripture, draft: true)
    return AnnotationLibrary(artworkAspect: 1.2, annotations: [
        Annotation(id: "christ", title: "t", short: "s", extended: "", references: [], evidence: .documented,
                   anchor: .init(x: 0.5, y: 0.5), outline: nil, textSide: .left, geometrySource: "t", more: more)])
}
private let placeholder = Verse(ref: "Isaiah 53:4", text: "placeholder wording", testament: .old, translation: .bsb)
private let other = Verse(ref: "Hebrews 4:15", text: "other placeholder", testament: .new, translation: .bsb)

@Test func pastedTextReplacesTheVerseAndItsTranslation() {
    let licensed = LicensedVerses(verses: [.init(ref: "Isaiah 53:4", translation: .niv, text: "pasted wording")])
    let out = lib([placeholder, other]).applying(licensed).annotations[0].more!.verses
    #expect(out[0] == Verse(ref: "Isaiah 53:4", text: "pasted wording", testament: .old, translation: .niv))
    #expect(out[1] == other)
}

@Test func blankPastedTextKeepsThePlaceholder() {
    let licensed = LicensedVerses(verses: [.init(ref: "Isaiah 53:4", translation: .esv, text: "   ")])
    #expect(lib([placeholder]).applying(licensed).annotations[0].more!.verses == [placeholder])
}

@Test func unfoldBeatsGetPastedTextToo() {
    let beat = UnfoldBeat(id: "b", duration: 300, light: [["whole"]], textSide: .left, title: "t", short: "s",
                          more: More(story: "s", verses: [other], connection: .inScripture, draft: true), draft: true)
    let licensed = LicensedVerses(verses: [.init(ref: "Hebrews 4:15", translation: .nlt, text: "pasted")])
    #expect(UnfoldScript(beats: [beat]).applying(licensed).beats[0].more!.verses[0].translation == .nlt)
}

@Test func licensedFileDecodesAndRejectsUnknownTranslations() throws {
    let ok = #"{"verses":[{"ref":"John 1:3","translation":"ESV","text":""}]}"#
    #expect(try LicensedVerses.decode(Data(ok.utf8)).verses.count == 1)
    let bad = #"{"verses":[{"ref":"John 1:3","translation":"KJV2","text":"x"}]}"#
    #expect(throws: (any Error).self) { try LicensedVerses.decode(Data(bad.utf8)) }
}
