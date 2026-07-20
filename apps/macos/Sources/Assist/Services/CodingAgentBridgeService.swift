import Darwin
import Foundation

final class CodingAgentBridgeService: @unchecked Sendable {
    private static let approvalTimeout: TimeInterval = 600

    private let listenerQueue = DispatchQueue(label: "com.thinkingsoundlab.assist.agent-listener")
    private let clientQueue = DispatchQueue(
        label: "com.thinkingsoundlab.assist.agent-clients",
        attributes: .concurrent
    )
    private let stateLock = NSLock()
    private var listenerDescriptor: Int32 = -1
    private var acceptSource: DispatchSourceRead?
    private var approvalChannels: [UUID: CodingAgentApprovalChannel] = [:]

    var onEvent: (@Sendable (CodingAgentHookEvent) -> Void)?
    var onApprovalInvalidated: (@Sendable (UUID, CodingAgentApprovalInvalidationReason) -> Void)?

    func start() throws {
        guard listenerDescriptor < 0 else { return }

        let socketURL = CodingAgentHookIPC.socketURL
        try FileManager.default.createDirectory(
            at: socketURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )

        _ = Darwin.unlink(socketURL.path)

        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else {
            throw POSIXError(.ENOTSOCK)
        }

        let didBind = CodingAgentHookIPC.withSocketAddress(path: socketURL.path) {
            Darwin.bind(descriptor, $0, $1)
        }
        guard didBind == 0 else {
            let error = POSIXErrorCode(rawValue: errno) ?? .EIO
            Darwin.close(descriptor)
            throw POSIXError(error)
        }

        guard Darwin.listen(descriptor, 16) == 0 else {
            let error = POSIXErrorCode(rawValue: errno) ?? .EIO
            Darwin.close(descriptor)
            throw POSIXError(error)
        }

        _ = chmod(socketURL.path, mode_t(0o600))
        _ = fcntl(descriptor, F_SETFL, O_NONBLOCK)
        listenerDescriptor = descriptor

        let source = DispatchSource.makeReadSource(
            fileDescriptor: descriptor,
            queue: listenerQueue
        )
        source.setEventHandler { [weak self] in
            self?.acceptAvailableClients()
        }
        acceptSource = source
        source.resume()
    }

    func stop() {
        acceptSource?.cancel()
        acceptSource = nil

        if listenerDescriptor >= 0 {
            Darwin.close(listenerDescriptor)
            listenerDescriptor = -1
        }
        _ = Darwin.unlink(CodingAgentHookIPC.socketURL.path)

        let channels = stateLock.withLock {
            let values = Array(approvalChannels.values)
            approvalChannels.removeAll()
            return values
        }
        channels.forEach { $0.closeWithoutDecision() }
    }

    func resolve(_ approvalID: UUID, decision: CodingAgentApprovalDecision) {
        let channel = stateLock.withLock {
            approvalChannels.removeValue(forKey: approvalID)
        }
        channel?.resolve(decision)
    }

    func declineToDecide(_ approvalID: UUID) {
        let channel = stateLock.withLock {
            approvalChannels.removeValue(forKey: approvalID)
        }
        channel?.closeWithoutDecision()
    }

    func declineToDecideAll() {
        let channels = stateLock.withLock {
            let values = Array(approvalChannels.values)
            approvalChannels.removeAll()
            return values
        }
        channels.forEach { $0.closeWithoutDecision() }
    }

    private func acceptAvailableClients() {
        while listenerDescriptor >= 0 {
            let clientDescriptor = Darwin.accept(listenerDescriptor, nil, nil)
            if clientDescriptor < 0 {
                if errno == EINTR { continue }
                return
            }

            guard Self.isCurrentUser(clientDescriptor) else {
                Darwin.close(clientDescriptor)
                continue
            }
            guard Self.makeBlocking(clientDescriptor) else {
                Darwin.close(clientDescriptor)
                continue
            }

            clientQueue.async { [weak self] in
                self?.handleClient(clientDescriptor)
            }
        }
    }

    private func handleClient(_ descriptor: Int32) {
        guard let payload = CodingAgentHookIPC.readFrame(from: descriptor),
              let parsedEvent = Self.parseEvent(payload) else {
            Darwin.close(descriptor)
            return
        }

        guard parsedEvent.isPermissionRequest,
              let approvalID = parsedEvent.approvalID else {
            Darwin.close(descriptor)
            onEvent?(parsedEvent)
            return
        }

        let channel = CodingAgentApprovalChannel(descriptor: descriptor)
        stateLock.withLock {
            approvalChannels[approvalID] = channel
        }
        onEvent?(parsedEvent)
        channel.startMonitoringDisconnect(on: listenerQueue) { [weak self, weak channel] in
            guard let channel else { return }
            self?.invalidateApproval(approvalID, channel: channel, reason: .disconnected)
        }

        listenerQueue.asyncAfter(deadline: .now() + Self.approvalTimeout) { [weak self] in
            self?.invalidateApproval(approvalID, channel: channel, reason: .timedOut)
        }
    }

