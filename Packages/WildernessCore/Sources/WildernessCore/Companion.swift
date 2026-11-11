import Foundation

/// The phone companion's wire protocol (docs/superpowers/specs/2026-11-11-iphone-companion-design.md).
/// Local network only; newline-delimited JSON over one TCP connection.

/// Phone → Apple TV.
public enum PhoneCommand: Codable, Equatable, Sendable {
    /// Sent on connect; the TV answers with a snapshot.
    case hello
    case go(Destination)
    /// The remote's arrows: next/previous page, beat or figure.
    case move(NudgeDirection)
    case playPause
    case back
    case setTuning(Tuning)
    case setSound(Bool)
    case setShowPainting(Bool)

    /// The remote-equivalent input, for commands that drive the mode machine.
    public var input: AppInput? {
        switch self {
        case let .go(d): .go(d)
        case let .move(d): .move(d)
        case .playPause: .playPause
        case .back: .back
        default: nil
        }
    }
}

/// Apple TV → phone: what the wall is showing now, plus the settings the phone edits.
public struct WallSnapshot: Codable, Equatable, Sendable {
    /// Left/right step through something here (Unfold beats, Context pages, Explore figures).
    public var canStep: Bool { ["unfold", "context", "explore"].contains(mode) }
    /// Pause only means something in Unfold. (On the remote, Play/Pause elsewhere starts
    /// Unfold; the phone shows the button only where it pauses.)
    public var canPause: Bool { mode == "unfold" }

    public struct ShownVerse: Codable, Equatable, Sendable {
        public var text: String
        public var citation: String
    }

    /// "rest", "menu", "intro", "explore", "unfold", "context", "settings", "calibrating".
    public var mode: String
    public var subjectId: String?
    public var header: String?
    public var title: String?
    public var short: String?
    public var story: String?
    public var verses: [ShownVerse]
    public var paused: Bool
    public var tuning: Tuning
    public var soundOn: Bool
    public var showPainting: Bool

    public static func make(mode: Mode, library: AnnotationLibrary, script: UnfoldScript, context: ContextScript,
                            tuning: Tuning, soundOn: Bool, showPainting: Bool) -> WallSnapshot {
        var s = WallSnapshot(mode: Self.name(mode), subjectId: nil,
                             header: mode.wayfinding(library: library, script: script, context: context),
                             title: nil, short: nil, story: nil, verses: [], paused: false,
                             tuning: tuning, soundOn: soundOn, showPainting: showPainting)
        switch mode {
        case let .explore(id, _):
            guard let a = library.annotations.first(where: { $0.id == id }) else { break }
            s.subjectId = id
            s.fill(title: a.title, short: a.short, more: a.more)
        case let .unfold(p) where script.beats.indices.contains(p.beat):
            let b = script.beats[p.beat]
            s.paused = p.paused
            s.fill(title: b.title, short: b.short, more: b.more)
        case let .context(page) where context.pages.indices.contains(page):
            s.title = context.pages[page].title
            s.short = context.pages[page].text
        default:
            break
        }
        return s
    }

    private mutating func fill(title: String, short: String, more: More?) {
        self.title = title
        self.short = short
        story = more?.story
        // Same order as the wall: Old Testament first.
        let ordered = (more?.verses ?? []).sorted { ($0.testament == .old ? 0 : 1) < ($1.testament == .old ? 0 : 1) }
        verses = ordered.map { ShownVerse(text: $0.text, citation: "\($0.ref) · \($0.translation.rawValue)") }
    }

    private static func name(_ m: Mode) -> String {
        switch m {
        case .stillness: "rest"
        case .menu: "menu"
        case .intro: "intro"
        case .explore: "explore"
        case .unfold: "unfold"
        case .context: "context"
        case .calibrating: "calibrating"
        case .settings, .tuning, .pattern, .about: "settings"
        }
    }
}

/// Splits a byte stream into newline-delimited messages, across partial reads.
public struct LineFramer: Sendable {
    private var pending = Data()
    public init() {}

    public mutating func push(_ data: Data) -> [Data] {
        pending.append(data)
        var out: [Data] = []
        while let nl = pending.firstIndex(of: 0x0A) {
            let line = pending[pending.startIndex..<nl]
            if !line.isEmpty { out.append(Data(line)) }
            pending = Data(pending[pending.index(after: nl)...])
        }
        return out
    }

    public static func frame<T: Encodable>(_ value: T) throws -> Data {
        var d = try JSONEncoder().encode(value)
        d.append(0x0A)
        return d
    }
}

/// Which figure a tap on the phone's painting lands on: inside its traced outline; where outlines
/// overlap, the smaller figure wins (a bird in front of the rocks, not the rocks).
public enum FigureHitTest {
    public static func figure(at p: Point<ArtworkSpace>, in library: AnnotationLibrary) -> String? {
        library.annotations
            .compactMap { a -> (String, Double)? in
                guard let o = a.outline, o.count >= 3, contains(o, p) else { return nil }
                return (a.id, area(o))
            }
            .min { $0.1 < $1.1 }?.0
    }

    static func contains(_ poly: [Point<ArtworkSpace>], _ p: Point<ArtworkSpace>) -> Bool {
        var inside = false
        var j = poly.count - 1
        for i in poly.indices {
            let a = poly[i], b = poly[j]
            if (a.y > p.y) != (b.y > p.y), p.x < (b.x - a.x) * (p.y - a.y) / (b.y - a.y) + a.x { inside.toggle() }
            j = i
        }
        return inside
    }

    static func area(_ poly: [Point<ArtworkSpace>]) -> Double {
        var s = 0.0
        for i in poly.indices {
            let a = poly[i], b = poly[(i + 1) % poly.count]
            s += a.x * b.y - b.x * a.y
        }
        return abs(s) / 2
    }
}
