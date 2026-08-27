import Darwin
import Foundation
import XCTest
@testable import Assist

final class RetiredAgentHooksCleanupTests: XCTestCase {
    private var root: URL!
    private var defaults: UserDefaults!
    private var suite: String!
    private let owner = "--assist-hook-owner=com.thinkingsoundlab.assist"

    override func setUpWithError() throws {
        // Unix socket paths must be short enough for sockaddr_un.sun_path.
        root = URL(fileURLWithPath: "/tmp/assist-retirement-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        suite = "AssistRetirementTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
    }

    override func tearDownWithError() throws {
        defaults.removePersistentDomain(forName: suite)
        try FileManager.default.removeItem(at: root)
    }

    func testRemovesOwnedHandlersFromBothProvidersAndKeepsUnrelatedFields() throws {
        let unrelated = handler("/usr/local/bin/my-notification")
        let unknownOwner = handler("'/Applications/Assist.app/Contents/MacOS/Assist' --codex-hook --assist-hook-owner=someone.else")
        for (file, flag) in [(".codex/hooks.json", "--codex-hook"), (".claude/settings.json", "--claude-code-hook")] {
            try write([
                "model": "keep-model", "permissions": ["deny": ["Bash(rm *)"]],
                "hooks": [
                    "UserPromptSubmit": [["matcher": "*", "other": true, "hooks": [
                        handler("'/moved app/Assist' \(flag) \(owner)"), unrelated, unknownOwner
                    ]]],
                    "UnknownEvent": [["hooks": [handler("'/moved app/Assist' \(flag) \(owner).dev")]]]
                ]
            ], to: file)
        }
        let result = cleanup().run()
        XCTAssertTrue(result.failures.isEmpty, result.failures.description)
        XCTAssertEqual(result.removedHandlers, 4)
        for file in [".codex/hooks.json", ".claude/settings.json"] {
            let value = try read(file)
            XCTAssertEqual(value["model"] as? String, "keep-model")
            XCTAssertEqual(value["permissions"] as? [String: [String]], ["deny": ["Bash(rm *)"]])
            let hooks = try XCTUnwrap(value["hooks"] as? [String: [[String: Any]]])
            let group = try XCTUnwrap(hooks["UserPromptSubmit"]?.first)
            XCTAssertEqual(group["matcher"] as? String, "*")
            XCTAssertEqual(group["other"] as? Bool, true)
            let remaining = try XCTUnwrap(group["hooks"] as? [[String: String]])
            XCTAssertEqual(remaining, [unrelated, unknownOwner])
            XCTAssertEqual(hooks["UnknownEvent"]?.count, 0)
        }
    }

    func testFreshInstallCreatesNoProviderFilesAndPreservesCapturePreferences() {
        defaults.set(true, forKey: "capture.voiceContextEnabled")
        defaults.set(550, forKey: "pill.expandedWidth")
        defaults.set("dark", forKey: "app.appearance")
        defaults.set(true, forKey: "agents.coding.enabled")
        defaults.set(true, forKey: "agents.codex.enabled")
        defaults.set(true, forKey: "rateLimits.showClaudeCode")
        defaults.set(true, forKey: "rateLimits.showCodex")
        let result = cleanup().run()
        XCTAssertTrue(result.failures.isEmpty)
        XCTAssertEqual(result.removedHandlers, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(".codex").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent(".claude").path))
        XCTAssertTrue(defaults.bool(forKey: "capture.voiceContextEnabled"))
        XCTAssertEqual(defaults.integer(forKey: "pill.expandedWidth"), 550)
        XCTAssertEqual(defaults.string(forKey: "app.appearance"), "dark")
        RetiredAgentHooksCleanup.obsoletePreferenceKeys.forEach { XCTAssertNil(defaults.object(forKey: $0)) }
    }

