import Foundation
import Testing
@testable import WildernessCore

// MARK: protocol

@Test func everyPhoneCommandSurvivesTheWire() throws {
    var t = Tuning.defaults; t.edgeLine = 0.3
    let all: [PhoneCommand] = [.hello, .go(.explore("christ")), .go(.unfold), .go(.context), .playPause, .back,
                               .setTuning(t), .setSound(true), .setShowPainting(false)]
    for c in all {
        let back = try JSONDecoder().decode(PhoneCommand.self, from: JSONEncoder().encode(c))
        #expect(back == c)
    }
}

@Test func framerSplitsLinesAcrossPartialReads() throws {
    var f = LineFramer()
    let a = try LineFramer.frame(PhoneCommand.back), b = try LineFramer.frame(PhoneCommand.playPause)
    let stream = a + b
    let cut = a.count + 3                        // second message arrives in two pieces
    #expect(f.push(stream.prefix(cut)).count == 1)
    let rest = f.push(stream.suffix(from: cut))
    #expect(rest.count == 1)
    #expect(try JSONDecoder().decode(PhoneCommand.self, from: rest[0]) == .playPause)
}

@Test func framerHandlesSeveralMessagesInOneRead() throws {
    var f = LineFramer()
    let data = try LineFramer.frame(PhoneCommand.back) + LineFramer.frame(PhoneCommand.hello) + LineFramer.frame(PhoneCommand.setSound(true))
    #expect(f.push(data).count == 3)
    #expect(f.push(Data()).isEmpty)
}

// MARK: snapshot

private func ann(_ id: String) -> Annotation {
    var a = Annotation(id: id, title: "T-\(id)", short: "S-\(id)", extended: "", references: [], evidence: .documented,
                       anchor: .init(x: 0.5, y: 0.5), outline: nil, textSide: .left, geometrySource: "test")
    a.more = More(story: "Story-\(id)", verses: [
        Verse(ref: "John 1:3", text: "NT words", testament: .new, translation: .niv),
        Verse(ref: "Genesis 1:28", text: "OT words", testament: .old, translation: .niv),
    ], connection: .inScripture, draft: true)
    return a
}
private let lib = AnnotationLibrary(artworkAspect: 1.2, annotations: [ann("christ"), ann("stag")])
private let script = UnfoldScript(beats: [
    UnfoldBeat(id: "b1", duration: 10, light: [["whole"]], textSide: .left, title: "Beat one", short: "Beat short", more: nil, draft: true),
])
private let ctx = ContextScript(pages: [
    ContextPage(id: "p1", title: "Page one", text: "Page text", light: [], visual: nil, textSide: .left, sources: ["s"], draft: true),
])
private func snap(_ m: Mode) -> WallSnapshot {
    WallSnapshot.make(mode: m, library: lib, script: script, context: ctx, tuning: .defaults, soundOn: true, showPainting: false)
}

@Test func exploreSnapshotCarriesTheWholeTextOldTestamentFirst() {
    let s = snap(.explore(id: "christ", expanded: false))
    #expect(s.mode == "explore" && s.subjectId == "christ")
    #expect(s.header == "EXPLORE" && s.title == "T-christ" && s.short == "S-christ" && s.story == "Story-christ")
    #expect(s.verses.map(\.citation) == ["Genesis 1:28 · NIV", "John 1:3 · NIV"])
    #expect(s.soundOn && !s.showPainting)
}

@Test func unfoldAndContextSnapshotsShowTheirPlace() {
    let u = snap(.unfold(.start))
    #expect(u.mode == "unfold" && u.title == "Beat one" && u.header == "UNFOLD · 1 of 1" && !u.paused)
    let c = snap(.context(page: 0))
    #expect(c.mode == "context" && c.title == "Page one" && c.short == "Page text")
}

@Test func restAndMenuSnapshotsHaveNoText() {
    for m: Mode in [.stillness, .menu(focus: .explore), .intro(startedAt: 0)] {
        let s = snap(m)
        #expect(s.title == nil && s.verses.isEmpty && s.subjectId == nil, "\(m)")
    }
}

@Test func snapshotsSurviveTheWire() throws {
    let s = snap(.explore(id: "stag", expanded: true))
    #expect(try JSONDecoder().decode(WallSnapshot.self, from: JSONEncoder().encode(s)) == s)
}

// MARK: tapping the painting on the phone

