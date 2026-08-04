import Foundation

protocol CodingAgentAdaptor: AnyObject {
    var provider: CodingAgentProvider { get }
    var isInstalled: Bool { get }
    var settingsKey: String { get }
    var configDirectorySettingKey: String? { get }

    func enable(executableURL: URL?) throws
    func disable() throws
    func containsAssistHandlers() -> Bool
    func loadUsageSnapshot() -> UsageLimitSnapshot

    func resolveApproval(_ id: UUID, decision: CodingAgentApprovalDecision)
    func answerQuestion(_ id: UUID, answers: [CodingAgentQuestionAnswer])
    func declineApproval(_ id: UUID)
    func declineQuestion(_ id: UUID)
    func declineAll()

    func parseHookEvent(_ payload: [String: Any], version: String?) -> CodingAgentEvent?
    func buildApprovalResponse(decision: CodingAgentApprovalDecision) -> [String: Any]
    func buildQuestionResponse(questions: [CodingAgentQuestion], answers: [CodingAgentQuestionAnswer]) -> [String: Any]
    func buildAutoResolutionTimeoutResponse() -> [String: Any]
    func requiresEmptyJSONResponse(for eventName: String) -> Bool
    func isQuestionToolName(_ toolName: String?) -> Bool
    var autoResolutionMilliseconds: Double? { get }
}

extension CodingAgentAdaptor {
    var configDirectorySettingKey: String? { nil }
    var autoResolutionMilliseconds: Double? { nil }

    func requiresEmptyJSONResponse(for eventName: String) -> Bool { false }
    func buildAutoResolutionTimeoutResponse() -> [String: Any] { [:] }
}
