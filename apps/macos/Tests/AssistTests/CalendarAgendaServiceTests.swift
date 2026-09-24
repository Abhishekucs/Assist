import AppKit
import Combine
import EventKit
import SwiftUI
import XCTest
@testable import Assist

final class CalendarAgendaServiceTests: XCTestCase {
    @MainActor
    func testNewReminderUsesDefaultListAndTrimmedTitle() async {
        let store = TestReminderStore()
        let service = CalendarAgendaService(store: store, accessProvider: { $0 == .reminder ? .granted : .denied })
        let refreshed = expectation(description: "Created reminder appears in the notch list")
        let observation = service.$reminders
            .first(where: { $0.contains { $0.title == "Review the draft" } })
            .sink { _ in refreshed.fulfill() }

        XCTAssertTrue(service.createReminder("  Review the draft \n"))
        await fulfillment(of: [refreshed], timeout: 2)
        withExtendedLifetime(observation) {}
        XCTAssertEqual(store.savedReminder?.title, "Review the draft")
        XCTAssertEqual(store.savedReminder?.calendar?.title, "Test list")
        XCTAssertEqual(store.savedWithCommit, true)
        XCTAssertEqual(service.reminders.first?.title, "Review the draft")
        XCTAssertNil(service.errorMessage)
    }

    @MainActor
    func testNewReminderRequiresTitleAccessAndDefaultList() {
        let store = TestReminderStore()
        let service = CalendarAgendaService(store: store, accessProvider: { $0 == .reminder ? .granted : .denied })

        XCTAssertFalse(service.createReminder(" \n "))
        XCTAssertNil(store.savedReminder)

        store.hasDefaultList = false
        XCTAssertFalse(service.createReminder("Review the draft"))
        XCTAssertEqual(service.errorMessage, "Choose a default list in Reminders first.")
        XCTAssertNil(store.savedReminder)

        let denied = CalendarAgendaService(store: store, accessProvider: { _ in .denied })
        XCTAssertFalse(denied.createReminder("Review the draft"))
        XCTAssertEqual(denied.errorMessage, "Allow Reminders access before adding one.")
        XCTAssertNil(store.savedReminder)
    }

    @MainActor
    func testCalendarModuleRendersWithReminderAccess() throws {
        let suite = "Assist.CalendarAgendaServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let settings = PillSettings(defaults: defaults)
        let voice = VoiceContextService(modelStateOverride: .notInstalled, microphoneAccessStateOverride: .notDetermined)
        let viewModel = PillViewModel(settings: settings, voiceContextService: voice)
        let service = CalendarAgendaService(
            store: TestReminderStore(),
            accessProvider: { $0 == .reminder ? .granted : .denied }
        )
        let view = CalendarModuleView(service: service, viewModel: viewModel)
            .frame(width: 500, height: AssistDesignTokens.ModuleIsland.contentHeight)
            .preferredColorScheme(.dark)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(x: 0, y: 0, width: 500, height: AssistDesignTokens.ModuleIsland.contentHeight)
        hostingView.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        XCTAssertGreaterThan(png.count, 1_000)

        if let path = ProcessInfo.processInfo.environment["ASSIST_CALENDAR_PREVIEW"] {
            try png.write(to: URL(fileURLWithPath: path))
        }
    }

    @MainActor
    func testCalendarModuleRendersSeparateAccessChoicesWhenBothDenied() throws {
        let suite = "Assist.CalendarAgendaServiceTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let viewModel = PillViewModel(
            settings: PillSettings(defaults: defaults),
            voiceContextService: VoiceContextService(
                modelStateOverride: .notInstalled,
                microphoneAccessStateOverride: .notDetermined
            )
        )
        let service = CalendarAgendaService(store: TestReminderStore(), accessProvider: { _ in .denied })
        let view = CalendarModuleView(service: service, viewModel: viewModel)
            .frame(width: 500, height: AssistDesignTokens.ModuleIsland.contentHeight)
            .preferredColorScheme(.dark)
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = CGRect(x: 0, y: 0, width: 500, height: AssistDesignTokens.ModuleIsland.contentHeight)
        hostingView.layoutSubtreeIfNeeded()
        let bitmap = try XCTUnwrap(hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds))
        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)
        let png = try XCTUnwrap(bitmap.representation(using: .png, properties: [:]))
        XCTAssertGreaterThan(png.count, 1_000)

        if let path = ProcessInfo.processInfo.environment["ASSIST_CALENDAR_DENIED_PREVIEW"] {
            try png.write(to: URL(fileURLWithPath: path))
        }
    }
}

private final class TestReminderStore: EKEventStore {
    var hasDefaultList = true
    var savedReminder: EKReminder?
    var savedWithCommit: Bool?

    override func defaultCalendarForNewReminders() -> EKCalendar? {
        guard hasDefaultList else { return nil }
        let calendar = EKCalendar(for: .reminder, eventStore: self)
        calendar.title = "Test list"
        return calendar
    }

    override func save(_ reminder: EKReminder, commit: Bool) throws {
        savedReminder = reminder
        savedWithCommit = commit
    }

    override func predicateForIncompleteReminders(
        withDueDateStarting startDate: Date?,
        ending endDate: Date?,
        calendars: [EKCalendar]?
    ) -> NSPredicate {
        NSPredicate(value: true)
    }

    override func fetchReminders(
        matching predicate: NSPredicate,
        completion: @escaping ([EKReminder]?) -> Void
    ) -> Any {
        completion(savedReminder.map { [$0] } ?? [])
        return UUID()
    }
}
