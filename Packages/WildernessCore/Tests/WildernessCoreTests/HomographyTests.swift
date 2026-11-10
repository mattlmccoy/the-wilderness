import Testing
@testable import WildernessCore

private func close(_ a: Point<ProjectorSpace>, _ b: Point<ProjectorSpace>, tol: Double = 1e-9) -> Bool {
    abs(a.x - b.x) < tol && abs(a.y - b.y) < tol
}

private let unitSquare: [Point<ArtworkSpace>] = [
    .init(x: 0, y: 0), .init(x: 1, y: 0), .init(x: 1, y: 1), .init(x: 0, y: 1),
]

@Test func fourPointSolveMapsCornersExactly() throws {
    // A keystoned quad, as a tilted projector would produce.
    let quad: [Point<ProjectorSpace>] = [
        .init(x: 0.30, y: 0.10), .init(x: 0.72, y: 0.14),
        .init(x: 0.70, y: 0.93), .init(x: 0.27, y: 0.88),
    ]
    let h = try #require(Homography<ArtworkSpace, ProjectorSpace>(from: unitSquare, to: quad))
    for (src, dst) in zip(unitSquare, quad) {
        #expect(close(h.apply(src), dst))
    }
}

private let keystoneQuad: [Point<ProjectorSpace>] = [
    .init(x: 0.30, y: 0.10), .init(x: 0.72, y: 0.14),
    .init(x: 0.70, y: 0.93), .init(x: 0.27, y: 0.88),
]

@Test func collinearCornersAreRejected() {
    let line: [Point<ProjectorSpace>] = [
        .init(x: 0.1, y: 0.1), .init(x: 0.2, y: 0.2), .init(x: 0.3, y: 0.3), .init(x: 0.4, y: 0.9),
    ]
    #expect(Homography<ArtworkSpace, ProjectorSpace>(from: unitSquare, to: line) == nil)
}

@Test func inverseRoundTripsAnInteriorPoint() throws {
    let h = try #require(Homography<ArtworkSpace, ProjectorSpace>(from: unitSquare, to: keystoneQuad))
    let inv = try #require(h.inverted())
    let p = Point<ArtworkSpace>(x: 0.37, y: 0.81)
    let back = inv.apply(h.apply(p))
    #expect(abs(back.x - p.x) < 1e-9 && abs(back.y - p.y) < 1e-9)
}

@Test func compositionAppliesRightThenLeft() throws {
    // camera ← projector and camera ← artwork  ⇒  projector ← artwork (the iPhone calibration chain)
    let camQuad: [Point<CameraSpace>] = [
        .init(x: 0.2, y: 0.3), .init(x: 0.8, y: 0.25), .init(x: 0.85, y: 0.8), .init(x: 0.15, y: 0.75),
    ]
    let artToProj = try #require(Homography<ArtworkSpace, ProjectorSpace>(from: unitSquare, to: keystoneQuad))
    let projToCam = try #require(Homography<ProjectorSpace, CameraSpace>(
        from: [.init(x: 0, y: 0), .init(x: 1, y: 0), .init(x: 1, y: 1), .init(x: 0, y: 1)], to: camQuad))
    let artToCam = projToCam * artToProj
    let recovered = try #require(projToCam.inverted()) * artToCam
    let p = Point<ArtworkSpace>(x: 0.6, y: 0.2)
    #expect(close(recovered.apply(p), artToProj.apply(p)))
}

@Test func rowVectorElementsMatchApplyForSwiftUI() throws {
    // SwiftUI's ProjectionTransform multiplies row vectors: [x y 1] · M.
    let h = try #require(Homography<ArtworkSpace, ProjectorSpace>(from: unitSquare, to: keystoneQuad))
    let m = h.rowVectorElements
    let (x, y) = (0.42, 0.66)
    let w = x * m.m13 + y * m.m23 + m.m33
    let u = (x * m.m11 + y * m.m21 + m.m31) / w
    let v = (x * m.m12 + y * m.m22 + m.m32) / w
    #expect(close(Point(x: u, y: v), h.apply(Point(x: x, y: y))))
}
