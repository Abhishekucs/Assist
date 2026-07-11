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
    private var lastDeliveredText: String?
    private var lastDeliveredAt: Date?
    private var shouldIgnoreNextTextChange = false

    func start() {
        lastChangeCount = pasteboard.changeCount
        lastSeenText = normalizedText(from: pasteboard)
        lastDeliveredText = nil
        lastDeliveredAt = nil

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

        guard let text = normalizedText(from: pasteboard) else {
            shouldIgnoreNextTextChange = false
            return
        }

        if shouldIgnoreNextTextChange {
            shouldIgnoreNextTextChange = false
            lastSeenText = text
            return
        }

        guard text != lastSeenText else { return }

        if shouldIgnoreIncidentalText(text) {
            DebugLogger.log("clipboard.text.ignored", [
                "characters": "\(text.count)",
                "reason": "incidentalMetadata"
            ])
            lastSeenText = text
            return
        }

        lastSeenText = text
        lastDeliveredText = text
        lastDeliveredAt = Date()
        delegate?.clipboardTextMonitor(self, didCopy: text)
    }

    private func normalizedText(from pasteboard: NSPasteboard) -> String? {
        guard let text = pasteboard.string(forType: .string) else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        return String(trimmed.prefix(50_000))
    }

    private func shouldIgnoreIncidentalText(_ text: String) -> Bool {
        guard text.count <= 32,
              text.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              let lastDeliveredAt,
              Date().timeIntervalSince(lastDeliveredAt) < 3,
              (lastDeliveredText?.count ?? 0) >= 40 else {
            return false
        }

        if isIPv4Address(text) {
            return true
        }

        let scalars = text.unicodeScalars
        let digitCount = scalars.filter { CharacterSet.decimalDigits.contains($0) }.count
        let machineTokenCharacters = CharacterSet(charactersIn: ".:-_")
        let punctuationCount = scalars.filter { machineTokenCharacters.contains($0) }.count

        return digitCount + punctuationCount == scalars.count
            && digitCount >= max(4, scalars.count / 2)
    }

    private func isIPv4Address(_ text: String) -> Bool {
        let parts = text.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count == 4 else { return false }

        return parts.allSatisfy { part in
            guard !part.isEmpty,
                  part.allSatisfy(\.isNumber),
                  let value = Int(part) else {
                return false
            }

            return (0...255).contains(value)
        }
    }
}
