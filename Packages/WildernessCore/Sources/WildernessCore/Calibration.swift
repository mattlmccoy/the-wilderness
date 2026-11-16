import Foundation

public struct PixelSize: Equatable, Codable, Sendable {
    public var width: Double
    public var height: Double
    public init(width: Double, height: Double) { self.width = width; self.height = height }
    public var aspect: Double { width / height }
}

/// A saved registration of the tapestry in the projector frame.
/// Corners are normalized ProjectorSpace points in clockwise order: TL, TR, BR, BL.
/// Being normalized, they stay valid across 1080p/4K output switches with the same aspect.
public struct Calibration: Equatable, Codable, Sendable {
    public static let currentVersion = 1

    public var version: Int = Calibration.currentVersion
    public var createdAt: Date = Date()
    public var name: String = "Default"
    public var artworkAspect: Double
    public var output: PixelSize
    public var corners: [Point<ProjectorSpace>]
    /// Top, right, bottom, left: how far each edge's midpoint sits from where the 4-corner
    /// perspective puts it (normalized projector units). Zero = a straight edge.
    public var edgeOffsets: [Point<ProjectorSpace>] = Calibration.straightEdges

    public static let straightEdges = [Point<ProjectorSpace>](repeating: .init(x: 0, y: 0), count: 4)
    /// A bend larger than this is a mistake, not a sagging tapestry (8% of the frame).
    public static let maxEdgeOffset = 0.08

    enum CodingKeys: String, CodingKey { case version, createdAt, name, artworkAspect, output, corners, edgeOffsets }

    /// A starting quad: centred, 80% of the frame height, at the artwork's true aspect on the wall.
    public static func defaultFor(artworkAspect: Double, output: PixelSize) -> Calibration {
        let h = 0.8
        let w = artworkAspect * h * output.height / output.width
        let (x0, y0) = (0.5 - w / 2, 0.5 - h / 2)
        return Calibration(artworkAspect: artworkAspect, output: output, corners: [
            .init(x: x0, y: y0), .init(x: x0 + w, y: y0),
            .init(x: x0 + w, y: y0 + h), .init(x: x0, y: y0 + h),
        ])
    }

    public var artworkToProjector: Homography<ArtworkSpace, ProjectorSpace>? {
        Homography(from: [.init(x: 0, y: 0), .init(x: 1, y: 0), .init(x: 1, y: 1), .init(x: 0, y: 1)],
                   to: corners)
    }

    /// The single transform the renderer applies: canvas points → screen points.
    public func canvasToScreen(canvas: PixelSize, screen: PixelSize) -> Homography<CanvasSpace, ScreenSpace>? {
        guard let h = artworkToProjector else { return nil }
        let toUnit = Homography<CanvasSpace, ArtworkSpace>.scaling(1 / canvas.width, 1 / canvas.height)
        let toScreen = Homography<ProjectorSpace, ScreenSpace>.scaling(screen.width, screen.height)
        return toScreen * h * toUnit
    }

    /// Normalized corners survive a resolution change, not a change of frame shape.
    public func matches(output other: PixelSize) -> Bool {
        abs(output.aspect - other.aspect) < 1e-3
    }

    /// Strictly convex and clockwise (in y-down coordinates). A folded quad has no valid mapping.
    public var isConvex: Bool {
        guard corners.count == 4 else { return false }
        return (0..<4).allSatisfy { i in
            let a = corners[i], b = corners[(i + 1) % 4], c = corners[(i + 2) % 4]
            let cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x)
            return cross > 1e-12
        }
    }
}

