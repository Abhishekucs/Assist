import AppKit
import ImageIO
import XCTest
@testable import Assist

final class NotchModuleSettingsTests: XCTestCase {
    @MainActor
    func testModulesDefaultOnPersistAndKeepClipboard() throws {
        let (defaults, cleanUp) = try makeDefaults()
        defer { cleanUp() }

        let settings = ModuleSettings(defaults: defaults)
        XCTAssertEqual(settings.enabledModules, AssistModule.defaultEnabled)
        XCTAssertEqual(settings.selectedModule, .clipboard)

        settings.setEnabled(.calendar, true)
        settings.setEnabled(.shelf, false)
        settings.setEnabled(.clipboard, false)
        settings.selectedModule = .calendar

        let reloaded = ModuleSettings(defaults: defaults)
        XCTAssertEqual(reloaded.enabledModules, [.clipboard, .notes, .timers, .calendar, .stats])
        XCTAssertEqual(reloaded.selectedModule, .calendar)
    }

    @MainActor
    func testTurningOffTheSelectedModuleReturnsToClipboard() throws {
        let (defaults, cleanUp) = try makeDefaults()
        defer { cleanUp() }

        let settings = ModuleSettings(defaults: defaults)
        settings.selectedModule = .notes
        settings.setEnabled(.notes, false)
        XCTAssertEqual(settings.selectedModule, .clipboard)

        settings.selectedModule = .media
        XCTAssertEqual(settings.selectedModule, .clipboard, "A disabled module cannot be selected")
    }

    @MainActor
    func testFilesDropOnTheSelectedFileModuleOrElseTheShelf() throws {
        let (defaults, cleanUp) = try makeDefaults()
        defer { cleanUp() }

        let settings = ModuleSettings(defaults: defaults)
        XCTAssertEqual(settings.fileDropTarget, .shelf)

        settings.setEnabled(.converter, true)
        settings.selectedModule = .converter
        XCTAssertEqual(settings.fileDropTarget, .converter)

        settings.selectedModule = .notes
        XCTAssertEqual(settings.fileDropTarget, .shelf)

        settings.setEnabled(.shelf, false)
        XCTAssertEqual(settings.fileDropTarget, .converter)

        settings.setEnabled(.converter, false)
        XCTAssertNil(settings.fileDropTarget)
    }

    func testTabsStayClearOfTheNotchAndTheIslandGrowsToFitThem() {
        for count in 1...AssistModule.allCases.count {
            for preferredWidth in stride(from: CGFloat(440), through: 760, by: 40) {
                let layout = ModuleTabLayout(tabCount: count, preferredIslandWidth: preferredWidth)
                let side = ModuleTabLayout.sideWidth(forIslandWidth: layout.islandWidth)
                let trailingWidth = ModuleTabLayout.rowWidth(itemCount: layout.trailingCount)
                    + (layout.trailingCount > 0 ? ModuleTabLayout.groupSpacing : 0)
                    + ModuleTabLayout.rowWidth(itemCount: ModuleTabLayout.actionCount)

                XCTAssertEqual(layout.leadingCount + layout.trailingCount, count)
                XCTAssertGreaterThanOrEqual(layout.islandWidth, preferredWidth)
                XCTAssertLessThanOrEqual(ModuleTabLayout.rowWidth(itemCount: layout.leadingCount), side + 0.5)
                XCTAssertLessThanOrEqual(trailingWidth, side + 0.5, "\(count) tabs at \(preferredWidth)")
            }
        }

        let defaultLayout = ModuleTabLayout(tabCount: AssistModule.defaultEnabled.count, preferredIslandWidth: 560)
        XCTAssertEqual(defaultLayout.islandWidth, 560, "The default modules fit the default island")
        XCTAssertEqual(defaultLayout.trailingCount, 0)
    }

    @MainActor
    func testModuleIslandHeightMatchesItsRows() {
        let height = AssistDesignTokens.Spacing.xSmall
            + AssistDesignTokens.ModuleIsland.tabRowHeight
            + AssistDesignTokens.Spacing.medium
            + AssistDesignTokens.ModuleIsland.contentHeight
            + AssistDesignTokens.Spacing.xLarge
        XCTAssertEqual(height, PillChromeMetrics.moduleExpandedHeight)
    }

    private func makeDefaults() throws -> (UserDefaults, () -> Void) {
        let suite = "Assist.NotchModuleSettingsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        return (defaults, { defaults.removePersistentDomain(forName: suite) })
    }
}

