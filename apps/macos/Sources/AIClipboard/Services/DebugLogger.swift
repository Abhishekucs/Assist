import AppKit

@MainActor
enum DebugLogger {
    static var logURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base
            .appendingPathComponent(AppIdentity.supportDirectoryName, isDirectory: true)
            .appendingPathComponent("debug.log")
    }

    static func log(_ event: String, _ fields: [String: String] = [:]) {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var line = "[\(formatter.string(from: Date()))] \(event)"
        if !fields.isEmpty {
            let renderedFields = fields
                .sorted { $0.key < $1.key }
                .map { "\($0.key)=\($0.value)" }
                .joined(separator: " ")
            line += " \(renderedFields)"
        }
        line += "\n"

        do {
            let directory = logURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

            guard let data = line.data(using: .utf8) else { return }
            if FileManager.default.fileExists(atPath: logURL.path) {
                let handle = try FileHandle(forWritingTo: logURL)
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
                try handle.close()
            } else {
                try data.write(to: logURL, options: .atomic)
            }
        } catch {
            NSLog("\(AppIdentity.name) debug log failed: \(error.localizedDescription)")
        }
    }

    static func openLog() {
        NSWorkspace.shared.open(logURL)
    }

    static func describe(_ rect: CGRect) -> String {
        "x:\(Int(rect.origin.x)),y:\(Int(rect.origin.y)),w:\(Int(rect.width)),h:\(Int(rect.height))"
    }

    static func describe(_ point: CGPoint) -> String {
        "x:\(Int(point.x)),y:\(Int(point.y))"
    }
}
