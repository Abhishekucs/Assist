import Combine
import XCTest
@testable import Assist

final class NowPlayingLifecycleTests: XCTestCase {
    @MainActor
    func testCollapsedPlaybackObserverRunsWithoutMediaModule() async throws {
        let suiteName = "AssistNowPlayingTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let settings = ModuleSettings(defaults: defaults)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let modules = ModuleServices(settings: settings, directory: directory, defaults: defaults)
        defer {
            modules.stop()
            try? FileManager.default.removeItem(at: directory)
            defaults.removePersistentDomain(forName: suiteName)
        }

        XCTAssertFalse(settings.isEnabled(.media))
        let playing = expectation(description: "Music notification observed without Media module")
        let title = "Assist playback test \(UUID().uuidString)"
        let subscription = modules.media.$info.compactMap { $0 }.filter { $0.title == title }.first().sink { _ in
            playing.fulfill()
        }

        modules.start()
        DistributedNotificationCenter.default().postNotificationName(
            NowPlayingInfo.Source.music.notificationName,
            object: nil,
            userInfo: ["Player State": "Playing", "Name": title],
            deliverImmediately: true
        )
        await fulfillment(of: [playing], timeout: 3)
        XCTAssertEqual(modules.media.info?.isPlaying, true)
        withExtendedLifetime(subscription) {}
    }
}
