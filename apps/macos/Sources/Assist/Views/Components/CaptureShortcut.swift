/// A modifier key in a capture shortcut, with each spelling the app shows.
enum ShortcutKey: String, Sendable {
    case control
    case option

    var name: String {
        switch self {
        case .control: "Control"
        case .option: "Option"
        }
    }

    var abbreviation: String {
        switch self {
        case .control: "Ctrl"
        case .option: "Opt"
        }
    }

    var symbol: String {
        switch self {
        case .control: "⌃"
        case .option: "⌥"
        }
    }
}

/// A capture shortcut, defined once for every place that describes it: the
/// library header, Capture settings, and the island's hints.
struct CaptureShortcut: Identifiable, Sendable {
    let id: String
    let icon: HugeIconKind
    let title: String
    let detail: String
    let keys: [ShortcutKey]
    /// What the shortcut does, after its keys in compact hints.
    let hintAction: String

    var keyNames: [String] { keys.map(\.name) }

    static let annotate = CaptureShortcut(
        id: "annotate",
        icon: .pen,
        title: "Annotate a screenshot",
        detail: "Hold Option and draw, then release to save.",
        keys: [.option],
        hintAction: "to annotate"
    )

    static let cleanCapture = CaptureShortcut(
        id: "clean-capture",
        icon: .camera,
        title: "Take a clean screenshot",
        detail: "Capture the active display without annotation.",
        keys: [.control, .option],
        hintAction: "for a clean screenshot"
    )

    static let all = [annotate, cleanCapture]

    /// The collapsed island's resting status, e.g. "Hold Opt / Ctrl+Opt".
    static var idleStatus: String {
        "Hold " + all.map { $0.keys.map(\.abbreviation).joined(separator: "+") }.joined(separator: " / ")
    }

    /// The island's empty-history hint, e.g. "Hold ⌥ to annotate  ·  ⌃⌥ for …".
    static var emptyHistoryHint: String {
        "Hold " + all.map { $0.keys.map(\.symbol).joined() + " " + $0.hintAction }.joined(separator: "  ·  ")
    }
}
