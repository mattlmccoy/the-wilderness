import Foundation

/// Painting trim: the print shows a little less of the painting than the image (the printer
/// fits a 1.194 image to a 60 × 50 in cloth). The eight handles stay on the cloth's edges; the
/// trim says how many inches of painting each edge lost, and everything drawn is fitted inside
/// the cloth to match, with whatever falls outside masked off so no light reaches the wall.
extension Calibration {
    public static let noTrim = [Double](repeating: 0, count: 4)
    public static let tapestryInches = (w: 60.0, h: 50.0)
    public static let trimStepInches = 1.0 / 16
    public static let maxTrimInches = 3.0

    public var isTrimmed: Bool { trimInches.contains { $0 != 0 } }

    /// The trim as fractions of the painting: (top, right, bottom, left).
    var trimFractions: (t: Double, r: Double, b: Double, l: Double) {
        let i = trimInches.count == 4 ? trimInches : Calibration.noTrim
        let (w, h) = Calibration.tapestryInches
        return (i[0] / h, i[1] / w, i[2] / h, i[3] / w)
    }

    /// Where a point of the painting (0…1) sits on the cloth (0…1); outside 0…1 is off the cloth.
    public func clothPoint(artwork p: Point<ArtworkSpace>) -> Point<ArtworkSpace> {
        let f = trimFractions
        return .init(x: (p.x - f.l) / (1 - f.l - f.r), y: (p.y - f.t) / (1 - f.t - f.b))
    }

    /// The painting's layer as drawn on the cloth: scale and offset, in fractions of the canvas.
    public var trimTransform: (scaleX: Double, scaleY: Double, offsetX: Double, offsetY: Double) {
        let f = trimFractions
        let sx = 1 / (1 - f.l - f.r), sy = 1 / (1 - f.t - f.b)
        return (sx, sy, -f.l * sx, -f.t * sy)
    }

    /// One edge's trim, in sixteenths of an inch, kept within 0…maxTrimInches.
    public mutating func trim(_ edge: AlignEdge, steps: Int) {
        if trimInches.count != 4 { trimInches = Calibration.noTrim }
        let v = trimInches[edge.rawValue] + Double(steps) * Calibration.trimStepInches
        trimInches[edge.rawValue] = min(max(v, 0), Calibration.maxTrimInches)
    }
}
