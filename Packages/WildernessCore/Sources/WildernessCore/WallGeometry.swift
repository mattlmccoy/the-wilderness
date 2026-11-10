import Foundation

/// Physical sizes on the wall, from the saved calibration (spec §2, §5.2).
public enum WallGeometry {
    /// Projector pixels per inch on the tapestry: mean of its top and bottom edge lengths ÷ its width.
    public static func pixelsPerInch(_ c: Calibration, artworkWidthInches: Double = 60) -> Double {
        let w = c.output.width, h = c.output.height
        func len(_ a: Point<ProjectorSpace>, _ b: Point<ProjectorSpace>) -> Double {
            hypot((b.x - a.x) * w, (b.y - a.y) * h)
        }
        let k = c.corners
        return (len(k[0], k[1]) + len(k[3], k[2])) / 2 / artworkWidthInches
    }

    /// Bare wall between the tapestry's edge and the edge of the projected frame, in inches.
    public static func wallInches(_ c: Calibration, side: TextSide, artworkWidthInches: Double = 60) -> Double {
        let k = c.corners
        let px = switch side {
        case .left: min(k[0].x, k[3].x) * c.output.width
        case .right: (1 - max(k[1].x, k[2].x)) * c.output.width
        }
        return max(px, 0) / pixelsPerInch(c, artworkWidthInches: artworkWidthInches)
    }
}

public enum ColumnPosition: Equatable, Sendable { case beside(TextSide), overLowerEdge }

public struct ColumnPlacement: Equatable, Sendable {
    public var position: ColumnPosition
    public var widthInches: Double
    public init(position: ColumnPosition, widthInches: Double) {
        self.position = position; self.widthInches = widthInches
    }
}

/// Where the wall text goes: beside the tapestry if a side has room, else over its lower edge.
public enum TextColumnLayout {
    public static let maxWidth = 19.0, minWidth = 14.0, gap = 3.0, margin = 1.0

    public static func place(preferred: TextSide, calibration: Calibration) -> ColumnPlacement {
        let other: TextSide = preferred == .left ? .right : .left
        for side in [preferred, other] {
            let width = min(maxWidth, WallGeometry.wallInches(calibration, side: side) - gap - margin)
            if width >= minWidth { return ColumnPlacement(position: .beside(side), widthInches: width) }
        }
        return ColumnPlacement(position: .overLowerEdge, widthInches: maxWidth)
    }
}
