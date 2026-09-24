import SwiftUI

private typealias Mono = AssistDesignTokens.Mono
private typealias ModuleTokens = AssistDesignTokens.ModuleIsland

/// The Calendar module: the next seven days of events, plus reminders that
/// can be created and completed in place.
struct CalendarModuleView: View {
    @ObservedObject var service: CalendarAgendaService
    @ObservedObject var viewModel: PillViewModel
    @State private var newReminderTitle = ""
    @State private var isAddingReminder = false
    @FocusState private var isReminderFocused: Bool

    private static let remindersWidth: CGFloat = 186

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleTokens.toolbarSpacing) {
            IslandModuleToolbar {
                IslandModuleTitle(title: "Calendar", detail: "Next \(CalendarAgendaService.dayCount) days")
            } trailing: {
                HStack(spacing: Tokens.Spacing.xxSmall) {
                    IslandIconButton(icon: .calendar, tooltip: "Open Calendar", size: Tokens.Control.compactHeight) {
                        service.openCalendarApp()
                    }
                    IslandIconButton(icon: .check, tooltip: "Open Reminders", size: Tokens.Control.compactHeight) {
                        service.openRemindersApp()
                    }
                }
            }

            Group {
                if service.eventAccess != .granted && service.reminderAccess != .granted {
                    accessRequest(
                        title: "See your week",
                        message: "Allow access to show events and reminders from the calendars and lists on this Mac."
                    )
                } else {
                    HStack(alignment: .top, spacing: Tokens.Spacing.large) {
                        agenda
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        reminders
                            .frame(width: Self.remindersWidth)
                            .frame(maxHeight: .infinity, alignment: .topLeading)
                    }
                }
            }
            .frame(height: ModuleTokens.bodyHeight)
        }
        .onAppear {
            service.refresh()
        }
        .onChange(of: isReminderFocused) { _, focused in
            viewModel.isEditingText = focused
        }
        .onChange(of: viewModel.isEditingText) { _, editing in
            if !editing, isReminderFocused {
                isReminderFocused = false
            }
        }
        .onDisappear {
            viewModel.isEditingText = false
        }
    }

    @ViewBuilder
    private var agenda: some View {
        if service.eventAccess != .granted {
            compactAccessRequest("Allow Calendar access to see events.", action: service.requestEventAccess)
        } else if service.days.isEmpty {
            IslandEmptyState(icon: .calendar, title: "Nothing scheduled", message: "Your next seven days are clear.")
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: Tokens.Spacing.medium) {
                    ForEach(service.days) { day in
                        VStack(alignment: .leading, spacing: Tokens.Spacing.xxSmall) {
                            Text(AgendaGrouping.title(for: day.day, relativeTo: Date(), calendar: .current))
                                .font(Tokens.Typography.caption(.semibold))
                                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
                                .accessibilityAddTraits(.isHeader)

                            ForEach(day.events) { event in
                                AgendaEventRow(event: event, day: day.day)
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @ViewBuilder
    private var reminders: some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.xxSmall) {
            HStack(spacing: Tokens.Spacing.xxSmall) {
                Text("Reminders")
                    .font(Tokens.Typography.caption(.semibold))
                    .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
                    .accessibilityAddTraits(.isHeader)

                Spacer(minLength: 0)

                if service.reminderAccess == .granted {
                    IslandIconButton(
                        icon: isAddingReminder ? .close : .add,
                        tooltip: isAddingReminder ? "Cancel new reminder" : "Add reminder",
                        size: Tokens.Control.compactHeight
                    ) {
                        if isAddingReminder {
                            cancelReminder()
                        } else {
                            isAddingReminder = true
                        }
                    }
                }
            }

            if isAddingReminder {
                HStack(spacing: Tokens.Spacing.xxSmall) {
                    TextField("New reminder", text: $newReminderTitle)
                        .font(Tokens.Typography.footnote(.medium))
                        .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
                        .textFieldStyle(.plain)
                        .focused($isReminderFocused)
                        .onSubmit(addReminder)
                        .onExitCommand(perform: cancelReminder)
                        .onAppear { isReminderFocused = true }

                    IslandIconButton(
                        icon: .check,
                        tooltip: "Save reminder",
                        isEnabled: !newReminderTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        size: Tokens.Control.compactHeight
                    ) {
                        addReminder()
                    }
                }
            }

            if service.reminderAccess != .granted {
                compactAccessRequest("Allow Reminders access to add and complete them here.", action: service.requestReminderAccess)
            } else if service.reminders.isEmpty {
                Text("All done.")
                    .font(Tokens.Typography.footnote(.medium))
                    .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.secondary))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Tokens.Spacing.xxSmall) {
                        ForEach(service.reminders) { reminder in
                            ReminderRow(reminder: reminder) {
                                service.complete(reminder)
                            }
                        }
                    }
                }
            }

            if let errorMessage = service.errorMessage {
                Text(errorMessage)
                    .font(Tokens.Typography.caption())
                    .foregroundStyle(AssistDesignTokens.Palette.warning)
                    .lineLimit(2)
            }
        }
        .padding(Tokens.Spacing.medium)
        .background(IslandTileBackground())
    }

    private func addReminder() {
        guard service.createReminder(newReminderTitle) else { return }
        cancelReminder()
    }

    private func cancelReminder() {
        isReminderFocused = false
        isAddingReminder = false
        newReminderTitle = ""
    }

    private func accessRequest(title: String, message: String) -> some View {
        IslandEmptyState(icon: .calendar, title: title, message: message) {
            HStack(spacing: Tokens.Spacing.small) {
                IslandTextButton(title: "Allow Calendar", isProminent: true, action: service.requestEventAccess)
                IslandTextButton(title: "Allow Reminders", isProminent: true, action: service.requestReminderAccess)
            }
        }
    }

    private func compactAccessRequest(_ message: String, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: Tokens.Spacing.small) {
            Text(message)
                .font(Tokens.Typography.caption(.medium))
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
                .fixedSize(horizontal: false, vertical: true)
            IslandTextButton(title: "Allow access", action: action)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AgendaEventRow: View {
    let event: AgendaEvent
    let day: Date

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Tokens.Spacing.small) {
            Text(timeText)
                .font(Tokens.Typography.caption(.medium).monospacedDigit())
                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.secondary))
                .frame(width: 58, alignment: .leading)

            VStack(alignment: .leading, spacing: 0) {
                Text(event.title.isEmpty ? "Untitled event" : event.title)
                    .font(Tokens.Typography.footnote(.medium))
                    .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
                    .lineLimit(1)
                if let location = event.location, !location.isEmpty {
                    Text(location)
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
                        .lineLimit(1)
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var timeText: String {
        if event.isAllDay {
            return "All day"
        }
        // An event that began on an earlier day continues on this one.
        if event.start < day {
            return "Ongoing"
        }
        return event.start.formatted(date: .omitted, time: .shortened)
    }
}

private struct ReminderRow: View {
    let reminder: AgendaReminder
    let complete: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: complete) {
            HStack(alignment: .top, spacing: Tokens.Spacing.xSmall) {
                HugeIcon(
                    isHovered ? .check : .circle,
                    size: Tokens.Icon.regular,
                    color: Mono.ink.opacity(isHovered ? Tokens.Opacity.primary : Tokens.Opacity.muted)
                )
                .padding(.top, 1)

                VStack(alignment: .leading, spacing: 0) {
                    Text(reminder.title.isEmpty ? "Untitled reminder" : reminder.title)
                        .font(Tokens.Typography.footnote(.medium))
                        .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    if let dueDate = reminder.dueDate {
                        Text(dueDate.formatted(.dateTime.weekday(.abbreviated).day().hour().minute()))
                            .font(Tokens.Typography.caption())
                            .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, Tokens.Spacing.xxxSmall)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointingHandCursor()
        .help("Mark as completed")
        .accessibilityLabel("Complete \(reminder.title)")
        .onHover { isHovered = $0 }
        .animation(Tokens.Motion.quick, value: isHovered)
    }
}
