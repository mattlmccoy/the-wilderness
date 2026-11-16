/// The calibration screen's flow (remote and phone). Pure state, no UI.
///   Arrows      → move the current handle (a corner, or bend an edge at its midpoint)
///   Select      → next handle; after the eighth, a review step; Select on review saves
///   Pick        → (phone) jump straight to a handle
///   Back        → on review, return to the last handle; otherwise cancel without saving
///   Play/Pause  → toggle coarse / fine steps
public struct CalibrationSession: Sendable {
    public enum Phase: Equatable, Sendable { case point(AlignPoint), review }
    public enum Input: Sendable { case move(NudgeDirection), select, back, playPause, pick(AlignPoint) }
    public enum Outcome: Equatable, Sendable { case save(Calibration), cancel }

    public private(set) var phase: Phase = .point(.topLeft)
    private var adjuster: CornerAdjuster

    public init(start: Calibration) { adjuster = CornerAdjuster(calibration: start) }

    public var calibration: Calibration { adjuster.calibration }
    public var step: NudgeStep { adjuster.step }
    public var selected: AlignPoint { adjuster.selected }

    @discardableResult
    public mutating func handle(_ input: Input) -> Outcome? {
        switch (input, phase) {
        case let (.move(direction), .point):
            adjuster.nudge(direction)
        case (.move, .review):
            break
        case (.select, .point(.leftMiddle)):
            phase = .review
        case (.select, .point):
            adjuster.selectNext()
            phase = .point(adjuster.selected)
        case (.select, .review):
            return .save(adjuster.calibration)
        case let (.pick(p), _):
            adjuster.select(p)
            phase = .point(p)
        case (.back, .review):
            phase = .point(adjuster.selected)
        case (.back, .point):
            return .cancel
        case (.playPause, _):
            adjuster.toggleStep()
        }
        return nil
    }

    public var stepLabel: String {
        switch phase {
        case .review: return "Check the outline"
        case let .point(p): return "\(p.label) · \(p.rawValue + 1) of \(AlignPoint.allCases.count)"
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
