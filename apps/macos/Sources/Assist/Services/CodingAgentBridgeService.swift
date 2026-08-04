import Darwin
import Foundation

final class CodingAgentBridgeService: @unchecked Sendable {
    private static let approvalTimeout: TimeInterval = 600

    private let registry: CodingAgentAdaptorRegistry
    private let listenerQueue = DispatchQueue(label: "com.thinkingsoundlab.assist.agent-listener")
    private let clientQueue = DispatchQueue(
        label: "com.thinkingsoundlab.assist.agent-clients",
        attributes: .concurrent
    )
    private var listenerDescriptor: Int32 = -1
    private var acceptSource: DispatchSourceRead?

    var onEvent: (@Sendable (CodingAgentEvent) -> Void)?
    var onApprovalInvalidated: (@Sendable (UUID, CodingAgentApprovalInvalidationReason) -> Void)?
    var onQuestionInvalidated: (@Sendable (UUID, CodingAgentApprovalInvalidationReason) -> Void)?

    init(registry: CodingAgentAdaptorRegistry) {
        self.registry = registry
    }

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

        CodingAgentHookResponseChannel.shared.closeAll()
    }

    func resolve(_ approvalID: UUID, decision: CodingAgentApprovalDecision) {
        CodingAgentHookResponseChannel.shared.resolveApproval(approvalID, decision: decision)
    }

    func answer(_ questionID: UUID, answers: [CodingAgentQuestionAnswer]) {
        CodingAgentHookResponseChannel.shared.answerQuestion(questionID, answers: answers)
    }

    func declineToDecide(_ approvalID: UUID) {
        CodingAgentHookResponseChannel.shared.declineApproval(approvalID)
    }

    func declineToAnswer(_ questionID: UUID) {
        CodingAgentHookResponseChannel.shared.declineQuestion(questionID)
    }

    func declineToDecideAll() {
        for adaptor in registry.adaptors {
            adaptor.declineAll()
        }
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
              let object = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let providerRawValue = object["_assist_provider"] as? String,
              let adaptor = registry.adaptor(forProviderID: providerRawValue) else {
            Darwin.close(descriptor)
            return
        }

        let version = object["_assist_agent_version"] as? String

        guard let event = adaptor.parseHookEvent(object, version: version) else {
            Darwin.close(descriptor)
            return
        }

        if event.isPermissionRequest, let approvalID = event.approvalID {
            registerApproval(approvalID, adaptor: adaptor, event: event, descriptor: descriptor)
            return
        }

        if event.isAnswerableQuestion, let questionID = event.questionRequestID {
            registerQuestion(questionID, adaptor: adaptor, event: event, descriptor: descriptor)
            return
        }

        Darwin.close(descriptor)
        onEvent?(event)
    }

    private func registerApproval(
        _ approvalID: UUID,
        adaptor: CodingAgentAdaptor,
        event: CodingAgentEvent,
        descriptor: Int32
    ) {
        let channel = ResponseChannel(descriptor: descriptor)
        CodingAgentHookResponseChannel.shared.registerApproval(
            approvalID,
            adaptor: adaptor,
            channel: channel
        )
        onEvent?(event)
        channel.startMonitoringDisconnect(on: listenerQueue) { [weak self] in
            self?.invalidateApproval(approvalID, reason: .disconnected)
        }

        listenerQueue.asyncAfter(deadline: .now() + Self.approvalTimeout) { [weak self] in
            self?.invalidateApproval(approvalID, reason: .timedOut)
        }
    }

    private func registerQuestion(
        _ questionID: UUID,
        adaptor: CodingAgentAdaptor,
        event: CodingAgentEvent,
        descriptor: Int32
    ) {
        let channel = ResponseChannel(descriptor: descriptor)
        CodingAgentHookResponseChannel.shared.registerQuestion(
            questionID,
            adaptor: adaptor,
            questions: event.questions,
            channel: channel
        )
        onEvent?(event)
        channel.startMonitoringDisconnect(on: listenerQueue) { [weak self] in
            self?.invalidateQuestion(questionID, reason: .disconnected)
        }

        let timeout = event.autoResolutionMilliseconds.map { $0 / 1_000 }
            ?? Self.approvalTimeout
        listenerQueue.asyncAfter(deadline: .now() + timeout) { [weak self] in
            self?.expireQuestion(questionID)
        }
    }

    private func invalidateApproval(
        _ approvalID: UUID,
        reason: CodingAgentApprovalInvalidationReason
    ) {
        CodingAgentHookResponseChannel.shared.declineApproval(approvalID)
        onApprovalInvalidated?(approvalID, reason)
    }

    private func invalidateQuestion(
        _ questionID: UUID,
        reason: CodingAgentApprovalInvalidationReason
    ) {
        CodingAgentHookResponseChannel.shared.declineQuestion(questionID)
        onQuestionInvalidated?(questionID, reason)
    }

    private func expireQuestion(_ questionID: UUID) {
        CodingAgentHookResponseChannel.shared.resolveAutoResolutionTimeout(questionID)
        onQuestionInvalidated?(questionID, .timedOut)
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
