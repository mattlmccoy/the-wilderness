import Foundation

/// How soft a lit figure's edge is, in canvas units. Large figures get the full 2.2 in feather;
/// thin ones (the serpent) get a sharper edge, because a blur wider than the shape spreads its
/// light away until almost nothing is left (Matt, notes/regions.json: the serpent is too hard to see).
public enum SubjectFeather {
    public static let maximum = 22.0
    public static let minimum = 6.0
    /// Feather as a share of the shape's mean width.
    static let shareOfWidth = 0.7

    public static func radius(outline: [Point<ArtworkSpace>], canvasWidth: Double, canvasHeight: Double) -> Double {
        let pts = outline.map { (x: $0.x * canvasWidth, y: $0.y * canvasHeight) }
        guard pts.count >= 3 else { return minimum }
        var area = 0.0, perimeter = 0.0
        for i in pts.indices {
            let a = pts[i], b = pts[(i + 1) % pts.count]
            area += a.x * b.y - b.x * a.y
            perimeter += hypot(b.x - a.x, b.y - a.y)
        }
        // Mean width of a shape: twice its area over its perimeter (exact for a long strip).
        let width = perimeter > 0 ? 2 * abs(area / 2) / perimeter : 0
        return min(maximum, max(minimum, width * shareOfWidth))
    }
}
