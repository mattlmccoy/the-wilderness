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

public enum ColumnPosition: Equatable, Sendable {
    /// On the painting itself, in a calm dark zone (Matt's wall has no room beside it).
    case onCanvas(TextZone)
}

public struct ColumnPlacement: Equatable, Sendable {
    public var position: ColumnPosition
    public var widthInches: Double
    public init(position: ColumnPosition, widthInches: Double) {
        self.position = position; self.widthInches = widthInches
    }
}

/// Where the wall text goes: always on the painting (Matt: there is no room beside, above or below
/// the tapestry on his wall), in a calm zone, or the fallback zone if none is known.
public enum TextColumnLayout {
    public static func place(preferred: TextSide, calibration: Calibration,
                             canvasZone: TextZone? = nil) -> ColumnPlacement {
        let z = canvasZone ?? .fallback
        return ColumnPlacement(position: .onCanvas(z), widthInches: z.w * Calibration.tapestryInches.w)
    }
}