final class FocusTimerModelTests: XCTestCase {
    func testPomodoroTakesALongBreakAfterEveryFourthSession() {
        let plan = PomodoroPlan()
        XCTAssertEqual(plan.phase(after: .focus, completedFocusSessions: 1), .shortBreak)
        XCTAssertEqual(plan.phase(after: .focus, completedFocusSessions: 3), .shortBreak)
        XCTAssertEqual(plan.phase(after: .focus, completedFocusSessions: 4), .longBreak)
        XCTAssertEqual(plan.phase(after: .shortBreak, completedFocusSessions: 1), .focus)
        XCTAssertEqual(plan.phase(after: .longBreak, completedFocusSessions: 4), .focus)
        XCTAssertEqual(plan.duration(of: .focus), 25 * 60)
    }

    func testClockMeasuresWallTimeAcrossPauses() {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)
        var clock = TimerClock()
        XCTAssertFalse(clock.hasStarted)

        clock.start(at: start)
        XCTAssertEqual(clock.elapsed(at: start.addingTimeInterval(30)), 30)
        clock.pause(at: start.addingTimeInterval(40))
        XCTAssertFalse(clock.isRunning)
        XCTAssertEqual(clock.elapsed(at: start.addingTimeInterval(500)), 40)

        clock.start(at: start.addingTimeInterval(600))
        clock.start(at: start.addingTimeInterval(700))
        XCTAssertEqual(clock.elapsed(at: start.addingTimeInterval(610)), 50, "A second start does not restart the clock")

        clock.reset()
        XCTAssertEqual(clock.elapsed(at: start.addingTimeInterval(900)), 0)
        XCTAssertFalse(clock.hasStarted)
    }

    func testClockFormatting() {
        XCTAssertEqual(TimerFormatting.clock(0), "0:00")
        XCTAssertEqual(TimerFormatting.clock(65.9), "1:05")
        XCTAssertEqual(TimerFormatting.clock(0.2, roundingUp: true), "0:01")
        XCTAssertEqual(TimerFormatting.clock(3723), "1:02:03")
        XCTAssertEqual(TimerFormatting.clock(-5), "0:00")
        XCTAssertEqual(TimerFormatting.minutes(45 * 60), "45 min")
        XCTAssertEqual(TimerFormatting.minutes(60 * 60), "1 hr")
        XCTAssertEqual(TimerFormatting.minutes(90 * 60), "1 hr 30 min")
    }

    @MainActor
    func testCountdownIsClampedAndRemembered() throws {
        let suite = "Assist.FocusTimerModelTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let timers = FocusTimerService(defaults: defaults)
        timers.select(.countdown)
        timers.setCountdown(10)
        XCTAssertEqual(timers.countdownDuration, FocusTimerService.countdownRange.lowerBound)
        timers.setCountdown(25 * 60)
        timers.adjustCountdown(byMinutes: 5)
        XCTAssertEqual(timers.displayTime, "30:00")

        let reloaded = FocusTimerService(defaults: defaults)
        XCTAssertEqual(reloaded.mode, .countdown)
        XCTAssertEqual(reloaded.countdownDuration, 30 * 60)
        reloaded.deactivate()
        timers.deactivate()
    }
}

final class CalendarAgendaModelTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    func testEventsAreGroupedByEveryDayTheyTouch() throws {
        let start = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 21)))
        func date(day: Int, hour: Int) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: 9, day: day, hour: hour))!
        }

        let events = [
            AgendaEvent(id: "late", title: "Review", start: date(day: 21, hour: 15), end: date(day: 21, hour: 16), isAllDay: false, location: nil),
            AgendaEvent(id: "early", title: "Standup", start: date(day: 21, hour: 9), end: date(day: 21, hour: 9), isAllDay: false, location: nil),
            AgendaEvent(id: "trip", title: "Trip", start: date(day: 21, hour: 0), end: date(day: 23, hour: 0), isAllDay: true, location: "Goa"),
            AgendaEvent(id: "later", title: "Later", start: date(day: 29, hour: 9), end: date(day: 29, hour: 10), isAllDay: false, location: nil)
        ]

        let days = AgendaGrouping.days(for: events, from: start, dayCount: 7, calendar: calendar)
        XCTAssertEqual(days.map { calendar.component(.day, from: $0.day) }, [21, 22])
        XCTAssertEqual(days[0].events.map(\.id), ["trip", "early", "late"])
        XCTAssertEqual(days[1].events.map(\.id), ["trip"])
    }

    func testDayTitlesAndReminderOrder() throws {
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 23, hour: 10)))
        let tomorrow = now.addingTimeInterval(24 * 60 * 60)
        XCTAssertEqual(AgendaGrouping.title(for: now, relativeTo: now, calendar: calendar), "Today")
        XCTAssertEqual(AgendaGrouping.title(for: tomorrow, relativeTo: now, calendar: calendar), "Tomorrow")
        XCTAssertFalse(AgendaGrouping.title(for: now.addingTimeInterval(3 * 24 * 60 * 60), relativeTo: now, calendar: calendar).isEmpty)

        let reminders = [
            AgendaReminder(id: "c", title: "Call", dueDate: nil),
            AgendaReminder(id: "b", title: "Book", dueDate: tomorrow),
            AgendaReminder(id: "a", title: "Apply", dueDate: now),
            AgendaReminder(id: "d", title: "Buy", dueDate: nil)
        ]
        XCTAssertEqual(AgendaGrouping.sortedReminders(reminders).map(\.id), ["a", "b", "d", "c"])
    }
}

