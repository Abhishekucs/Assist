import AppKit

/// The notes module's single scratchpad, saved as Markdown on every edit so
/// nothing typed is lost if Assist quits.
@MainActor
final class ScratchpadStore: ObservableObject {
    @Published var text: String {
        didSet {
            guard text != oldValue else { return }
            persist()
        }
    }

    private let fileURL: URL
    private var canPersist = true

    init(directory: URL) {
        fileURL = directory.appendingPathComponent("scratchpad.md", isDirectory: false)
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                text = try String(contentsOf: fileURL, encoding: .utf8)
            } catch {
                // Keep an unreadable file untouched rather than replacing it.
                text = ""
                canPersist = false
                DebugLogger.log("modules.notes.load.error", ["description": error.localizedDescription])
            }
        } else {
            text = ""
        }
    }

    var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var wordCount: Int {
        text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).count
    }

    @discardableResult
    func copyToPasteboard() -> Bool {
        guard !isEmpty else { return false }
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.setString(text, forType: .string)
    }

    func clear() {
        text = ""
    }

    private func persist() {
        guard canPersist else { return }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try text.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            DebugLogger.log("modules.notes.save.error", ["description": error.localizedDescription])
        }
    }
}
