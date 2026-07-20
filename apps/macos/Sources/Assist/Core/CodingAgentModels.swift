import Foundation

enum CodingAgentActivity: String, Sendable {
    case idle
    case working
    case waitingForApproval
    case waitingForInput
    case completed

    var displayName: String {
        switch self {
        case .idle:
            "Ready"
        case .working:
            "Working"
        case .waitingForApproval:
            "Needs approval"
        case .waitingForInput:
            "Needs answer"
        case .completed:
            "Completed"
        }
    }

    var taskSortPriority: Int {
        switch self {
        case .waitingForApproval, .waitingForInput:
            0
        case .working:
            1
        case .completed:
            2
        case .idle:
            3
        }
    }
}

struct CodingAgentSession: Identifiable, Equatable, Sendable {
    let provider: UsageLimitProvider
    let sessionID: String
    var cwd: String
    var model: String?
    var version: String?
    var turnID: String?
    var taskSummary: String?
    var questionPrompt: String?
    var activity: CodingAgentActivity
    var updatedAt: Date

    var id: String {
        "\(provider.rawValue):\(sessionID)"
    }

    var projectName: String {
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        return name.isEmpty ? "\(provider.displayName) task" : name
    }
}

enum CodingAgentApprovalDecision: Sendable {
    case allow
    case deny
}

enum CodingAgentApprovalInvalidationReason: Sendable {
    case disconnected
    case timedOut
}

struct CodingAgentApprovalRequest: Identifiable, Equatable, Sendable {
    let id: UUID
    let provider: UsageLimitProvider
    let sessionID: String
    let turnID: String?
    let cwd: String
    let model: String?
    let toolName: String
    let commandPreview: String
    let reason: String?
    let receivedAt: Date

    var sessionKey: String {
        "\(provider.rawValue):\(sessionID)"
    }

    var projectName: String {
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        return name.isEmpty ? "\(provider.displayName) task" : name
    }

    var toolDisplayName: String {
        switch toolName {
        case "Bash":
            "Run command"
        case "apply_patch":
            "Edit files"
        default:
            toolName
        }
    }
}

struct CodingAgentHookEvent: Sendable {
    let provider: UsageLimitProvider
    let name: String
    let sessionID: String
    let turnID: String?
    let source: String?
    let cwd: String
    let model: String?
    let version: String?
    let taskSummary: String?
    let questionPrompt: String?
    let notificationType: String?
    let toolName: String?
    let commandPreview: String?
    let reason: String?
    let approvalID: UUID?

    var isPermissionRequest: Bool {
        name == "PermissionRequest"
    }

    var sessionKey: String {
        "\(provider.rawValue):\(sessionID)"
    }

    var startsQuestion: Bool {
        if name == "PreToolUse" {
            return provider.isQuestionTool(toolName)
        }
        guard name == "Notification" else { return false }
        return ["elicitation_dialog", "agent_needs_input"].contains(notificationType)
    }

    var finishesQuestion: Bool {
        if name == "PostToolUse" || name == "PostToolUseFailure" {
            return provider.isQuestionTool(toolName)
        }
        guard name == "Notification" else { return false }
        return ["elicitation_complete", "elicitation_response", "agent_completed"].contains(notificationType)
    }
}

private extension UsageLimitProvider {
    func isQuestionTool(_ toolName: String?) -> Bool {
        switch self {
        case .claudeCode:
            toolName == "AskUserQuestion"
        case .codex:
            toolName == "request_user_input"
        }
    }
}
