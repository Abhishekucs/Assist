import Foundation

/// Cumulative CPU ticks across all cores, as reported by the kernel.
struct CPULoadSample: Equatable, Sendable {
    let user: UInt32
    let system: UInt32
    let idle: UInt32
    let nice: UInt32

    /// The busy share of the time between two samples, from 0 to 1. Tick
    /// counters are 32-bit and wrap, so differences use wrapping arithmetic.
    static func usage(from old: CPULoadSample, to new: CPULoadSample) -> Double? {
        let busy = Double(new.user &- old.user) + Double(new.system &- old.system) + Double(new.nice &- old.nice)
        let idle = Double(new.idle &- old.idle)
        let total = busy + idle
        guard total > 0 else { return nil }
        return min(max(busy / total, 0), 1)
    }
}

/// Byte counters for one network interface. The kernel keeps them as 32-bit
/// values that wrap at 4 GB.
struct InterfaceCounters: Equatable, Sendable {
    let received: UInt32
    let sent: UInt32
}

struct NetworkThroughput: Equatable, Sendable {
    let receivedPerSecond: Double
    let sentPerSecond: Double

    /// Throughput between two readings, counting only interfaces present in
    /// both, so an interface that appears or disappears never shows a spike.
    static func between(
        _ old: [String: InterfaceCounters],
        _ new: [String: InterfaceCounters],
        interval: TimeInterval
    ) -> NetworkThroughput? {
        guard interval > 0 else { return nil }
        var received: UInt64 = 0
        var sent: UInt64 = 0
        for (name, counters) in new {
            guard let previous = old[name] else { continue }
            received += UInt64(counters.received &- previous.received)
            sent += UInt64(counters.sent &- previous.sent)
        }
        return NetworkThroughput(
            receivedPerSecond: Double(received) / interval,
            sentPerSecond: Double(sent) / interval
        )
    }
}

struct BatteryStatus: Equatable, Sendable {
    /// Charge, from 0 to 1.
    let level: Double
    let isCharging: Bool
    let isOnPowerAdapter: Bool
    /// Full-charge capacity relative to the design capacity, from 0 to 1.
    let health: Double?
    let cycleCount: Int?
}

struct DiskUsage: Equatable, Sendable {
    let available: Int64
    let total: Int64

    var usedFraction: Double {
        guard total > 0 else { return 0 }
        return min(max(Double(total - available) / Double(total), 0), 1)
    }
}

struct SystemStatsSnapshot: Equatable, Sendable {
    var cpuUsage: Double?
    var memoryUsed: UInt64?
    var memoryTotal: UInt64
    var disk: DiskUsage?
    var network: NetworkThroughput?
    var battery: BatteryStatus?

    static let empty = SystemStatsSnapshot(memoryTotal: ProcessInfo.processInfo.physicalMemory)

    var memoryFraction: Double? {
        guard let memoryUsed, memoryTotal > 0 else { return nil }
        return min(Double(memoryUsed) / Double(memoryTotal), 1)
    }
}

enum StatsFormatting {
    static func percent(_ fraction: Double) -> String {
        "\(Int((min(max(fraction, 0), 1) * 100).rounded()))%"
    }

    static func bytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .memory)
    }

    static func fileBytes(_ count: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: count, countStyle: .file)
    }

    static func rate(_ bytesPerSecond: Double) -> String {
        "\(ByteCountFormatter.string(fromByteCount: Int64(bytesPerSecond.rounded()), countStyle: .decimal))/s"
    }
}