final class NowPlayingInfoTests: XCTestCase {
    func testPlayerNotificationsAreParsed() throws {
        let playing = try XCTUnwrap(NowPlayingInfo(source: .music, userInfo: [
            "Player State": "Playing",
            "Name": "Blue in Green",
            "Artist": "Miles Davis",
            "Album": "Kind of Blue"
        ]))
        XCTAssertTrue(playing.isPlaying)
        XCTAssertEqual(playing.title, "Blue in Green")
        XCTAssertEqual(playing.artist, "Miles Davis")

        let paused = try XCTUnwrap(NowPlayingInfo(source: .spotify, userInfo: ["Player State": "Paused", "Name": "Song"]))
        XCTAssertFalse(paused.isPlaying)
        XCTAssertEqual(paused.album, "")

        XCTAssertNil(NowPlayingInfo(source: .music, userInfo: ["Player State": "Stopped", "Name": "Song"]))
        XCTAssertNil(NowPlayingInfo(source: .music, userInfo: ["Player State": "Playing", "Name": "  "]))
        XCTAssertNil(NowPlayingInfo(source: .music, userInfo: ["Name": "Song"]))
    }
}

final class SystemStatsModelTests: XCTestCase {
    func testCPUUsageHandlesCounterWrap() throws {
        let old = CPULoadSample(user: UInt32.max - 9, system: 0, idle: 100, nice: 0)
        let new = CPULoadSample(user: 20, system: 10, idle: 160, nice: 0)
        // 30 user ticks (across the wrap) + 10 system busy, 60 idle.
        XCTAssertEqual(try XCTUnwrap(CPULoadSample.usage(from: old, to: new)), 0.4, accuracy: 0.0001)
        XCTAssertNil(CPULoadSample.usage(from: new, to: new))
    }

    func testNetworkThroughputIgnoresNewInterfacesAndHandlesWrap() throws {
        let old = ["en0": InterfaceCounters(received: UInt32.max - 999, sent: 100)]
        let new = [
            "en0": InterfaceCounters(received: 1_000, sent: 300),
            "en1": InterfaceCounters(received: 9_000_000, sent: 9_000_000)
        ]
        let throughput = try XCTUnwrap(NetworkThroughput.between(old, new, interval: 2))
        XCTAssertEqual(throughput.receivedPerSecond, 1_000)
        XCTAssertEqual(throughput.sentPerSecond, 100)
        XCTAssertNil(NetworkThroughput.between(old, new, interval: 0))
    }

    func testSamplerReadsThisMac() {
        XCTAssertNotNil(SystemStatsSampler.cpuLoad())
        let memory = SystemStatsSampler.memoryUsed()
        XCTAssertNotNil(memory)
        XCTAssertLessThanOrEqual(memory ?? 0, ProcessInfo.processInfo.physicalMemory * 2)
        let disk = SystemStatsSampler.startupDisk()
        XCTAssertNotNil(disk)
        XCTAssertGreaterThan(disk?.total ?? 0, 0)
    }
}