@Test func aTapInsideAnOutlineFindsThatFigureAndOutsideFindsNothing() {
    var a = ann("christ"); a.outline = [.init(x: 0.6, y: 0.3), .init(x: 0.9, y: 0.3), .init(x: 0.9, y: 0.8), .init(x: 0.6, y: 0.8)]
    var b = ann("stag"); b.outline = [.init(x: 0.1, y: 0.5), .init(x: 0.3, y: 0.5), .init(x: 0.3, y: 0.7)]
    let l = AnnotationLibrary(artworkAspect: 1.2, annotations: [a, b])
    #expect(FigureHitTest.figure(at: .init(x: 0.75, y: 0.5), in: l) == "christ")
    #expect(FigureHitTest.figure(at: .init(x: 0.28, y: 0.55), in: l) == "stag")
    #expect(FigureHitTest.figure(at: .init(x: 0.05, y: 0.05), in: l) == nil)
}

@Test func overlappingOutlinesPickTheSmallerFigure() {
    var big = ann("christ"); big.outline = [.init(x: 0, y: 0), .init(x: 1, y: 0), .init(x: 1, y: 1), .init(x: 0, y: 1)]
    var small = ann("stag"); small.outline = [.init(x: 0.4, y: 0.4), .init(x: 0.6, y: 0.4), .init(x: 0.6, y: 0.6), .init(x: 0.4, y: 0.6)]
    #expect(FigureHitTest.figure(at: .init(x: 0.5, y: 0.5), in: AnnotationLibrary(artworkAspect: 1.2, annotations: [big, small])) == "stag")
}

@Test func thePhoneCanStepLikeTheRemoteArrows() throws {
    #expect(PhoneCommand.move(.right).input == .move(.right))
    #expect(PhoneCommand.move(.left).input == .move(.left))
    let back = try JSONDecoder().decode(PhoneCommand.self, from: LineFramer.frame(PhoneCommand.move(.left)).dropLast())
    #expect(back == .move(.left))
}

@Test func theSnapshotSaysWhenStepsAndPauseMakeSense() {
    #expect(snap(.unfold(.start)).canStep && snap(.unfold(.start)).canPause)
    #expect(snap(.context(page: 0)).canStep && !snap(.context(page: 0)).canPause)
    #expect(snap(.explore(id: "christ", expanded: false)).canStep && !snap(.explore(id: "christ", expanded: false)).canPause)
    #expect(!snap(.stillness).canStep && !snap(.stillness).canPause)
}

// MARK: Review fixes (2026-11-11)

@Test func aLineThatNeverEndsIsDroppedNotHoarded() {
    var f = LineFramer()
    #expect(f.push(Data(repeating: 0x41, count: LineFramer.maxLine + 1)).isEmpty)
    #expect(f.overflowed)
    // After an overflow the framer is clean again and reads the next real line.
    #expect(f.push(Data("x\n{\"hello\":{}}\n".utf8)).map { String(decoding: $0, as: UTF8.self) } == ["{\"hello\":{}}"])
}

@Test func tuningFromThePhoneIsClampedToTheWallsRanges() {
    var t = Tuning.defaults
    t.subjectStrength = 7; t.baseWash = -1; t.edgeLine = 2; t.breathing = 5
    t.glintBrightness = 0; t.glintSizeInches = 9; t.glintMeanInterval = 0.1
    let c = t.clamped
    #expect(c.subjectStrength == 1 && c.baseWash == 0 && c.edgeLine == 1 && c.breathing == 0.3)
    #expect(c.glintBrightness == 0.2 && c.glintSizeInches == 0.6 && c.glintMeanInterval == 4)
    #expect(Tuning.defaults.clamped == .defaults)
}

// MARK: Picking which advertised wall to join (2026-11-15: a stale simulator on the Mac was
// always first in the list, so the phone retried it forever and never reached the Apple TV)

@Test func thePhoneSkipsAWallThatJustFailedWhenAnotherIsAdvertised() {
    let found = ["The Wilderness", "The Wilderness (2)"]
    #expect(WallPicker.pick(found, recentlyFailed: []) == "The Wilderness")
    #expect(WallPicker.pick(found, recentlyFailed: ["The Wilderness"]) == "The Wilderness (2)")
    // If every advertised wall failed recently, try the one that failed longest ago (list order).
    #expect(WallPicker.pick(found, recentlyFailed: ["The Wilderness (2)", "The Wilderness"]) == "The Wilderness (2)")
    #expect(WallPicker.pick([], recentlyFailed: []) == nil)
}
