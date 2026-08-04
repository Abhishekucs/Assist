import Foundation

struct CodingAgentProvider: Hashable, Sendable, Identifiable, Codable {
    let id: String
    let displayName: String
    let compactName: String
    let accentColorHex: String
    let logoResourceName: String?

    var id: String { id }

    static let claudeCode = CodingAgentProvider(
        id: "claude-code",
        displayName: "Claude",
        compactName: "Claude",
        accentColorHex: "#F58337",
        logoResourceName: "claude-code-logo"
    )

    static let codex = CodingAgentProvider(
        id: "codex",
        displayName: "Codex",
        compactName: "Codex",
        accentColorHex: "#7A9DFF",
        logoResourceName: "codex-logo"
    )

    static let opencode = CodingAgentProvider(
        id: "opencode",
        displayName: "opencode",
        compactName: "opencode",
        accentColorHex: "#7A9DFF",
        logoResourceName: nil
    )

    static let allBuiltIn: [CodingAgentProvider] = [.claudeCode, .codex]
}