extension Calibration {
    /// Saves from before eight-point alignment have no edgeOffsets: their edges stay straight.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(artworkAspect: try c.decode(Double.self, forKey: .artworkAspect),
                  output: try c.decode(PixelSize.self, forKey: .output),
                  corners: try c.decode([Point<ProjectorSpace>].self, forKey: .corners))
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? Calibration.currentVersion
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Default"
        let offsets = try c.decodeIfPresent([Point<ProjectorSpace>].self, forKey: .edgeOffsets)
        edgeOffsets = offsets?.count == 4 ? offsets! : Calibration.straightEdges
    }

    /// How far the bend moves an artwork point (u, v in 0…1), in normalized projector units.
    /// Each edge bows by b(s) = 4s(1−s) — full at its midpoint, zero at the corners — and the
    /// inside blends between the four edges.
    public func bend(u: Double, v: Double) -> (dx: Double, dy: Double) {
        let o = edgeOffsets.count == 4 ? edgeOffsets : Calibration.straightEdges
        let bu = 4 * u * (1 - u), bv = 4 * v * (1 - v)
        let (t, r, b, l) = (o[0], o[1], o[2], o[3])
        let dx = (1 - v) * t.x * bu + v * b.x * bu + (1 - u) * l.x * bv + u * r.x * bv
        let dy = (1 - v) * t.y * bu + v * b.y * bu + (1 - u) * l.y * bv + u * r.y * bv
        return (dx, dy)
    }

    /// Where an artwork point lands in the projector frame: the perspective, then the bend.
    public func projectorPoint(artwork p: Point<ArtworkSpace>) -> Point<ProjectorSpace> {
        guard let h = artworkToProjector else { return .init(x: p.x, y: p.y) }
        let q = h.apply(p), d = bend(u: p.x, v: p.y)
        return .init(x: q.x + d.dx, y: q.y + d.dy)
    }

    /// Where a handle sits on the wall.
    public func handle(_ point: AlignPoint) -> Point<ProjectorSpace> {
        if let i = point.cornerIndex { return corners[i] }
        return projectorPoint(artwork: point.artworkPosition)
    }

    /// Rows of the screen → artwork (0…1) homography, for the bend shader: the shader works out
    /// which artwork point each screen pixel shows, then how far the bend moved it.
    public func screenToArtworkRows(screen: PixelSize) -> [SIMD3<Double>]? {
        guard let h = artworkToProjector else { return nil }
        let toScreen = Homography<ProjectorSpace, ScreenSpace>.scaling(screen.width, screen.height) * h
        guard let inv = toScreen.inverted() else { return nil }
        let m = inv.matrix
        return (0..<3).map { r in SIMD3(m[0][r], m[1][r], m[2][r]) }
    }

    /// True when any edge is bent (the renderer then adds the bend effect).
    public var isBent: Bool { edgeOffsets.contains { $0.x != 0 || $0.y != 0 } }
}

public enum AlignEdge: Int, CaseIterable, Codable, Sendable { case top, right, bottom, left }

/// The eight alignment handles, clockwise from top left.
public enum AlignPoint: Int, CaseIterable, Codable, Sendable {
    case topLeft, topMiddle, topRight, rightMiddle, bottomRight, bottomMiddle, bottomLeft, leftMiddle

    public var label: String {
        ["Top left", "Top middle", "Top right", "Right middle",
         "Bottom right", "Bottom middle", "Bottom left", "Left middle"][rawValue]
    }
    /// Index into `corners` (TL, TR, BR, BL), or nil for a midpoint.
    public var cornerIndex: Int? { [0, nil, 1, nil, 2, nil, 3, nil][rawValue] }
    public var edge: AlignEdge? { [nil, .top, nil, .right, nil, .bottom, nil, .left][rawValue] }
    /// The handle's place on the artwork (0…1).
    public var artworkPosition: Point<ArtworkSpace> {
        let xy: [(Double, Double)] = [(0, 0), (0.5, 0), (1, 0), (1, 0.5), (1, 1), (0.5, 1), (0, 1), (0, 0.5)]
        return .init(x: xy[rawValue].0, y: xy[rawValue].1)
    }
}

extension Homography {
    public static func scaling(_ sx: Double, _ sy: Double) -> Homography {
        Homography(matrix: .init(diagonal: SIMD3(sx, sy, 1)))
    }
}

public enum Corner: Int, CaseIterable, Codable, Sendable { case topLeft, topRight, bottomRight, bottomLeft }
public enum NudgeDirection: String, Codable, Sendable { case up, down, left, right }
public enum NudgeStep: Sendable {
    case coarse, fine
    public var pixels: Double { self == .coarse ? 10 : 1 }
}

/// Remote-driven corner editing. Pure state, no UI.
public struct CornerAdjuster: Sendable {
    public var calibration: Calibration
    public var selected: AlignPoint = .topLeft
    public var step: NudgeStep = .coarse

    public init(calibration: Calibration) { self.calibration = calibration }

    public mutating func nudge(_ direction: NudgeDirection) {
        let dx = step.pixels / calibration.output.width
        let dy = step.pixels / calibration.output.height
        let (mx, my): (Double, Double) = switch direction {
        case .left: (-dx, 0)
        case .right: (dx, 0)
        case .up: (0, -dy)
        case .down: (0, dy)
        }
        if let edge = selected.edge {
            let m = Calibration.maxEdgeOffset
            var o = calibration.edgeOffsets[edge.rawValue]
            o.x = min(max(o.x + mx, -m), m)
            o.y = min(max(o.y + my, -m), m)
            calibration.edgeOffsets[edge.rawValue] = o
            return
        }
        let i = selected.cornerIndex!
        var p = calibration.corners[i]
        p.x = min(max(p.x + mx, 0), 1)
        p.y = min(max(p.y + my, 0), 1)
        var candidate = calibration
        candidate.corners[i] = p
        if candidate.isConvex { calibration = candidate }
    }

    public mutating func select(_ point: AlignPoint) { selected = point }

    public mutating func selectNext() {
        selected = AlignPoint(rawValue: (selected.rawValue + 1) % AlignPoint.allCases.count)!
    }

    public mutating func toggleStep() {
        step = step == .coarse ? .fine : .coarse
    }
}
