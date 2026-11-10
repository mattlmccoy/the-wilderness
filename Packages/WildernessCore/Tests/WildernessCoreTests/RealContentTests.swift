import Foundation
import Testing
@testable import WildernessCore

/// Validates the actual content file the app ships, not a fixture.
private let contentURL = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("App/Content/annotations.json")

@Test func shippedContentDecodesAndValidates() throws {
    let lib = try AnnotationLibrary.decode(Data(contentsOf: contentURL))
    #expect(lib.annotations.count >= 3)
    #expect(abs(lib.artworkAspect - 60.0 / 50.0) < 1e-9)
}

@Test func everyShippedDetailIsReachableByTheRemote() throws {
    let lib = try AnnotationLibrary.decode(Data(contentsOf: contentURL))
    let dirs: [NudgeDirection] = [.left, .right, .up, .down]
    // Breadth-first walk from the first detail using only remote presses.
    var seen: Set<String> = [lib.annotations[0].id], queue = [lib.annotations[0]]
    while let cur = queue.popLast() {
        for d in dirs {
            if let n = SpatialNavigator.next(from: cur, direction: d, among: lib.annotations, artworkAspect: lib.artworkAspect),
               seen.insert(n.id).inserted { queue.append(n) }
        }
    }
    #expect(seen.count == lib.annotations.count, "unreachable: \(Set(lib.annotations.map(\.id)).subtracting(seen))")
}

@Test func everyShippedSubjectHasAnOutline() throws {
    let lib = try AnnotationLibrary.decode(Data(contentsOf: contentURL))
    for a in lib.annotations {
        #expect((a.outline?.count ?? 0) >= 6, "\(a.id) has no usable outline")
    }
}

@Test func shippedShortLinesRespectTheWordLimit() throws {
    let lib = try AnnotationLibrary.decode(Data(contentsOf: contentURL))
    for a in lib.annotations {
        #expect(WordLimits.count(a.short) <= WordLimits.short, "\(a.id): \(WordLimits.count(a.short)) words")
    }
}

@Test func shippedMoreRespectsWordLimits() throws {
    let lib = try AnnotationLibrary.decode(Data(contentsOf: contentURL))
    for a in lib.annotations {
        guard let m = a.more, !m.draft else { continue }
        #expect(WordLimits.count(m.story) <= WordLimits.story, "\(a.id) story")
        for v in m.verses { #expect(WordLimits.count(v.text) <= WordLimits.verse, "\(a.id) \(v.ref)") }
    }
}

private let contentDir = contentURL.deletingLastPathComponent()

@Test func shippedUnfoldDecodesAgainstShippedAnnotations() throws {
    let lib = try AnnotationLibrary.decode(Data(contentsOf: contentURL))
    let script = try UnfoldScript.decode(Data(contentsOf: contentDir.appendingPathComponent("unfold.json")), library: lib)
    #expect(script.beats.count == 8)
    #expect(script.beats.first?.id == "eden" && script.beats.last?.id == "rest-of-story")
}
