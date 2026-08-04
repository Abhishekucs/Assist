import XCTest
@testable import Assist

final class CodingAgentEventMappingTests: XCTestCase {
    func testPermissionRequestEventParsesCorrectly() {
        let payload: [String: Any] = [
            "hook_event_name": "PermissionRequest",
            "session_id": "sess-123",
            "cwd": "/Users/test/project",
            "tool_name": "Bash",
            "tool_input": ["command": "ls -la", "description": "List files"],
            "_assist_provider": "claude-code"
        ]

        let event = HookEventParser.parse(
            payload: payload,
            provider: .claudeCode,
            version: "1.0.0"
        )

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.name, "PermissionRequest")
        XCTAssertEqual(event?.sessionID, "sess-123")
        XCTAssertEqual(event?.cwd, "/Users/test/project")
        XCTAssertEqual(event?.toolName, "Bash")
        XCTAssertEqual(event?.commandPreview, "ls -la")
        XCTAssertEqual(event?.reason, "List files")
        XCTAssertEqual(event?.version, "1.0.0")
        XCTAssertTrue(event?.isPermissionRequest ?? false)
        XCTAssertNotNil(event?.approvalID)
        XCTAssertNil(event?.questionRequestID)
    }

    func testAnswerableQuestionParsesForClaudeCode() {
        let payload: [String: Any] = [
            "hook_event_name": "PreToolUse",
            "session_id": "sess-456",
            "cwd": "/Users/test/project",
            "tool_name": "AskUserQuestion",
            "tool_input": [
                "questions": [
                    [
                        "question": "Which approach?",
                        "header": "Approach",
                        "options": [
                            ["label": "Option A", "description": "First approach"],
                            ["label": "Option B", "description": "Second approach"]
                        ],
                        "multiSelect": false
                    ]
                ]
            ],
            "_assist_provider": "claude-code"
        ]

        let event = HookEventParser.parse(
            payload: payload,
            provider: .claudeCode,
            version: nil
        )

        XCTAssertNotNil(event)
        XCTAssertTrue(event?.isAnswerableQuestion ?? false)
        XCTAssertEqual(event?.questions.count, 1)
        XCTAssertEqual(event?.questions.first?.prompt, "Which approach?")
        XCTAssertEqual(event?.questions.first?.header, "Approach")
        XCTAssertEqual(event?.questions.first?.options.count, 2)
        XCTAssertEqual(event?.questions.first?.responseKey, "Which approach?")
    }

    func testAnswerableQuestionParsesForCodex() {
        let payload: [String: Any] = [
            "hook_event_name": "PreToolUse",
            "session_id": "sess-789",
            "cwd": "/Users/test/codex-project",
            "tool_name": "request_user_input",
            "tool_input": [
                "questions": [
                    [
                        "id": "q1",
                        "question": "Deploy now?",
                        "header": "Deployment",
                        "options": [
                            ["label": "Yes", "description": "Deploy immediately"]
                        ],
                        "multiSelect": false
                    ]
                ]
            ],
            "_assist_provider": "codex"
        ]

        let event = HookEventParser.parse(
            payload: payload,
            provider: .codex,
            version: nil
        )

        XCTAssertNotNil(event)
        XCTAssertTrue(event?.isAnswerableQuestion ?? false)
        XCTAssertEqual(event?.questions.first?.id, "q1")
        XCTAssertEqual(event?.questions.first?.responseKey, "q1")
    }

    func testNonQuestionToolIsNotAnswerable() {
        let payload: [String: Any] = [
            "hook_event_name": "PreToolUse",
            "session_id": "sess-000",
            "cwd": "/test",
            "tool_name": "Bash",
            "tool_input": ["command": "echo hello"],
            "_assist_provider": "claude-code"
        ]

        let event = HookEventParser.parse(
            payload: payload,
            provider: .claudeCode,
            version: nil
        )

        XCTAssertNotNil(event)
        XCTAssertFalse(event?.isAnswerableQuestion ?? true)
    }

    func testSessionStartEventParsesCorrectly() {
        let payload: [String: Any] = [
            "hook_event_name": "SessionStart",
            "session_id": "sess-start",
            "cwd": "/Users/test/new-project",
            "source": "startup",
            "_assist_provider": "codex"
        ]

        let event = HookEventParser.parse(
            payload: payload,
            provider: .codex,
            version: "0.1.0"
        )

        XCTAssertNotNil(event)
        XCTAssertEqual(event?.name, "SessionStart")
        XCTAssertEqual(event?.source, "startup")
        XCTAssertFalse(event?.isPermissionRequest ?? true)
        XCTAssertFalse(event?.isAnswerableQuestion ?? true)
    }

    func testProviderIsQuestionToolName() {
        XCTAssertTrue(CodingAgentProvider.claudeCode.isQuestionToolName("AskUserQuestion"))
        XCTAssertFalse(CodingAgentProvider.claudeCode.isQuestionToolName("Bash"))
        XCTAssertTrue(CodingAgentProvider.codex.isQuestionToolName("request_user_input"))
        XCTAssertFalse(CodingAgentProvider.codex.isQuestionToolName("Bash"))
        XCTAssertFalse(CodingAgentProvider.opencode.isQuestionToolName("AskUserQuestion"))
    }

    func testEventSessionKey() {
        let event = CodingAgentEvent(
            provider: .claudeCode,
            name: "SessionStart",
            sessionID: "abc123",
            turnID: nil,
            source: nil,
            cwd: "/test",
            model: nil,
            version: nil,
            taskSummary: nil,
            questionPrompt: nil,
            notificationType: nil,
            toolName: nil,
            commandPreview: nil,
            reason: nil,
            approvalID: nil,
            questionRequestID: nil,
            autoResolutionMilliseconds: nil,
            questions: []
        )

        XCTAssertEqual(event.sessionKey, "claude-code:abc123")
    }

    func testStartsQuestionForNotificationType() {
        let payload: [String: Any] = [
            "hook_event_name": "Notification",
            "session_id": "sess-notif",
            "cwd": "/test",
            "notification_type": "elicitation_dialog",
            "_assist_provider": "claude-code"
        ]

        let event = HookEventParser.parse(
            payload: payload,
            provider: .claudeCode,
            version: nil
        )

        XCTAssertTrue(event?.startsQuestion ?? false)
    }

    func testFinishesQuestionForElicitationComplete() {
        let payload: [String: Any] = [
            "hook_event_name": "Notification",
            "session_id": "sess-done",
            "cwd": "/test",
            "notification_type": "elicitation_complete",
            "_assist_provider": "claude-code"
        ]

        let event = HookEventParser.parse(
            payload: payload,
            provider: .claudeCode,
            version: nil
        )

        XCTAssertTrue(event?.finishesQuestion ?? false)
    }
}
