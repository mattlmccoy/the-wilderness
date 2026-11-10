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