    func testCustomDirectoriesAreRetiredEvenAfterDefaultLocationsCompleted() throws {
        XCTAssertTrue(cleanup().run().failures.isEmpty)
        defaults.set("~/custom claude", forKey: "agents.claude.configDirectory")
        for file in ["custom claude/settings.json", "env claude/settings.json", "env codex/hooks.json"] {
            try write(configuration(), to: file)
        }
        let result = cleanup(environment: ["CODEX_HOME": "env codex", "CLAUDE_CONFIG_DIR": root.appendingPathComponent("env claude").path]).run()
        XCTAssertTrue(result.failures.isEmpty, result.failures.description)
        XCTAssertEqual(result.removedHandlers, 3)
        XCTAssertNil(defaults.object(forKey: "agents.claude.configDirectory"))
    }

    func testSymlinkAndPermissionsSurviveAndSecondRunDoesNotRewrite() throws {
        try write(configuration(), to: "actual-settings.json")
        let target = root.appendingPathComponent("actual-settings.json")
        try FileManager.default.setAttributes([.posixPermissions: 0o640], ofItemAtPath: target.path)
        let parent = root.appendingPathComponent(".claude")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let link = parent.appendingPathComponent("settings.json")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "../actual-settings.json")
        let first = cleanup().run()
        XCTAssertTrue(first.failures.isEmpty, first.failures.description)
        XCTAssertEqual(first.removedHandlers, 1)
        XCTAssertEqual(try FileManager.default.destinationOfSymbolicLink(atPath: link.path), "../actual-settings.json")
        let attributes = try FileManager.default.attributesOfItem(atPath: target.path)
        XCTAssertEqual((attributes[.posixPermissions] as? NSNumber)?.intValue, 0o640)
        let data = try Data(contentsOf: target)
        let second = cleanup().run()
        XCTAssertEqual(second.removedHandlers, 0)
        XCTAssertEqual(try Data(contentsOf: target), data)
        XCTAssertEqual(try FileManager.default.attributesOfItem(atPath: target.path)[.modificationDate] as? Date,
                       attributes[.modificationDate] as? Date)
    }

    func testRelativeCodexDirectoryUsesOriginalInstallerWorkingDirectory() throws {
        try write(configuration(), to: "launch/relative codex/hooks.json")
        try write(configuration(), to: "relative codex/hooks.json")
        let untouched = root.appendingPathComponent("relative codex/hooks.json")
        let before = try Data(contentsOf: untouched)
        let migration = RetiredAgentHooksCleanup(
            defaults: defaults, homeDirectory: root,
            workingDirectory: root.appendingPathComponent("launch"), supportDirectory: root,
            environment: ["CODEX_HOME": "relative codex"], executableURL: nil
        )
        let result = migration.run()
        XCTAssertTrue(result.failures.isEmpty, result.failures.description)
        XCTAssertEqual(result.removedHandlers, 1)
        XCTAssertEqual(try Data(contentsOf: untouched), before)
    }

    func testInvalidJSONAndUnreadableFileArePreservedUntilRetrySucceeds() throws {
        try write(configuration(), to: ".claude/settings.json")
        let file = root.appendingPathComponent(".claude/settings.json")
        let invalid = Data("{\"hooks\":".utf8)
        try invalid.write(to: file)
        XCTAssertFalse(cleanup().run().failures.isEmpty)
        XCTAssertEqual(try Data(contentsOf: file), invalid)

        try write(configuration(), to: ".claude/settings.json")
        try FileManager.default.setAttributes([.posixPermissions: 0], ofItemAtPath: file.path)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path) }
        XCTAssertFalse(cleanup().run().failures.isEmpty)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        let retry = cleanup().run()
        XCTAssertTrue(retry.failures.isEmpty, retry.failures.description)
        XCTAssertEqual(retry.removedHandlers, 1)
    }

    func testMalformedConfigurationIsUnchangedAndCanBeRetried() throws {
        let invalidFiles: [Any] = [
            ["not", "an", "object"], ["hooks": []],
            ["hooks": ["Stop": [42]]], ["hooks": ["Stop": [["hooks": "invalid"]]]]
        ]
        for invalid in invalidFiles {
            defaults.set("custom", forKey: "agents.claude.configDirectory")
            try write(invalid, to: "custom/settings.json")
            let file = root.appendingPathComponent("custom/settings.json")
            let before = try Data(contentsOf: file)
            XCTAssertEqual(cleanup().run().failures.count, 1)
            XCTAssertEqual(try Data(contentsOf: file), before)
            XCTAssertEqual(defaults.string(forKey: "agents.claude.configDirectory"), "custom")
        }
        try write(configuration(), to: "custom/settings.json")
        let retry = cleanup().run()
        XCTAssertTrue(retry.failures.isEmpty, retry.failures.description)
        XCTAssertEqual(retry.removedHandlers, 1)
        XCTAssertNil(defaults.object(forKey: "agents.claude.configDirectory"))
    }

    func testUnreadableOrBrokenSymlinkIsNotMarkedComplete() throws {
        let parent = root.appendingPathComponent(".claude")
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        let link = parent.appendingPathComponent("settings.json")
        try FileManager.default.createSymbolicLink(atPath: link.path, withDestinationPath: "../missing.json")
        XCTAssertFalse(cleanup().run().failures.isEmpty)
        try write(configuration(), to: "missing.json")
        XCTAssertEqual(cleanup().run().removedHandlers, 1)
    }

    func testOnlyExactLegacyExecutablesAndOwnedDirectCommandsAreRemoved() throws {
        let retained = [
            handler("'/Applications/NotAssist.app/Contents/MacOS/Assist' --codex-hook"),
            handler("'/Applications/Assist.app/Contents/MacOS/Assist-copy' --codex-hook"),
            handler("echo 'Assist --codex-hook \(owner)'"),
            handler("'/Applications/Assist.app/Contents/MacOS/Assist' --codex-hook \(owner) ; other-command"),
            handler("'/Applications/Assist.app/Contents/MacOS/Assist' --codex-hook \(owner)-other")
        ]
        try write(["hooks": ["Stop": [["hooks": retained + [
            handler("'/Applications/Assist.app/Contents/MacOS/Assist' --codex-hook"),
            handler("\"/Applications/Assist Dev.app/Contents/MacOS/Assist\" --codex-hook"),
            handler("'/my'\"'\"'s folder/Assist' --claude-code-hook \(owner) --assist-agent-version='1.0'")
        ]]]]], to: ".codex/hooks.json")
        let result = cleanup().run()
        XCTAssertTrue(result.failures.isEmpty, result.failures.description)
        XCTAssertEqual(result.removedHandlers, 3)
        let hooks = try XCTUnwrap(try read(".codex/hooks.json")["hooks"] as? [String: [[String: Any]]])
        XCTAssertEqual(hooks["Stop"]?.first?["hooks"] as? [[String: String]], retained)
    }

    func testStaleSocketRemovedWithoutRemovingCaptureData() throws {
        let descriptor = try makeSocket(listening: false)
        Darwin.close(descriptor)
        try Data("keep capture".utf8).write(to: root.appendingPathComponent("screenshot.png"))
        let result = cleanup().run()
        XCTAssertTrue(result.failures.isEmpty, result.failures.description)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("coding-agent.sock").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("screenshot.png").path))
    }

    func testLiveSocketAndNonSocketFilesArePreserved() throws {
        let descriptor = try makeSocket(listening: true)
        let socketURL = root.appendingPathComponent("coding-agent.sock")
        XCTAssertFalse(cleanup().run().failures.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: socketURL.path))
        Darwin.close(descriptor)
        XCTAssertTrue(cleanup().run().failures.isEmpty)
        try Data("user data".utf8).write(to: socketURL)
        XCTAssertFalse(cleanup().run().failures.isEmpty)
        XCTAssertEqual(try String(contentsOf: socketURL, encoding: .utf8), "user data")
    }

    func testObsoleteCommandsNeverDecideApprovalsOrAnswerQuestions() {
        XCTAssertFalse(RetiredAgentHookCommand.isInvocation(["Assist"]))
        XCTAssertFalse(RetiredAgentHookCommand.isInvocation(["Assist", "--request-screen-access"]))
        for flag in ["--codex-hook", "--claude-code-hook"] {
            let arguments = ["Assist", flag]
            XCTAssertTrue(RetiredAgentHookCommand.isInvocation(arguments))
            for event in ["SessionStart", "UserPromptSubmit", "PermissionRequest", "PreToolUse", "PostToolUse"] {
                let payload = Data("{\"hook_event_name\":\"\(event)\"}".utf8)
                XCTAssertTrue(RetiredAgentHookCommand.response(arguments: arguments, payload: payload).isEmpty)
            }
            XCTAssertTrue(RetiredAgentHookCommand.response(arguments: arguments, payload: Data("invalid".utf8)).isEmpty)
        }
        let stop = Data("{\"hook_event_name\":\"Stop\"}".utf8)
        XCTAssertEqual(RetiredAgentHookCommand.response(arguments: ["Assist", "--codex-hook"], payload: stop), Data("{}\n".utf8))
        XCTAssertTrue(RetiredAgentHookCommand.response(arguments: ["Assist", "--claude-code-hook"], payload: stop).isEmpty)
    }

    @MainActor
    func testCaptureOnlyGeometryPreservesCopyFeedbackAndCompactShelf() {
        let settings = PillSettings(defaults: defaults)
        XCTAssertEqual(PillChromeMetrics.expandedSize(settings: settings).height, 210)
        XCTAssertEqual(PillChromeMetrics.collapsedSize(settings: settings), settings.collapsedSize)
        XCTAssertEqual(PillChromeMetrics.collapsedSize(settings: settings, showingCopyFeedback: true).width,
                       settings.collapsedWidth + 120)
        settings.collapsedWidth = 360
        settings.expandedWidth = 440
        XCTAssertEqual(PillChromeMetrics.collapsedSize(settings: settings, showingCopyFeedback: true).width, 440)
    }

    private func cleanup(environment: [String: String] = [:]) -> RetiredAgentHooksCleanup {
        RetiredAgentHooksCleanup(defaults: defaults, homeDirectory: root, workingDirectory: root, supportDirectory: root,
                                 environment: environment, executableURL: nil)
    }

    private func handler(_ command: String) -> [String: String] { ["type": "command", "command": command] }

    private func configuration() -> [String: Any] {
        ["hooks": ["Stop": [["hooks": [handler("'/Applications/Assist.app/Contents/MacOS/Assist' --codex-hook \(owner)")]]]]]
    }

    private func write(_ object: Any, to file: String) throws {
        let url = root.appendingPathComponent(file)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: object).write(to: url)
    }

    private func read(_ file: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: root.appendingPathComponent(file))) as? [String: Any])
    }

    private func makeSocket(listening: Bool) throws -> Int32 {
        let path = root.appendingPathComponent("coding-agent.sock").path
        var address = sockaddr_un()
        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        let bytes = Array(path.utf8CString)
        guard bytes.count <= MemoryLayout.size(ofValue: address.sun_path) else { throw POSIXError(.ENAMETOOLONG) }
        withUnsafeMutableBytes(of: &address.sun_path) { destination in
            bytes.withUnsafeBytes { destination.copyBytes(from: $0) }
        }
        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        let bound = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                Darwin.bind(descriptor, $0, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
        guard bound == 0, !listening || Darwin.listen(descriptor, 1) == 0 else {
            Darwin.close(descriptor)
            throw POSIXError(.EIO)
        }
        return descriptor
    }
}
