import AppKit

@MainActor
protocol ClipboardTextMonitorDelegate: AnyObject {
    func clipboardTextMonitor(_ monitor: ClipboardTextMonitor, didCopy text: String)
}

@MainActor
final class ClipboardTextMonitor {
    weak var delegate: ClipboardTextMonitorDelegate?

    private let pasteboard = NSPasteboard.general
    private var timer: Timer?
    private var lastChangeCount = NSPasteboard.general.changeCount
    private var lastSeenText: String?
    private var shouldIgnoreNextTextChange = false

    func start() {
        lastChangeCount = pasteboard.changeCount
        lastSeenText = normalizedText(from: pasteboard)

        timer?.invalidate()
        let timer = Timer(timeInterval: 0.45, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollPasteboard()
            }
        }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func ignoreNextPasteboardWrite() {
        shouldIgnoreNextTextChange = true
    }

    private func pollPasteboard() {
        let changeCount = pasteboard.changeCount
        guard changeCount != lastChangeCount else { return }
        lastChangeCount = changeCount

        guard let text = normalizedText(from: pasteboard) else { return }

        if shouldIgnoreNextTextChange {
            shouldIgnoreNextTextChange = false
            lastSeenText = text
            return
        }

        guard text != lastSeenText else { return }
        lastSeenText = text
        delegate?.clipboardTextMonitor(self, didCopy: text)
    }

    private func normalizedText(from pasteboard: NSPasteboard) -> String? {
        guard let text = pasteboard.string(forType: .string) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        return String(trimmed.prefix(50_000))
    }
}
