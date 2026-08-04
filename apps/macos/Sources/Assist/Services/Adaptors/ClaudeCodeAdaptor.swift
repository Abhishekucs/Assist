import Foundation

final class ClaudeCodeAdaptor: CodingAgentAdaptor {
    let provider: CodingAgentProvider = .claudeCode
    var settingsKey: String { "agents.claude-code.enabled" }
    var configDirectorySettingKey: String? { "agents.claude.configDirectory" }

    private let hookInstaller: ClaudeCodeHookInstaller
    private var configDirectory: String

    init(configDirectory: String = "") {
        self.configDirectory = configDirectory
        self.hookInstaller = ClaudeCodeHookInstaller(
            claudeHome: CodingAgentConfiguration.claudeHome(
                configuredDirectory: configDirectory
            )
        )
    }

    func updateConfigDirectory(_ directory: String) {
        configDirectory = directory
    }

    var isInstalled: Bool {
        hookInstaller.isInstalled()
    }

    func containsAssistHandlers() -> Bool {
        hookInstaller.containsAssistHandlers()
    }

    var settingsURL: URL {
        hookInstaller.settingsURL
    }

    func enable(executableURL: URL?) throws {
        try hookInstaller.install(executableURL: executableURL)
    }

    func disable() throws {
        try hookInstaller.uninstall()
    }

    func loadUsageSnapshot() -> UsageLimitSnapshot {
        let claudeHome = CodingAgentConfiguration.claudeHome(
            configuredDirectory: configDirectory
        )
        return LocalRateLimitReader.loadSnapshot(
            provider: provider,
            source: .claudeStatusLine,
            roots: [
                claudeHome.appendingPathComponent("projects", isDirectory: true),
                claudeHome.appendingPathComponent("sessions", isDirectory: true),
                claudeHome.appendingPathComponent("tasks", isDirectory: true)
            ],
            maxFiles: 80
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
        toolName == "AskUserQuestion"
    }

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
        let questionInput = questions.map { question -> [String: Any] in
            [
                "question": question.prompt,
                "header": question.header,
                "options": question.options.map { option in
                    [
                        "label": option.label,
                        "description": option.description
                    ]
                },
                "multiSelect": question.allowsMultipleSelection
            ]
        }
        var answerInput: [String: String] = [:]
        answers.forEach { answer in
            answerInput[answer.responseKey] = answer.selectedAnswers.joined(separator: ", ")
        }
        return [
            "hookSpecificOutput": [
                "hookEventName": "PreToolUse",
                "permissionDecision": "allow",
                "updatedInput": [
                    "questions": questionInput,
                    "answers": answerInput
                ]
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
}
