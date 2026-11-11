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
    public var selected: Corner = .topLeft
    public var step: NudgeStep = .coarse

    public init(calibration: Calibration) { self.calibration = calibration }

    public mutating func nudge(_ direction: NudgeDirection) {
        let dx = step.pixels / calibration.output.width
        let dy = step.pixels / calibration.output.height
        var p = calibration.corners[selected.rawValue]
        switch direction {
        case .left: p.x -= dx
        case .right: p.x += dx
        case .up: p.y -= dy
        case .down: p.y += dy
        }
        p.x = min(max(p.x, 0), 1)
        p.y = min(max(p.y, 0), 1)
        var candidate = calibration
        candidate.corners[selected.rawValue] = p
        if candidate.isConvex { calibration = candidate }
    }

    public mutating func selectNext() {
        selected = Corner(rawValue: (selected.rawValue + 1) % 4)!
    }

    public mutating func toggleStep() {
        step = step == .coarse ? .fine : .coarse
    }
}
