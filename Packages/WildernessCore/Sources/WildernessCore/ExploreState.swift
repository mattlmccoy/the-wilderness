public enum RemoteInput: Sendable { case move(NudgeDirection), select, back }

/// The Explore experience as a tiny state machine, independent of any UI.
///   idle (dark) ── any arrow ──▶ exploring(first detail)
///   exploring ── arrow ──▶ nearest detail that way (longer text stays open if it was); no neighbour → stay
///   exploring ── select ──▶ toggle longer text (it persists across details until toggled off)
///   exploring ── back ──▶ idle;   idle ── back ──▶ exit (returns true)
public enum ExploreState: Equatable, Sendable {
    case idle
    case exploring(id: String, expanded: Bool)

    /// Returns true when the input should leave the experience (Menu on a dark wall).
    @discardableResult
    public mutating func handle(_ input: RemoteInput, library: AnnotationLibrary) -> Bool {
        switch (self, input) {
        case (.idle, .move):
            if let first = library.annotations.first { self = .exploring(id: first.id, expanded: false) }
        case (.idle, .select):
            break
        case (.idle, .back):
            return true
        case let (.exploring(id, expanded), .move(direction)):
            guard let current = library.annotations.first(where: { $0.id == id }),
                  let next = SpatialNavigator.next(from: current, direction: direction,
                                                   among: library.annotations,
                                                   artworkAspect: library.artworkAspect)
            else { return false }
            self = .exploring(id: next.id, expanded: expanded)
        case let (.exploring(id, expanded), .select):
            self = .exploring(id: id, expanded: !expanded)
        case (.exploring, .back):
            self = .idle
        }
        return false
    }
}
