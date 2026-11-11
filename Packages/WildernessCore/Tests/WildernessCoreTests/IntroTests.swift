import Foundation
import Testing
@testable import WildernessCore

// The boot-up intro (approved by Matt, 2026-11-10): Christ is outlined first, then the beasts
// that bow, then the peaceable animals, then the angels; the lines soften into a faint glow,
// and the glows fade together into Stillness at about 15 s.

private let groups: [[String]] = [["christ"], ["snake", "lion", "basilisk"], ["pelican", "bear", "fox", "stag"], ["angels"]]
private let timeline = IntroTimeline(groups: groups)
private let everyone = groups.flatMap { $0 }
private let contentURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("App/Content/annotations.json")

private func subject(_ id: String, outlined: Bool) -> Annotation {
    let square: [Point<ArtworkSpace>] = [.init(x: 0.1, y: 0.1), .init(x: 0.2, y: 0.1), .init(x: 0.2, y: 0.2)]
    return Annotation(id: id, title: id, short: "", extended: "", references: [], evidence: .documented,
                      anchor: .init(x: 0.5, y: 0.5), outline: outlined ? square : nil, textSide: .left, geometrySource: "test")
}

// MARK: - Order

@Test func introOrderIsChristThenBeastsThatBowThenPeaceableAnimalsThenAngels() {
    #expect(IntroOrder.groups.count == 4)
    #expect(IntroOrder.groups.first == ["christ"])
    #expect(IntroOrder.groups.last == ["angels"])
    let ids = IntroOrder.groups.flatMap { $0 }
    #expect(Set(ids).count == ids.count, "a subject is traced twice")
}

@Test func introOrderTracesEveryShippedFigureButNotTheTreeOrTheMissingPicture() throws {
    let lib = try AnnotationLibrary.decode(Data(contentsOf: contentURL))
    let traced = Set(IntroOrder.groups.flatMap { $0 })
    let shipped = Set(lib.annotations.map(\.id))
    #expect(traced.isSubset(of: shipped), "order names unknown ids: \(traced.subtracting(shipped))")
    #expect(shipped.subtracting(traced) == ["tree", "fragment"])
}

@Test func introSkipsSubjectsWithoutAnOutlineAndDropsEmptyGroups() {
    let lib = AnnotationLibrary(artworkAspect: 1.2, annotations: [
        subject("christ", outlined: true), subject("lion", outlined: false),
        subject("fox", outlined: true), subject("angels", outlined: false),
    ])
    let order: [[String]] = [["christ"], ["lion"], ["fox", "stag"], ["angels"]]
    #expect(IntroOrder.groups(order, in: lib) == [["christ"], ["fox"]])
}

// MARK: - Timeline

@Test func wallStartsDarkThenChristIsOutlinedOverTheFirstTwoSeconds() {
    for id in everyone { #expect(timeline.frame(id, at: 0) == .dark, "\(id) shows at 0 s") }
    let mid = timeline.frame("christ", at: 1.2)
    #expect(mid.drawProgress > 0.2 && mid.drawProgress < 0.9)
    #expect(mid.line == 1 && mid.glow == 0)
    #expect(timeline.frame("christ", at: 2.0).drawProgress == 1)
    for id in everyone.dropFirst() { #expect(timeline.frame(id, at: 2.0).drawProgress == 0, "\(id) began with Christ") }
}

@Test func otherFiguresDrawInOrderEachInUnderASecondAndAllByTenSeconds() throws {
    var lastStart = 2.0
    for id in everyone.dropFirst() {
        let start = try #require(timeline.drawStart(id))
        #expect(start > lastStart, "\(id) is out of order")
        #expect(timeline.drawDuration < 1.0)
        #expect(start + timeline.drawDuration <= IntroTimeline.traceEnd + 1e-9)
        lastStart = start
    }
    #expect(timeline.frame("angels", at: IntroTimeline.traceEnd).drawProgress == 1)
}

@Test func drawingsOverlapAndGroupsArePausedBetween() throws {
    let s = try ["snake", "lion", "basilisk", "pelican"].map { try #require(timeline.drawStart($0)) }
    #expect(s[1] - s[0] < timeline.drawDuration, "neighbours should overlap")
    #expect(s[3] - s[2] > (s[1] - s[0]) * 1.5, "no breath between the beasts that bow and the peaceable animals")
}

@Test func linesSoftenIntoAFaintGlowThenAllGlowsFadeTogetherAtFifteenSeconds() {
    let soft = timeline.frame("stag", at: 11.0)
    #expect(soft.line > 0 && soft.line < 1 && soft.glow > 0 && soft.glow < 1)
    for id in everyone {
        let f = timeline.frame(id, at: IntroTimeline.fadeStart)
        #expect(f.line < 0.01 && f.glow > 0.99, "\(id) has not softened by the fade")
    }
    let fading = everyone.map { timeline.frame($0, at: 14.0).glow }
    #expect(Set(fading).count == 1, "glows should fade together")
    #expect(fading[0] > 0 && fading[0] < 1)
    for id in everyone { #expect(timeline.frame(id, at: IntroTimeline.duration).glow == 0) }
}

@Test func introLastsAboutFifteenSeconds() {
    #expect(IntroTimeline.duration == 15)
    #expect(!IntroTimeline.isFinished(at: 14.9))
    #expect(IntroTimeline.isFinished(at: 15))
}

@Test func drawingNeverRunsBackwards() {
    for id in everyone {
        var last = 0.0
        for step in 0...300 {
            let p = timeline.frame(id, at: Double(step) * 0.05).drawProgress
            #expect(p >= last); last = p
        }
    }
}

@Test func unknownSubjectStaysDark() {
    #expect(timeline.frame("tree", at: 5) == .dark)
}
