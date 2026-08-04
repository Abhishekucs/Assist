import Foundation

final class CodexAdaptor: CodingAgentAdaptor {
    let provider: CodingAgentProvider = .codex
    var settingsKey: String { "agents.codex.enabled" }

    private let hookInstaller: CodexHookInstaller

    init() {
        self.hookInstaller = CodexHookInstaller()
    }

    var isInstalled: Bool {
        hookInstaller.isInstalled()
    }

    func containsAssistHandlers() -> Bool {
        hookInstaller.containsAssistHandlers()
    }

    var hooksURL: URL {
        hookInstaller.hooksURL
    }

    func enable(executableURL: URL?) throws {
        try hookInstaller.install(executableURL: executableURL)
    }

    func disable() throws {
        try hookInstaller.uninstall()
    }

    func loadUsageSnapshot() -> UsageLimitSnapshot {
        let codexHome = Self.codexHome()
        return LocalRateLimitReader.loadSnapshot(
            provider: provider,
            source: .codexSessionLog,
            roots: [
                codexHome.appendingPathComponent("sessions", isDirectory: true),
                codexHome.appendingPathComponent("archived_sessions", isDirectory: true)
            ],
            maxFiles: 120
        )
    }

    func resolveApproval(_ id: UUID, decision: CodingAgentApprovalDecision) {
        CodingAgentHookResponseChannel.shared.resolveApproval(id, decision: decision)
    }

    func answerQuestion(_ id: UUID, answers: [CodingAgentQuestionAnswer]) {
        CodingAgentHookResponseChannel.shared.answerQuestion(id, answers: answers)
    }

    func declineApproval(_ id: UUID) {
        CodingAgentHookResponseChannel.shared.declineApproval(id)
    }

    func declineQuestion(_ id: UUID) {
        CodingAgentHookResponseChannel.shared.declineQuestion(id)
    }

    func declineAll() {
        CodingAgentHookResponseChannel.shared.declineAll(forAdaptor: self)
    }

    func isQuestionToolName(_ toolName: String?) -> Bool {
        toolName == "request_user_input"
    }

    func requiresEmptyJSONResponse(for eventName: String) -> Bool {
        eventName == "Stop"
    }

    var autoResolutionMilliseconds: Double? { nil }

    func parseHookEvent(_ payload: [String: Any], version: String?) -> CodingAgentEvent? {
        HookEventParser.parse(payload: payload, provider: provider, version: version)
    }

    func buildApprovalResponse(decision: CodingAgentApprovalDecision) -> [String: Any] {
        let decisionObject: [String: Any]
        switch decision {
        case .allow:
            decisionObject = ["behavior": "allow"]
        case .deny:
            decisionObject = [
                "behavior": "deny",
                "message": "Denied from the Assist island."
            ]
        }

        return [
            "hookSpecificOutput": [
                "hookEventName": "PermissionRequest",
                "decision": decisionObject
            ]
        ]
    }

    func buildQuestionResponse(questions: [CodingAgentQuestion], answers: [CodingAgentQuestionAnswer]) -> [String: Any] {
        var questionByID: [String: CodingAgentQuestion] = [:]
        questions.forEach { question in
            questionByID[question.id] = question
        }
        let answerSummary = answers.map { answer in
            let question = questionByID[answer.questionID]
            let label = question?.header ?? question?.prompt ?? answer.questionID
            return "- \(label): \(answer.selectedAnswers.joined(separator: ", "))"
        }
        .joined(separator: "\n")
        return [
            "hookSpecificOutput": [
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": """
                The user answered this request through Assist:
                \(answerSummary)
                Treat these as the user's answers and continue without asking again.
                """
            ]
        ]
    }

    func buildAutoResolutionTimeoutResponse() -> [String: Any] {
        [
            "hookSpecificOutput": [
                "hookEventName": "PreToolUse",
                "permissionDecision": "deny",
                "permissionDecisionReason": """
                The user did not answer in Assist before this request's auto-resolution deadline.
                Continue with your best judgment without asking again.
                """
            ]
        ]
    }

    private static func codexHome() -> URL {
        if let path = ProcessInfo.processInfo.environment["CODEX_HOME"],
           !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(
                fileURLWithPath: (path as NSString).expandingTildeInPath,
                isDirectory: true
            )
        }

        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".codex", isDirectory: true)
    }
}
