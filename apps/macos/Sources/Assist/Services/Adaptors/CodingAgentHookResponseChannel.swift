import Darwin
import Foundation

final class CodingAgentHookResponseChannel: @unchecked Sendable {
    static let shared = CodingAgentHookResponseChannel()

    private let lock = NSLock()
    private var approvalChannels: [UUID: ChannelEntry] = [:]
    private var questionChannels: [UUID: QuestionChannelEntry] = [:]

    private struct ChannelEntry {
        let adaptor: CodingAgentAdaptor
        let channel: ResponseChannel
    }

    private struct QuestionChannelEntry {
        let adaptor: CodingAgentAdaptor
        let questions: [CodingAgentQuestion]
        let channel: ResponseChannel
    }

    private init() {}

    func registerApproval(
        _ approvalID: UUID,
        adaptor: CodingAgentAdaptor,
        channel: ResponseChannel
    ) {
        lock.withLock {
            approvalChannels[approvalID] = ChannelEntry(adaptor: adaptor, channel: channel)
        }
    }

    func registerQuestion(
        _ questionID: UUID,
        adaptor: CodingAgentAdaptor,
        questions: [CodingAgentQuestion],
        channel: ResponseChannel
    ) {
        lock.withLock {
            questionChannels[questionID] = QuestionChannelEntry(
                adaptor: adaptor,
                questions: questions,
                channel: channel
            )
        }
    }

    func resolveApproval(_ id: UUID, decision: CodingAgentApprovalDecision) {
        guard let entry = lock.withLock({ approvalChannels.removeValue(forKey: id) }) else { return }
        let response = entry.adaptor.buildApprovalResponse(decision: decision)
        entry.channel.writeResponse(response)
    }

    func answerQuestion(_ id: UUID, answers: [CodingAgentQuestionAnswer]) {
        guard let entry = lock.withLock({ questionChannels.removeValue(forKey: id) }) else { return }
        let response = entry.adaptor.buildQuestionResponse(
            questions: entry.questions,
            answers: answers
        )
        entry.channel.writeResponse(response)
    }

    func resolveApproval(_ id: UUID, decision: CodingAgentApprovalDecision, adaptor: CodingAgentAdaptor) {
        resolveApproval(id, decision: decision)
    }

    func answerQuestion(_ id: UUID, answers: [CodingAgentQuestionAnswer], adaptor: CodingAgentAdaptor) {
        answerQuestion(id, answers: answers)
    }

    func declineApproval(_ id: UUID) {
        guard let entry = lock.withLock({ approvalChannels.removeValue(forKey: id) }) else { return }
        entry.channel.closeWithoutResponse()
    }

    func declineQuestion(_ id: UUID) {
        guard let entry = lock.withLock({ questionChannels.removeValue(forKey: id) }) else { return }
        entry.channel.closeWithoutResponse()
    }

    func declineAll(forAdaptor adaptor: CodingAgentAdaptor) {
        let channels = lock.withLock {
            let approvalEntries = approvalChannels.values.filter { $0.adaptor.provider == adaptor.provider }
            let questionEntries = questionChannels.values.filter { $0.adaptor.provider == adaptor.provider }
            approvalChannels = approvalChannels.filter { $0.value.adaptor.provider != adaptor.provider }
            questionChannels = questionChannels.filter { $0.value.adaptor.provider != adaptor.provider }
            return approvalEntries.map(\.channel) + questionEntries.map(\.channel)
        }
        channels.forEach { $0.closeWithoutResponse() }
    }

    func resolveAutoResolutionTimeout(_ questionID: UUID) {
        guard let entry = lock.withLock({ questionChannels.removeValue(forKey: questionID) }) else { return }
        let response = entry.adaptor.buildAutoResolutionTimeoutResponse()
        entry.channel.writeResponse(response)
    }

    func closeAll() {
        let channels = lock.withLock {
            let values = Array(approvalChannels.values.map(\.channel))
                + Array(questionChannels.values.map(\.channel))
            approvalChannels.removeAll()
            questionChannels.removeAll()
            return values
        }
        channels.forEach { $0.closeWithoutResponse() }
    }
}

final class ResponseChannel: @unchecked Sendable {
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

    func writeResponse(_ response: [String: Any]) {
        let (descriptor, disconnectSource) = takeResources()
        guard descriptor >= 0 else { return }
        defer {
            if let disconnectSource {
                disconnectSource.cancel()
            } else {
                Darwin.close(descriptor)
            }
        }

        guard let data = try? JSONSerialization.data(withJSONObject: response) else { return }
        _ = CodingAgentHookIPC.writeAll(data, to: descriptor)
    }

    func closeWithoutResponse() {
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
