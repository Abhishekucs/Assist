import Foundation

enum HookEventParser {
    static func parse(
        payload: [String: Any],
        provider: CodingAgentProvider,
        version: String?
    ) -> CodingAgentEvent? {
        guard let name = payload["hook_event_name"] as? String,
              let sessionID = payload["session_id"] as? String,
              let cwd = payload["cwd"] as? String else {
            return nil
        }

        let toolInput = payload["tool_input"] as? [String: Any]
        let toolName = payload["tool_name"] as? String
        let reason = toolInput?["description"] as? String
        let commandPreview = Self.commandPreview(toolInput: toolInput)
        let notificationType = payload["notification_type"] as? String

        let isQuestionTool = isQuestionToolName(toolName, provider: provider)
        let questions = Self.questions(
            toolInput: toolInput,
            provider: provider
        )
        let questionPrompt = Self.questionPrompt(
            questions: questions,
            notificationMessage: payload["message"] as? String
        )
        let isAnswerableQuestion = name == "PreToolUse"
            && isQuestionTool
            && !questions.isEmpty
        let autoResolutionMilliseconds = provider.id == "codex"
            ? Self.autoResolutionMilliseconds(from: toolInput)
            : nil

        return CodingAgentEvent(
            provider: provider,
            name: name,
            sessionID: sessionID,
            turnID: payload["turn_id"] as? String,
            source: payload["source"] as? String,
            cwd: cwd,
            model: payload["model"] as? String,
            version: version,
            taskSummary: Self.taskSummary(from: payload["prompt"] as? String),
            questionPrompt: questionPrompt,
            notificationType: notificationType,
            toolName: toolName,
            commandPreview: commandPreview,
            reason: reason,
            approvalID: name == "PermissionRequest" ? UUID() : nil,
            questionRequestID: isAnswerableQuestion ? UUID() : nil,
            autoResolutionMilliseconds: autoResolutionMilliseconds,
            questions: questions
        )
    }

    private static func isQuestionToolName(_ toolName: String?, provider: CodingAgentProvider) -> Bool {
        switch provider.id {
        case "claude-code":
            toolName == "AskUserQuestion"
        case "codex":
            toolName == "request_user_input"
        default:
            false
        }
    }

    private static func autoResolutionMilliseconds(from toolInput: [String: Any]?) -> Double? {
        guard let number = toolInput?["autoResolutionMs"] as? NSNumber else { return nil }
        let milliseconds = number.doubleValue
        guard milliseconds.isFinite, milliseconds > 0 else { return nil }
        let minimum: Double = 60_000.0
        let maximum: Double = 240_000.0
        return min(max(milliseconds, minimum), maximum)
    }

    private static func questionPrompt(
        questions: [CodingAgentQuestion],
        notificationMessage: String?
    ) -> String? {
        let text = questions.map(\.prompt).joined(separator: " · ")
        if !text.isEmpty {
            return String(text.prefix(240))
        }
        return taskSummary(from: notificationMessage)
    }

    private static func questions(
        toolInput: [String: Any]?,
        provider: CodingAgentProvider
    ) -> [CodingAgentQuestion] {
        guard let rawQuestions = toolInput?["questions"] as? [[String: Any]] else {
            return []
        }

        return rawQuestions.enumerated().compactMap { index, rawQuestion in
            guard let prompt = (rawQuestion["question"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !prompt.isEmpty else {
                return nil
            }

            let rawID = (rawQuestion["id"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let id = rawID.flatMap { $0.isEmpty ? nil : $0 } ?? "question-\(index + 1)"
            let rawHeader = (rawQuestion["header"] as? String)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let header = rawHeader.flatMap { $0.isEmpty ? nil : $0 } ?? "Question \(index + 1)"
            let options = (rawQuestion["options"] as? [[String: Any]] ?? []).compactMap {
                option -> CodingAgentQuestionOption? in
                guard let label = (option["label"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                    !label.isEmpty else {
                    return nil
                }
                let description = (option["description"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return CodingAgentQuestionOption(label: label, description: description)
            }

            return CodingAgentQuestion(
                id: id,
                responseKey: provider.id == "claude-code" ? prompt : id,
                header: header,
                prompt: prompt,
                options: options,
                allowsMultipleSelection: rawQuestion["multiSelect"] as? Bool ?? false,
                allowsCustomAnswer: rawQuestion["isOther"] as? Bool ?? true,
                isSecret: rawQuestion["isSecret"] as? Bool ?? false
            )
        }
    }

    private static func taskSummary(from prompt: String?) -> String? {
        guard let prompt else { return nil }
        let collapsed = prompt
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        guard !collapsed.isEmpty else { return nil }
        return String(collapsed.prefix(120))
    }

    private static func commandPreview(toolInput: [String: Any]?) -> String? {
        guard let toolInput else { return nil }

        let rawPreview: String
        if let command = toolInput["command"] as? String {
            rawPreview = command
        } else if let data = try? JSONSerialization.data(
            withJSONObject: toolInput,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        ) {
            rawPreview = String(decoding: data, as: UTF8.self)
        } else {
            return nil
        }

        let maximumCharacters = 2_000
        guard rawPreview.count > maximumCharacters else { return rawPreview }
        return "\(rawPreview.prefix(maximumCharacters))\n…"
    }
}
