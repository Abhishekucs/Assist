import Darwin
import Foundation

enum CodexHookIPC {
    static let commandLineFlag = "--codex-hook"
    static let maximumPayloadBytes = 1_048_576

    static var socketURL: URL {
        FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(AppIdentity.supportDirectoryName, isDirectory: true)
            .appendingPathComponent("codex-agent.sock")
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

    @discardableResult
    static func writeAll(_ data: Data, to descriptor: Int32) -> Bool {
        data.withUnsafeBytes { rawBuffer in
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
}

enum CodexHookCommand {
    static func run() -> Int32 {
        let payload = FileHandle.standardInput.readDataToEndOfFile()
        guard !payload.isEmpty,
              payload.count <= CodexHookIPC.maximumPayloadBytes,
              let event = try? JSONSerialization.jsonObject(with: payload) as? [String: Any],
              event["hook_event_name"] is String else {
            return 0
        }

        let descriptor = socket(AF_UNIX, SOCK_STREAM, 0)
        guard descriptor >= 0 else { return 0 }
        defer { Darwin.close(descriptor) }

        let connected = CodexHookIPC.withSocketAddress(path: CodexHookIPC.socketURL.path) {
            Darwin.connect(descriptor, $0, $1)
        }
        guard connected == 0 else { return 0 }

        guard CodexHookIPC.writeAll(payload, to: descriptor) else { return 0 }
        _ = Darwin.shutdown(descriptor, SHUT_WR)

        guard let response = CodexHookIPC.readAll(from: descriptor),
              !response.isEmpty else {
            return 0
        }

        FileHandle.standardOutput.write(response)
        if response.last != 0x0A {
            FileHandle.standardOutput.write(Data([0x0A]))
        }
        return 0
    }
}
