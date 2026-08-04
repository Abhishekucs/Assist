import XCTest
@testable import Assist

final class CodingAgentAdaptorRegistryTests: XCTestCase {
    @MainActor
    func testRegisterAndLookupAdaptor() {
        let registry = CodingAgentAdaptorRegistry()
        let adaptor = ClaudeCodeAdaptor(configDirectory: "")

        registry.register(adaptor)

        XCTAssertEqual(registry.adaptors.count, 1)
        XCTAssertEqual(registry.adaptor(for: .claudeCode)?.provider, .claudeCode)
        XCTAssertEqual(registry.adaptor(forProviderID: "claude-code")?.provider, .claudeCode)
    }

    @MainActor
    func testRegisterDuplicateProviderIsIgnored() {
        let registry = CodingAgentAdaptorRegistry()

        registry.register(ClaudeCodeAdaptor(configDirectory: ""))
        registry.register(ClaudeCodeAdaptor(configDirectory: ""))

        XCTAssertEqual(registry.adaptors.count, 1)
    }

    @MainActor
    func testUnregisterRemovesAdaptor() {
        let registry = CodingAgentAdaptorRegistry()
        registry.register(ClaudeCodeAdaptor(configDirectory: ""))
        registry.register(CodexAdaptor())

        registry.unregister(provider: .claudeCode)

        XCTAssertEqual(registry.adaptors.count, 1)
        XCTAssertNil(registry.adaptor(for: .claudeCode))
        XCTAssertNotNil(registry.adaptor(for: .codex))
    }

    @MainActor
    func testAllProvidersReturnsRegisteredProviders() {
        let registry = CodingAgentAdaptorRegistry()
        registry.register(ClaudeCodeAdaptor(configDirectory: ""))
        registry.register(CodexAdaptor())

        let providers = registry.allProviders
        XCTAssertEqual(providers.count, 2)
        XCTAssertTrue(providers.contains(.claudeCode))
        XCTAssertTrue(providers.contains(.codex))
    }
}
