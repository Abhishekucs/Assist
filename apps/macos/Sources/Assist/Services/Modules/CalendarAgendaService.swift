import AppKit
import Combine
@preconcurrency import EventKit

/// The next seven days of events and the open reminders, read from the
/// calendars and lists already on this Mac through EventKit.
@MainActor
final class CalendarAgendaService: ObservableObject {
    enum Access: Equatable {
        case notDetermined
        case denied
        case granted
    }

    static let dayCount = 7
    static let reminderLimit = 40

    @Published private(set) var eventAccess: Access
    @Published private(set) var reminderAccess: Access
    @Published private(set) var days: [AgendaDay] = []
    @Published private(set) var reminders: [AgendaReminder] = []
    @Published private(set) var errorMessage: String?

    private let store = EKEventStore()
    private var changeCancellable: AnyCancellable?
    private var reminderFetchID = UUID()

    init() {
        eventAccess = Self.access(for: .event)
        reminderAccess = Self.access(for: .reminder)
        changeCancellable = NotificationCenter.default
            .publisher(for: .EKEventStoreChanged, object: store)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.refresh()
                }
            }
    }

    var needsAccess: Bool {
        eventAccess != .granted || reminderAccess != .granted
    }

    /// Asks for calendar and reminder access the first time; after a denial,
    /// opens the privacy pane where access can be turned on.
    func requestAccess() {
        if eventAccess == .notDetermined {
            store.requestFullAccessToEvents { @Sendable [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.accessChanged()
                }
            }
        } else if eventAccess == .denied {
            openPrivacyPane("Privacy_Calendars")
        }

        if reminderAccess == .notDetermined {
            store.requestFullAccessToReminders { @Sendable [weak self] _, _ in
                Task { @MainActor [weak self] in
                    self?.accessChanged()
                }
            }
        } else if reminderAccess == .denied, eventAccess != .denied {
            openPrivacyPane("Privacy_Reminders")
        }
    }

    func refresh() {
        eventAccess = Self.access(for: .event)
        reminderAccess = Self.access(for: .reminder)

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: Date())
        guard let end = calendar.date(byAdding: .day, value: Self.dayCount, to: start) else { return }

        if eventAccess == .granted {
            let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
            let events = store.events(matching: predicate).map { event in
                AgendaEvent(
                    id: "\(event.eventIdentifier ?? UUID().uuidString)-\(event.startDate.timeIntervalSinceReferenceDate)",
                    title: event.title ?? "",
                    start: event.startDate,
                    end: event.endDate,
                    isAllDay: event.isAllDay,
                    location: event.location
                )
            }
            days = AgendaGrouping.days(for: events, from: start, dayCount: Self.dayCount, calendar: calendar)
        } else {
            days = []
        }

        if reminderAccess == .granted {
            let fetchID = UUID()
            reminderFetchID = fetchID
            let predicate = store.predicateForIncompleteReminders(
                withDueDateStarting: nil,
                ending: nil,
                calendars: nil
            )
            store.fetchReminders(matching: predicate) { @Sendable [weak self] fetched in
                let calendar = Calendar.current
                let values = (fetched ?? []).map { reminder in
                    AgendaReminder(
                        id: reminder.calendarItemIdentifier,
                        title: reminder.title ?? "",
                        dueDate: reminder.dueDateComponents.flatMap { calendar.date(from: $0) }
                    )
                }
                Task { @MainActor [weak self] in
                    guard let self, self.reminderFetchID == fetchID else { return }
                    self.reminders = Array(AgendaGrouping.sortedReminders(values).prefix(Self.reminderLimit))
                }
            }
        } else {
            reminders = []
        }
    }

    /// Marks a reminder done in the Reminders database, as ticking it in the
    /// Reminders app would.
    func complete(_ reminder: AgendaReminder) {
        guard let item = store.calendarItem(withIdentifier: reminder.id) as? EKReminder else {
            reminders.removeAll { $0.id == reminder.id }
            return
        }

        item.isCompleted = true
        do {
            try store.save(item, commit: true)
            reminders.removeAll { $0.id == reminder.id }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            DebugLogger.log("modules.calendar.reminder.complete.error", [
                "description": error.localizedDescription
            ])
        }
    }

    func openCalendarApp() {
        openApp(bundleIdentifier: "com.apple.iCal")
    }

    func openRemindersApp() {
        openApp(bundleIdentifier: "com.apple.reminders")
    }

    private func accessChanged() {
        eventAccess = Self.access(for: .event)
        reminderAccess = Self.access(for: .reminder)
        refresh()
    }

    private func openApp(bundleIdentifier: String) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return }
        NSWorkspace.shared.openApplication(
            at: url,
            configuration: NSWorkspace.OpenConfiguration(),
            completionHandler: nil
        )
    }

    private func openPrivacyPane(_ anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }

    private static func access(for type: EKEntityType) -> Access {
        switch EKEventStore.authorizationStatus(for: type) {
        case .fullAccess:
            .granted
        case .notDetermined:
            .notDetermined
        case .denied, .restricted, .writeOnly:
            .denied
        @unknown default:
            .denied
        }
    }
}
