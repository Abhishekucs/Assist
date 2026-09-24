import AppKit
import Combine
import EventKit
import SwiftUI
import XCTest
@testable import Assist

final class MarketingScreenshotTests: XCTestCase {
    @MainActor
    func testExportModuleScreenshots() async throws {
        guard let outputPath = ProcessInfo.processInfo.environment["ASSIST_MODULE_SCREENSHOT_DIR"] else {
            throw XCTSkip("Set ASSIST_MODULE_SCREENSHOT_DIR to export sanitized module screenshots")
        }
        guard EKEventStore.authorizationStatus(for: .event) == .notDetermined,
              EKEventStore.authorizationStatus(for: .reminder) == .notDetermined else {
            throw XCTSkip("Calendar access must be unavailable to avoid including personal events")
        }

        let output = URL(fileURLWithPath: outputPath, isDirectory: true)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let suite = "Assist.MarketingScreenshots.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

        let settings = PillSettings(defaults: defaults)
        let moduleSettings = ModuleSettings(defaults: defaults)
        for module in AssistModule.allCases {
            moduleSettings.setEnabled(module, true)
        }
        var screenTime = ScreenTimeLedger()
        let today = Date()
        for (name, bundle, minutes) in [
            ("Editor", "dev.assist.preview.editor", 88.0),
            ("Browser", "dev.assist.preview.browser", 52.0),
            ("Mail", "dev.assist.preview.mail", 21.0)
        ] {
            screenTime.record(
                from: today.addingTimeInterval(-(minutes + 1) * 60),
                to: today.addingTimeInterval(-60),
                bundleIdentifier: bundle,
                name: name,
                calendar: .current
            )
        }
        try JSONEncoder().encode(screenTime).write(to: directory.appendingPathComponent("screen-time.json"))

        let claudeDirectory = directory.appendingPathComponent(".claude/projects/demo", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeDirectory, withIntermediateDirectories: true)
        let formatter = ISO8601DateFormatter()
        let log = (0..<40).map { day -> String in
            let stamp = formatter.string(from: today.addingTimeInterval(TimeInterval(-day * 86_400)))
            return #"{"type":"assistant","message":{"id":"demo-\#(day)","model":"demo","usage":{"input_tokens":\#(500 + day * 70),"output_tokens":\#(300 + day * 50)}},"requestId":"preview-\#(day)","timestamp":"\#(stamp)"}"#
        }.joined(separator: "\n")
        try log.write(to: claudeDirectory.appendingPathComponent("session.jsonl"), atomically: true, encoding: .utf8)

        let demoStats = SystemStatsSnapshot(
            cpuUsage: 0.32,
            memoryUsed: 6_000_000_000,
            memoryTotal: 16_000_000_000,
            disk: DiskUsage(available: 180_000_000_000, total: 500_000_000_000),
            network: NetworkThroughput(receivedPerSecond: 1_250_000, sentPerSecond: 320_000),
            battery: BatteryStatus(level: 0.82, isCharging: true, isOnPowerAdapter: true, health: nil, cycleCount: nil)
        )
        let modules = ModuleServices(
            settings: moduleSettings,
            directory: directory,
            defaults: defaults,
            stats: SystemStatsService(previewSnapshot: demoStats),
            revenue: RevenueService(keys: KeychainSecretStore(service: suite)),
            aiUsage: AIUsageService(homeDirectory: directory)
        )
        let activityReady = expectation(description: "Demo AI activity loaded")
        let activityObservation = modules.aiUsage.$isHistoryReady
            .filter { $0 }
            .sink { _ in activityReady.fulfill() }
        modules.aiUsage.refresh()
        await fulfillment(of: [activityReady], timeout: 10)
        withExtendedLifetime(activityObservation) {}
        let voice = VoiceContextService(modelStateOverride: .notInstalled, microphoneAccessStateOverride: .notDetermined)
        let viewModel = PillViewModel(settings: settings, voiceContextService: voice)
        viewModel.insertTextItem(TextClipItem(id: UUID(), createdAt: Date(), text: "https://assistapp.dev"))
        viewModel.insertTextItem(TextClipItem(id: UUID(), createdAt: Date().addingTimeInterval(-60), text: "A quick thought worth keeping nearby."))
        modules.notes.text = "Ideas for today\n\nCapture the detail. Keep the momentum."
        let sampleFile = directory.appendingPathComponent("Project brief.txt")
        try "A sample file for the Shelf preview.".write(to: sampleFile, atomically: true, encoding: .utf8)
        modules.shelf.add([sampleFile])
        modules.timers.start()
        defer { modules.timers.deactivate() }

        let size = PillChromeMetrics.expandedSize(settings: settings, enabledModuleCount: moduleSettings.enabledModules.count)
        for module in AssistModule.allCases {
            moduleSettings.selectedModule = module
            let island = ModuleIslandView(
                viewModel: viewModel,
                moduleSettings: moduleSettings,
                modules: modules,
                islandWidth: size.width,
                onDragChanged: { _ in }
            )
            let preview = island
                .frame(width: size.width, height: size.height, alignment: .top)
                .background(Color.black, in: BoringNotchShape(
                    topCornerRadius: PillChromeMetrics.expandedTopCornerRadius,
                    bottomCornerRadius: PillChromeMetrics.expandedBottomCornerRadius
                ))
                .preferredColorScheme(.dark)
            try export(preview, size: size, to: output.appendingPathComponent("\(module.rawValue).png"))
        }
        viewModel.showTimerAlert(badge: "Hydrate", detail: "Time for some water")
        try export(
            PillView(
                viewModel: viewModel,
                settings: settings,
                moduleSettings: moduleSettings,
                modules: modules,
                onHoverChanged: { _ in },
                onIslandDragChanged: { _ in }
            ).frame(width: size.width, height: size.height),
            size: size,
            to: output.appendingPathComponent("hydration-alert.png")
        )
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: output.path).filter { $0.hasSuffix(".png") }.count, AssistModule.allCases.count + 1)
    }

    @MainActor
    private func export<V: View>(_ view: V, size: CGSize, to destination: URL) throws {
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        try png.write(to: destination)
    }
}