final class ScreenTimeLedgerTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    func testTimeIsSplitAtMidnightAndSortedByUse() throws {
        let beforeMidnight = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 22, hour: 23, minute: 30)))
        let afterMidnight = beforeMidnight.addingTimeInterval(60 * 60)
        var ledger = ScreenTimeLedger()

        ledger.record(from: beforeMidnight, to: afterMidnight, bundleIdentifier: "com.apple.Safari", name: "Safari", calendar: calendar)
        ledger.record(from: afterMidnight, to: afterMidnight.addingTimeInterval(10 * 60), bundleIdentifier: "com.apple.dt.Xcode", name: "Xcode", calendar: calendar)
        ledger.record(from: afterMidnight, to: afterMidnight, bundleIdentifier: "com.apple.Notes", name: "Notes", calendar: calendar)

        XCTAssertEqual(ledger.total(on: beforeMidnight, calendar: calendar), 30 * 60)
        XCTAssertEqual(ledger.total(on: afterMidnight, calendar: calendar), 40 * 60)
        XCTAssertEqual(ledger.entries(on: afterMidnight, calendar: calendar).map(\.name), ["Safari", "Xcode"])
        XCTAssertEqual(ScreenTimeLedger.dayKey(for: afterMidnight, calendar: calendar), "2026-09-23")
    }

    func testPruneKeepsTheMostRecentWeek() throws {
        var ledger = ScreenTimeLedger()
        let first = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 12)))
        for day in 0..<10 {
            let start = first.addingTimeInterval(TimeInterval(day) * 24 * 60 * 60)
            ledger.record(from: start, to: start.addingTimeInterval(60), bundleIdentifier: "app.\(day)", name: "App \(day)", calendar: calendar)
        }
        ledger.prune()

        XCTAssertEqual(ledger.days.count, ScreenTimeLedger.retainedDayCount)
        XCTAssertNil(ledger.days["2026-09-01"])
        XCTAssertNotNil(ledger.days["2026-09-10"])
        XCTAssertEqual(ledger.names.count, ScreenTimeLedger.retainedDayCount)
    }
}

final class ImageConversionTests: XCTestCase {
    func testOutputNamesNeverReplaceExistingFiles() {
        let source = URL(fileURLWithPath: "/tmp/Shots/Photo.png")
        var existing: Set<String> = ["/tmp/Shots/Photo.jpg", "/tmp/Shots/Photo 2.jpg"]
        XCTAssertEqual(
            ImageConversionNaming.outputURL(for: source, format: .jpeg) { existing.contains($0.path) }.path,
            "/tmp/Shots/Photo 3.jpg"
        )
        existing = []
        XCTAssertEqual(
            ImageConversionNaming.outputURL(for: source, format: .pdf) { existing.contains($0.path) }.lastPathComponent,
            "Photo.pdf"
        )
        XCTAssertTrue(ImageConversionNaming.isImage(source))
        XCTAssertFalse(ImageConversionNaming.isImage(URL(fileURLWithPath: "/tmp/notes.txt")))
    }

    func testConvertsAndShrinksBesideTheOriginal() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AssistImageConversionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("Sample.png")
        try writeSamplePNG(to: source, width: 400, height: 200)

        var options = ImageConversionOptions()
        options.format = .jpeg
        options.maxDimension = .small
        let jpeg = ImageConverter.convert(source, options: options)
        XCTAssertNil(jpeg.errorMessage)
        let jpegURL = try XCTUnwrap(jpeg.outputURL)
        XCTAssertEqual(jpegURL.lastPathComponent, "Sample.jpg")
        let jpegSource = try XCTUnwrap(CGImageSourceCreateWithURL(jpegURL as CFURL, nil))
        let properties = try XCTUnwrap(CGImageSourceCopyPropertiesAtIndex(jpegSource, 0, nil) as? [CFString: Any])
        XCTAssertEqual(properties[kCGImagePropertyPixelWidth] as? Int, 400, "Images are never enlarged")

        options.format = .pdf
        let pdf = ImageConverter.convert(source, options: options)
        XCTAssertNil(pdf.errorMessage)
        XCTAssertEqual(pdf.outputURL?.lastPathComponent, "Sample.pdf")
        XCTAssertGreaterThan(pdf.outputBytes ?? 0, 0)

