import Darwin
import Foundation
import IOKit
import IOKit.ps

/// Samples CPU, memory, disk, network, and battery every two seconds, and only
/// while the System module is on screen.
@MainActor
final class SystemStatsService: ObservableObject {
    static let sampleInterval: TimeInterval = 2

    @Published private(set) var snapshot = SystemStatsSnapshot.empty

    private let previewSnapshot: SystemStatsSnapshot?
    private var timer: Timer?
    private var previousCPU: CPULoadSample?
    private var previousNetwork: [String: InterfaceCounters]?
    private var previousNetworkDate: Date?
    private var viewerCount = 0

    init(previewSnapshot: SystemStatsSnapshot? = nil) {
        self.previewSnapshot = previewSnapshot
        if let previewSnapshot {
            snapshot = previewSnapshot
        }
    }

    /// Starts sampling for a view that shows the stats. Balanced by `stop()`.
    func start() {
        guard previewSnapshot == nil else { return }
        viewerCount += 1
        guard timer == nil else { return }
        sample()
        let timer = Timer(timeInterval: Self.sampleInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sample()
            }
        }
        timer.tolerance = 0.2
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func stop() {
        viewerCount = max(viewerCount - 1, 0)
        guard viewerCount == 0 else { return }
        timer?.invalidate()
        timer = nil
        previousCPU = nil
        previousNetwork = nil
        previousNetworkDate = nil
    }

    private func sample() {
        let now = Date()
        var next = SystemStatsSnapshot(memoryTotal: ProcessInfo.processInfo.physicalMemory)

        if let cpu = SystemStatsSampler.cpuLoad() {
            if let previousCPU {
                next.cpuUsage = CPULoadSample.usage(from: previousCPU, to: cpu)
            }
            previousCPU = cpu
        }

        next.memoryUsed = SystemStatsSampler.memoryUsed()
        next.disk = SystemStatsSampler.startupDisk()

        let network = SystemStatsSampler.interfaceCounters()
        if let previousNetwork, let previousNetworkDate {
            next.network = NetworkThroughput.between(
                previousNetwork,
                network,
                interval: now.timeIntervalSince(previousNetworkDate)
            )
        }
        previousNetwork = network
        previousNetworkDate = now

        next.battery = SystemStatsSampler.battery()
        snapshot = next
    }
}

/// Reads the numbers behind the System module straight from the kernel and
/// IOKit. Nothing here needs a permission.
enum SystemStatsSampler {
    private static let host: host_t = mach_host_self()

    static func cpuLoad() -> CPULoadSample? {
        var info = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics(host, HOST_CPU_LOAD_INFO, reboundPointer, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        return CPULoadSample(
            user: info.cpu_ticks.0,
            system: info.cpu_ticks.1,
            idle: info.cpu_ticks.2,
            nice: info.cpu_ticks.3
        )
    }

    /// Memory in use as Activity Monitor counts it: app memory, wired
    /// memory, and memory held by the compressor.
    static func memoryUsed() -> UInt64? {
        var statistics = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &statistics) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { reboundPointer in
                host_statistics64(host, HOST_VM_INFO64, reboundPointer, &count)
            }
        }
        guard result == KERN_SUCCESS else { return nil }

        var pageSize: vm_size_t = 0
        guard host_page_size(host, &pageSize) == KERN_SUCCESS else { return nil }

        let internalPages = UInt64(statistics.internal_page_count)
        let purgeablePages = UInt64(statistics.purgeable_count)
        let appPages = internalPages > purgeablePages ? internalPages - purgeablePages : 0
        let usedPages = appPages + UInt64(statistics.wire_count) + UInt64(statistics.compressor_page_count)
        return usedPages * UInt64(pageSize)
    }

    static func startupDisk() -> DiskUsage? {
        let values = try? URL(fileURLWithPath: "/").resourceValues(forKeys: [
            .volumeAvailableCapacityForImportantUsageKey,
            .volumeTotalCapacityKey
        ])
        guard let available = values?.volumeAvailableCapacityForImportantUsage,
              let total = values?.volumeTotalCapacity,
              total > 0 else { return nil }
        return DiskUsage(available: available, total: Int64(total))
    }

    /// Byte counters for the Mac's physical interfaces (Wi-Fi and Ethernet,
    /// named "en…"), leaving out loopback and VPN tunnels that would count
    /// the same traffic twice.
    static func interfaceCounters() -> [String: InterfaceCounters] {
        var counters: [String: InterfaceCounters] = [:]
        var addresses: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addresses) == 0 else { return counters }
        defer { freeifaddrs(addresses) }

        var cursor = addresses
        while let pointer = cursor {
            let entry = pointer.pointee
            cursor = entry.ifa_next

            guard let address = entry.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_LINK),
                  (entry.ifa_flags & UInt32(IFF_UP)) != 0,
                  let data = entry.ifa_data else { continue }

            let name = String(cString: entry.ifa_name)
            guard name.hasPrefix("en") else { continue }

            let interfaceData = data.assumingMemoryBound(to: if_data.self).pointee
            counters[name] = InterfaceCounters(
                received: interfaceData.ifi_ibytes,
                sent: interfaceData.ifi_obytes
            )
        }
        return counters
    }

    static func battery() -> BatteryStatus? {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return nil
        }

        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(snapshot, source)?
                .takeUnretainedValue() as? [String: Any],
                (description[kIOPSTypeKey] as? String) == kIOPSInternalBatteryType,
                let current = description[kIOPSCurrentCapacityKey] as? Int,
                let maximum = description[kIOPSMaxCapacityKey] as? Int,
                maximum > 0 else { continue }

            let health = batteryHealth()
            return BatteryStatus(
                level: min(max(Double(current) / Double(maximum), 0), 1),
                isCharging: description[kIOPSIsChargingKey] as? Bool ?? false,
                isOnPowerAdapter: (description[kIOPSPowerSourceStateKey] as? String) == kIOPSACPowerValue,
                health: health.health,
                cycleCount: health.cycleCount
            )
        }
        return nil
    }

    /// Full-charge capacity against design capacity, and the cycle count,
    /// from the battery's registry entry. Apple silicon reports the raw
    /// full-charge capacity separately from its percentage-based MaxCapacity.
    private static func batteryHealth() -> (health: Double?, cycleCount: Int?) {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return (nil, nil) }
        defer { IOObjectRelease(service) }

        func integer(_ key: String) -> Int? {
            IORegistryEntryCreateCFProperty(service, key as CFString, kCFAllocatorDefault, 0)?
                .takeRetainedValue() as? Int
        }

        let cycleCount = integer("CycleCount")
        guard let design = integer("DesignCapacity"), design > 0,
              let fullCharge = integer("AppleRawMaxCapacity") ?? integer("MaxCapacity"),
              fullCharge > 100 || design <= 100 else {
            return (nil, cycleCount)
        }
        return (min(max(Double(fullCharge) / Double(design), 0), 1), cycleCount)
    }
}
