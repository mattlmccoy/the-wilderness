/// The calibration screen's remote flow. Pure state, no UI.
///   Arrows      → move the current corner
///   Select      → next corner; after the fourth, a review step; Select on review saves
///   Back        → on review, return to the last corner; otherwise cancel without saving
///   Play/Pause  → toggle coarse / fine steps
public struct CalibrationSession: Sendable {
    public enum Phase: Equatable, Sendable { case corner(Corner), review }
    public enum Input: Sendable { case move(NudgeDirection), select, back, playPause }
    public enum Outcome: Equatable, Sendable { case save(Calibration), cancel }

    public private(set) var phase: Phase = .corner(.topLeft)
    private var adjuster: CornerAdjuster

    public init(start: Calibration) { adjuster = CornerAdjuster(calibration: start) }

    public var calibration: Calibration { adjuster.calibration }
    public var step: NudgeStep { adjuster.step }

    @discardableResult
    public mutating func handle(_ input: Input) -> Outcome? {
        switch (input, phase) {
        case let (.move(direction), .corner):
            adjuster.nudge(direction)
        case (.move, .review):
            break
        case (.select, .corner(.bottomLeft)):
            phase = .review
        case (.select, .corner):
            adjuster.selectNext()
            phase = .corner(adjuster.selected)
        case (.select, .review):
            return .save(adjuster.calibration)
        case (.back, .review):
            phase = .corner(adjuster.selected)
        case (.back, .corner):
            return .cancel
        case (.playPause, _):
            adjuster.toggleStep()
        }
        return nil
    }

    public var stepLabel: String {
        switch phase {
        case .review: return "Check the outline"
        case let .corner(c): return "\(c.label) · \(c.rawValue + 1) of 4"
        }
    }
}

extension Corner {
    public var label: String {
        switch self {
        case .topLeft: "Top left"
        case .topRight: "Top right"
        case .bottomRight: "Bottom right"
        case .bottomLeft: "Bottom left"
        }
    }
}
