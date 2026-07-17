import Foundation
import Testing
@testable import Assist

struct CodexTaskServiceTests {
    @Test
    func returnsOnlyActiveTopLevelTasks() throws {
        let codexHome = try makeCodexHome()
        defer { try? FileManager.default.removeItem(at: codexHome) }

        try writeSession(
            in: codexHome,
            id: "active-thread",
            cwd: "/Users/example/Assist",
            messages: ["Add the Codex task view"],
            events: ["task_started"],
            modifiedAt: Date(timeIntervalSince1970: 300)
        )
        try writeSession(
            in: codexHome,
            id: "completed-thread",
            cwd: "/Users/example/Done",
            messages: ["Already finished"],
            events: ["task_started", "task_complete"],
            modifiedAt: Date(timeIntervalSince1970: 400)
        )
        try writeSession(
            in: codexHome,
            id: "subagent-thread",
            cwd: "/Users/example/Assist",
            messages: ["Explore the code"],
            events: ["task_started"],
            modifiedAt: Date(timeIntervalSince1970: 500),
            source: ["subagent": "explore"]
        )

        let tasks = CodexTaskService.loadActiveTasks(codexHome: codexHome)

        #expect(tasks == [
            CodexTask(
                id: "active-thread",
                title: "Add the Codex task view",
                workspaceName: "Assist",
                updatedAt: Date(timeIntervalSince1970: 300)
            )
        ])
    }

    @Test
    func limitsTasksAndExtractsUserQueryTitle() throws {
        let codexHome = try makeCodexHome()
        defer { try? FileManager.default.removeItem(at: codexHome) }

        for index in 0..<4 {
            try writeSession(
                in: codexHome,
                id: "thread-\(index)",
                cwd: "/Users/example/Project\(index)",
                messages: [
                    "An older request",
                    """
                    <system_reminder>context</system_reminder>
                    <user_query>
                    Implement task \(index)
                    </user_query>
                    """
                ],
                events: ["task_started"],
                modifiedAt: Date(timeIntervalSince1970: TimeInterval(100 + index))
            )
        }

        let tasks = CodexTaskService.loadActiveTasks(codexHome: codexHome, limit: 3)

        #expect(tasks.map(\.id) == ["thread-3", "thread-2", "thread-1"])
        #expect(tasks.map(\.title) == ["Implement task 3", "Implement task 2", "Implement task 1"])
    }

    private func makeCodexHome() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("AssistCodexTaskTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("sessions", isDirectory: true),
            withIntermediateDirectories: true
        )
        return root
    }

    private func writeSession(
        in codexHome: URL,
        id: String,
        cwd: String,
        messages: [String],
        events: [String],
        modifiedAt: Date,
        source: Any = "cli"
    ) throws {
        let sessionsDirectory = codexHome
            .appendingPathComponent("sessions", isDirectory: true)
            .appendingPathComponent("2026/07/17", isDirectory: true)
        try FileManager.default.createDirectory(
            at: sessionsDirectory,
            withIntermediateDirectories: true
        )
        let url = sessionsDirectory
            .appendingPathComponent("\(id).jsonl")

        var lines: [[String: Any]] = [
            [
                "type": "session_meta",
                "payload": [
                    "id": id,
                    "cwd": cwd,
                    "source": source
                ]
            ]
        ]

        for (index, message) in messages.enumerated() {
            lines.append([
                "type": "event_msg",
                "payload": [
                    "type": "user_message",
                    "message": message
                ]
            ])
            if index < messages.count - 1 {
                lines.append([
                    "type": "event_msg",
                    "payload": [
                        "type": "task_started",
                        "turn_id": UUID().uuidString
                    ]
                ])
                lines.append([
                    "type": "event_msg",
                    "payload": [
                        "type": "task_complete",
                        "turn_id": UUID().uuidString
                    ]
                ])
            }
        }

        lines.append(contentsOf: events.map { event in
            [
                "type": "event_msg",
                "payload": [
                    "type": event,
                    "turn_id": UUID().uuidString
                ]
            ]
        })

        let data = try lines
            .map { try JSONSerialization.data(withJSONObject: $0) }
            .reduce(into: Data()) { result, line in
                result.append(line)
                result.append(Data([0x0A]))
            }

        try data.write(to: url)
        try FileManager.default.setAttributes(
            [.modificationDate: modifiedAt],
            ofItemAtPath: url.path
        )
    }
}