        let notImage = directory.appendingPathComponent("notes.txt")
        try Data("hello".utf8).write(to: notImage)
        XCTAssertNotNil(ImageConverter.convert(notImage, options: options).errorMessage)
    }

    func testExistingConversionOptionsKeepTheirSettingsWithoutAFileSizeTarget() throws {
        let stored = Data(#"{"format":"heic","maxDimension":1600,"quality":"medium"}"#.utf8)
        let options = try JSONDecoder().decode(ImageConversionOptions.self, from: stored)
        XCTAssertEqual(options.format, .heic)
        XCTAssertEqual(options.maxDimension, .medium)
        XCTAssertEqual(options.quality, .medium)
        XCTAssertNil(options.maxFileSizeKB)
    }

    func testJPEGTargetWritesOnlyFilesWithinTheRequestedSize() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("Noise.png")
        try writeNoisePNG(to: source, side: 512)

        var options = ImageConversionOptions()
        options.maxFileSizeKB = 10
        let result = ImageConverter.convert(source, options: options)
        let output = try XCTUnwrap(result.outputURL, result.errorMessage ?? "No output")
        XCTAssertLessThanOrEqual(try Data(contentsOf: output).count, 10 * 1_024)
        XCTAssertLessThanOrEqual(result.outputBytes ?? .max, 10 * 1_024)
        XCTAssertTrue(FileManager.default.fileExists(atPath: source.path))

        options.format = .heic
        let heic = ImageConverter.convert(source, options: options)
        let heicURL = try XCTUnwrap(heic.outputURL, heic.errorMessage ?? "No HEIC output")
        XCTAssertLessThanOrEqual(try Data(contentsOf: heicURL).count, 10 * 1_024)

        options.format = .jpeg
        options.maxFileSizeKB = 1
        let impossible = ImageConverter.convert(source, options: options)
        XCTAssertNil(impossible.outputURL)
        XCTAssertNotNil(impossible.errorMessage)
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.appendingPathComponent("Noise 2.jpg").path))
    }

    func testLosslessFormatKeepsPixelConversionWhenFileSizeTargetIsStored() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let source = directory.appendingPathComponent("Sample.png")
        try writeSamplePNG(to: source, width: 400, height: 200)

        var options = ImageConversionOptions()
        options.format = .png
        options.maxFileSizeKB = 1
        XCTAssertNotNil(ImageConverter.convert(source, options: options).outputURL)
    }

    private func writeNoisePNG(to url: URL, side: Int) throws {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: side,
            height: side,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        let pixels = try XCTUnwrap(context.data).assumingMemoryBound(to: UInt8.self)
        for y in 0..<side {
            for x in 0..<side {
                let offset = y * context.bytesPerRow + x * 4
                let seed = UInt32(truncatingIfNeeded: x &* 73856093 ^ y &* 19349663)
                pixels[offset] = UInt8(truncatingIfNeeded: seed)
                pixels[offset + 1] = UInt8(truncatingIfNeeded: seed >> 8)
                pixels[offset + 2] = UInt8(truncatingIfNeeded: seed >> 16)
                pixels[offset + 3] = 255
            }
        }
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

    private func writeSamplePNG(to url: URL, width: Int, height: Int) throws {
        let colorSpace = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try XCTUnwrap(CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(CGColor(gray: 0.2, alpha: 0.5))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try XCTUnwrap(context.makeImage())
        let destination = try XCTUnwrap(CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }
}

final class ModuleStoreTests: XCTestCase {
    @MainActor
    func testShelfKeepsReferencesWithoutDuplicatesAndDropsDeletedFiles() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = directory.appendingPathComponent("first.txt")
        let second = directory.appendingPathComponent("second.txt")
        try Data("1".utf8).write(to: first)
        try Data("2".utf8).write(to: second)

        let store = ShelfStore(directory: directory)
        store.add([first, second])
        store.add([first, URL(string: "https://example.com")!])
        XCTAssertEqual(store.items.map(\.displayName), ["first.txt", "second.txt"])

        try FileManager.default.removeItem(at: second)
        let reloaded = ShelfStore(directory: directory)
        XCTAssertEqual(reloaded.items.map(\.displayName), ["first.txt"])

        reloaded.removeAll()
        XCTAssertTrue(ShelfStore(directory: directory).items.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: first.path), "The shelf never deletes files")
    }

    @MainActor
    func testScratchpadSavesAsYouType() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let notes = ScratchpadStore(directory: directory)
        XCTAssertTrue(notes.isEmpty)
        notes.text = "Ship the notch modules\nthen test"
        XCTAssertEqual(notes.wordCount, 6)
        XCTAssertEqual(ScratchpadStore(directory: directory).text, "Ship the notch modules\nthen test")
    }

    @MainActor
    func testUnreadableShelfFileIsNeverOverwritten() throws {
        let directory = try makeDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("shelf.json")
        try Data("not json".utf8).write(to: file)

        let store = ShelfStore(directory: directory)
        store.add([file])
        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8), "not json")
    }

    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AssistModuleStoreTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}