    private func invalidateApproval(
        _ approvalID: UUID,
        channel: CodingAgentApprovalChannel,
        reason: CodingAgentApprovalInvalidationReason
    ) {
        let invalidated = stateLock.withLock {
            guard approvalChannels[approvalID] === channel else { return false }
            approvalChannels.removeValue(forKey: approvalID)
            return true
        }
        guard invalidated else { return }

        channel.closeWithoutDecision()
        onApprovalInvalidated?(approvalID, reason)
    }

    private static func parseEvent(_ data: Data) -> CodingAgentHookEvent? {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let providerRawValue = object["_assist_provider"] as? String,
              let provider = UsageLimitProvider(rawValue: providerRawValue),
              let name = object["hook_event_name"] as? String,
              let sessionID = object["session_id"] as? String,
              let cwd = object["cwd"] as? String else {
            return nil
        }

        let toolInput = object["tool_input"] as? [String: Any]
        let toolName = object["tool_name"] as? String
        let reason = toolInput?["description"] as? String
        let commandPreview = Self.commandPreview(toolInput: toolInput)
        let notificationType = object["notification_type"] as? String
        let questionPrompt = Self.questionPrompt(
            toolInput: toolInput,
            notificationMessage: object["message"] as? String
        )

        return CodingAgentHookEvent(
            provider: provider,
            name: name,
            sessionID: sessionID,
            turnID: object["turn_id"] as? String,
            source: object["source"] as? String,
            cwd: cwd,
            model: object["model"] as? String,
            version: object["_assist_agent_version"] as? String,
            taskSummary: Self.taskSummary(from: object["prompt"] as? String),
            questionPrompt: questionPrompt,
            notificationType: notificationType,
            toolName: toolName,
            commandPreview: commandPreview,
            reason: reason,
            approvalID: name == "PermissionRequest" ? UUID() : nil
        )
    }

    private static func questionPrompt(
        toolInput: [String: Any]?,
        notificationMessage: String?
    ) -> String? {
        if let questions = toolInput?["questions"] as? [[String: Any]] {
            let text = questions.compactMap { $0["question"] as? String }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            if !text.isEmpty {
                return String(text.prefix(240))
            }
        }
        return taskSummary(from: notificationMessage)
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

    private static func isCurrentUser(_ descriptor: Int32) -> Bool {
        var effectiveUserID: uid_t = 0
        var effectiveGroupID: gid_t = 0
        guard getpeereid(descriptor, &effectiveUserID, &effectiveGroupID) == 0 else {
            return false
        }
        return effectiveUserID == geteuid()
    }

    private static func makeBlocking(_ descriptor: Int32) -> Bool {
        let flags = fcntl(descriptor, F_GETFL)
        guard flags >= 0 else { return false }
        return fcntl(descriptor, F_SETFL, flags & ~O_NONBLOCK) == 0
    }
}

private final class CodingAgentApprovalChannel: @unchecked Sendable {
    private let lock = NSLock()
    private var descriptor: Int32
    private var disconnectSource: DispatchSourceRead?

    init(descriptor: Int32) {
        self.descriptor = descriptor
    }

    func startMonitoringDisconnect(
        on queue: DispatchQueue,
        handler: @escaping @Sendable () -> Void
    ) {
        lock.withLock {
            guard descriptor >= 0, disconnectSource == nil else { return }

            let monitoredDescriptor = descriptor
            let source = DispatchSource.makeReadSource(
                fileDescriptor: monitoredDescriptor,
                queue: queue
            )
            source.setEventHandler {
                var byte: UInt8 = 0
                let count = Darwin.recv(monitoredDescriptor, &byte, 1, MSG_PEEK | MSG_DONTWAIT)
                if count >= 0 || ![EAGAIN, EWOULDBLOCK, EINTR].contains(errno) {
                    handler()
                }
            }
            source.setCancelHandler {
                Darwin.close(monitoredDescriptor)
            }
            disconnectSource = source
            source.resume()
        }
    }

    func resolve(_ decision: CodingAgentApprovalDecision) {
        let (descriptor, disconnectSource) = takeResources()
        guard descriptor >= 0 else { return }
        defer {
            if let disconnectSource {
                disconnectSource.cancel()
            } else {
                Darwin.close(descriptor)
            }
        }

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

        let response: [String: Any] = [
            "hookSpecificOutput": [
                "hookEventName": "PermissionRequest",
                "decision": decisionObject
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: response) else { return }
        _ = CodingAgentHookIPC.writeAll(data, to: descriptor)
    }

    func closeWithoutDecision() {
        let (descriptor, disconnectSource) = takeResources()
        guard descriptor >= 0 else { return }

        if let disconnectSource {
            disconnectSource.cancel()
        } else {
            Darwin.close(descriptor)
        }
    }

    private func takeResources() -> (Int32, DispatchSourceRead?) {
        lock.withLock {
            let currentDescriptor = descriptor
            let currentSource = disconnectSource
            descriptor = -1
            disconnectSource = nil
            return (currentDescriptor, currentSource)
        }
    }
}

private extension NSLock {
    func withLock<T>(_ body: () -> T) -> T {
        lock()
        defer { unlock() }
        return body()
    }
}
