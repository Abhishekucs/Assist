/// A capture shortcut as the library header and Capture settings show it.
struct CaptureShortcut: Identifiable {
    let id: String
    let icon: HugeIconKind
    let title: String
    let detail: String
    let keys: [String]

    static let annotate = CaptureShortcut(
        id: "annotate",
        icon: .pen,
        title: "Annotate a screenshot",
        detail: "Hold Option and draw, then release to save.",
        keys: ["Option"]
    )

    static let cleanCapture = CaptureShortcut(
        id: "clean-capture",
        icon: .camera,
        title: "Take a clean screenshot",
        detail: "Capture the active display without annotation.",
        keys: ["Control", "Option"]
    )

    static let all = [annotate, cleanCapture]
}
