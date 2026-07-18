import Foundation

enum CodexAgentActivity: String, Sendable {
    case idle
    case working
    case waitingForApproval
    case completed

    var displayName: String {
        switch self {
        case .idle:
            "Ready"
        case .working:
            "Working"
        case .waitingForApproval:
            "Needs approval"
        case .completed:
            "Completed"
        }
    }

    var taskSortPriority: Int {
        switch self {
        case .waitingForApproval:
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

struct CodexAgentSession: Identifiable, Equatable, Sendable {
    let id: String
    var cwd: String
    var model: String?
    var turnID: String?
    var taskSummary: String?
    var activity: CodexAgentActivity
    var updatedAt: Date

    var projectName: String {
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        return name.isEmpty ? "Codex task" : name
    }
}

enum CodexApprovalDecision: Sendable {
    case allow
    case deny
}

struct CodexApprovalRequest: Identifiable, Equatable, Sendable {
    let id: UUID
    let sessionID: String
    let turnID: String?
    let cwd: String
    let model: String?
    let toolName: String
    let commandPreview: String
    let reason: String?
    let receivedAt: Date

    var projectName: String {
        let name = URL(fileURLWithPath: cwd).lastPathComponent
        return name.isEmpty ? "Codex task" : name
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

struct CodexHookEvent: Sendable {
    let name: String
    let sessionID: String
    let turnID: String?
    let cwd: String
    let model: String?
    let taskSummary: String?
    let toolName: String?
    let commandPreview: String?
    let reason: String?
    let approvalID: UUID?

    var isPermissionRequest: Bool {
        name == "PermissionRequest"
    }
}
