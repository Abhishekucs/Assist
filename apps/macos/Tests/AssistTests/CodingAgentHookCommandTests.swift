import XCTest
@testable import Assist

final class CodingAgentHookCommandTests: XCTestCase {
    func testGenericAgentHookFlagParsesProviderID() {
        let args = ["/path/to/assist", "--agent-hook=claude-code", "--assist-hook-owner=com.test"]
        XCTAssertEqual(CodingAgentHookCommand.providerID(in: args), "claude-code")
    }

    func testAgentHookFlagForCodex() {
        let args = ["/path/to/assist", "--agent-hook=codex"]
        XCTAssertEqual(CodingAgentHookCommand.providerID(in: args), "codex")
    }

    func testAgentHookFlagForNewProvider() {
        let args = ["/path/to/assist", "--agent-hook=opencode"]
        XCTAssertEqual(CodingAgentHookCommand.providerID(in: args), "opencode")
    }

    func testLegacyClaudeCodeFlagStillWorks() {
        let args = ["/path/to/assist", "--claude-code-hook"]
        XCTAssertEqual(CodingAgentHookCommand.providerID(in: args), "claude-code")
    }

    func testLegacyCodexFlagStillWorks() {
        let args = ["/path/to/assist", "--codex-hook"]
        XCTAssertEqual(CodingAgentHookCommand.providerID(in: args), "codex")
    }

    func testNoHookFlagReturnsNil() {
        let args = ["/path/to/assist"]
        XCTAssertNil(CodingAgentHookCommand.providerID(in: args))
    }

    func testEmptyAgentHookReturnsNil() {
        let args = ["/path/to/assist", "--agent-hook="]
        XCTAssertNil(CodingAgentHookCommand.providerID(in: args))
    }

    func testGenericFlagTakesPrecedenceOverLegacy() {
        let args = ["/path/to/assist", "--agent-hook=opencode", "--codex-hook"]
        XCTAssertEqual(CodingAgentHookCommand.providerID(in: args), "opencode")
    }
}
