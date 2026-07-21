import Darwin
import Foundation

enum CodingAgentHookIPC {
    static let codexCommandLineFlag = "--codex-hook"
    static let claudeCodeCommandLineFlag = "--claude-code-hook"
    static let versionArgumentPrefix = "--assist-agent-version="
    static let maximumPayloadBytes = 1_048_576
    private static let frameHeaderByteCount = 4

    static var socketURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppIdentity.supportDirectoryName, isDirectory: true)
            .appendingPathComponent("coding-agent.sock")
    }

    static func withSocketAddress<T>(
        path: String,
        _ body: (UnsafePointer<sockaddr>, socklen_t) -> T
    ) -> T? {
        var address = sockaddr_un()
        let pathBytes = Array(path.utf8CString)
        let pathCapacity = MemoryLayout.size(ofValue: address.sun_path)
        guard pathBytes.count <= pathCapacity else { return nil }

        address.sun_family = sa_family_t(AF_UNIX)
        address.sun_len = UInt8(MemoryLayout<sockaddr_un>.size)
        withUnsafeMutableBytes(of: &address.sun_path) { destination in
            pathBytes.withUnsafeBytes { source in
                destination.copyBytes(from: source)
            }
        }

        return withUnsafePointer(to: &address) { addressPointer in
            addressPointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { socketAddress in
                body(socketAddress, socklen_t(MemoryLayout<sockaddr_un>.size))
            }
        }
    }

    static func readAll(from descriptor: Int32) -> Data? {
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 8_192)

        while data.count <= maximumPayloadBytes {
            let count = Darwin.read(descriptor, &buffer, buffer.count)
            if count == 0 {
                return data
            }
            if count < 0 {
                if errno == EINTR { continue }
                return nil
            }
            data.append(buffer, count: count)
        }

        return nil
    }

    static func readFrame(from descriptor: Int32) -> Data? {
        guard let header = readExactly(frameHeaderByteCount, from: descriptor) else {
            return nil
        }

        let payloadLength = header.reduce(UInt32(0)) { partialResult, byte in
            (partialResult << 8) | UInt32(byte)
        }
        guard payloadLength <= maximumPayloadBytes else { return nil }

        return readExactly(Int(payloadLength), from: descriptor)
    }

    @discardableResult
    static func writeFrame(_ data: Data, to descriptor: Int32) -> Bool {
        guard data.count <= maximumPayloadBytes else { return false }

        let payloadLength = UInt32(data.count)
        let header = Data([
            UInt8((payloadLength >> 24) & 0xff),
            UInt8((payloadLength >> 16) & 0xff),
            UInt8((payloadLength >> 8) & 0xff),
            UInt8(payloadLength & 0xff)
        ])
        return writeAll(header, to: descriptor) && writeAll(data, to: descriptor)
    }

    @discardableResult
    static func writeAll(_ data: Data, to descriptor: Int32) -> Bool {
        guard suppressSIGPIPE(on: descriptor) else { return false }

        return data.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return true }
            var written = 0

            while written < rawBuffer.count {
                let count = Darwin.write(
                    descriptor,
                    baseAddress.advanced(by: written),
                    rawBuffer.count - written
                )
                if count < 0 {
                    if errno == EINTR { continue }
                    return false
                }
                written += count
            }

            return true
        }
    }

    private static func readExactly(_ byteCount: Int, from descriptor: Int32) -> Data? {
        guard byteCount >= 0 else { return nil }
        guard byteCount > 0 else { return Data() }

        var data = Data()
        var buffer = [UInt8](repeating: 0, count: min(8_192, byteCount))

        while data.count < byteCount {
            let requestedByteCount = min(buffer.count, byteCount - data.count)
            let count = Darwin.read(descriptor, &buffer, requestedByteCount)
            if count == 0 { return nil }
            if count < 0 {
                if errno == EINTR { continue }
                return nil
            }
            data.append(buffer, count: count)
        }

        return data
    }

    private static func suppressSIGPIPE(on descriptor: Int32) -> Bool {
        var enabled: Int32 = 1
        return setsockopt(
            descriptor,
            SOL_SOCKET,
            SO_NOSIGPIPE,
            &enabled,
            socklen_t(MemoryLayout.size(ofValue: enabled))
        ) == 0
    }
}

enum CodingAgentHookCommand {
    static func provider(in arguments: [String]) -> UsageLimitProvider? {
        if arguments.contains(CodingAgentHookIPC.codexCommandLineFlag) {
            return .codex
        }
        if arguments.contains(CodingAgentHookIPC.claudeCodeCommandLineFlag) {
            return .claudeCode
        }
        return nil
    }

    static func run(provider: UsageLimitProvider, arguments: [String]) -> Int32 {
        let payload = FileHandle.standardInput.readDataToEndOfFile()
        guard !payload.isEmpty,
              payload.count <= CodingAgentHookIPC.maximumPayloadBytes,
              var event = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              let eventName = event["hook_event_name"] as? String else {
            return 0
        }

        let requiresEmptyJSONResponse = provider == .codex && eventName == "Stop"
        var wroteBridgeResponse = false
        defer {
            if requiresEmptyJSONResponse && !wroteBridgeResponse {
                FileHandle.standardOutput.write(Data("{}\n".utf8))
            }
        }

        event["_assist_provider"] = provider.rawValue
        if let version = arguments
            .first(where: { $0.hasPrefix(CodingAgentHookIPC.versionArgumentPrefix) })?
            .dropFirst(CodingAgentHookIPC.versionArgumentPrefix.count),
           !version.isEmpty {
            event["_assist_agent_version"] = String(version)
        }
        guard let bridgedPayload = try? JSONSerialization.data(withJSONObject: event) else {
            return 0
        }

        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return 0 }
        defer { Darwin.close(descriptor) }

        let connected = CodingAgentHookIPC.withSocketAddress(path: CodingAgentHookIPC.socketURL.path) {
            Darwin.connect(descriptor, $0, $1)
        }
        guard connected == 0 else { return 0 }

        guard CodingAgentHookIPC.writeFrame(bridgedPayload, to: descriptor) else { return 0 }

        guard let response = CodingAgentHookIPC.readAll(from: descriptor),
              !response.isEmpty else {
            return 0
        }

        FileHandle.standardOutput.write(response)
        wroteBridgeResponse = true
        if response.last != 0x0A {
            FileHandle.standardOutput.write(Data([0x0A]))
        }
        return 0
    }
}
