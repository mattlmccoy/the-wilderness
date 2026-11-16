import Foundation

/// Where the alignment screen's instructions go so they never sit on the tapestry: below it if
/// there is room, otherwise above, otherwise beside it on the side with more room (a tapestry
/// that fills the height, as on Matt's wall), otherwise the biggest gap there is. Points are the
/// live handles (corners and edge midpoints, so a bowed edge counts), normalized to the screen;
/// `height` and `width` are the instructions' size laid out across (above/below) or stacked (beside).
public enum CalibrationLayout {
    public enum Place: Equatable, Sendable { case above, below, left, right }
    /// Clear space kept between the instructions and the tapestry, as a fraction of the screen.
    public static let margin = 0.02

    public static func instructions(handles: [Point<ProjectorSpace>], height: Double, width: Double) -> Place {
        let ys = handles.map(\.y), xs = handles.map(\.x)
        let below = 1 - (ys.max() ?? 1), above = ys.min() ?? 0
        let right = 1 - (xs.max() ?? 1), left = xs.min() ?? 0
        if below >= height + margin { return .below }
        if above >= height + margin { return .above }
        if max(left, right) >= width + margin { return right >= left ? .right : .left }
        return below >= above ? .below : .above
    }
}
