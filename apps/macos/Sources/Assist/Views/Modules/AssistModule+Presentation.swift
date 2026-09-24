import SwiftUI

/// How a module is presented, shared by the island tabs and Settings.
extension AssistModule {
    var icon: HugeIconKind {
        switch self {
        case .clipboard: .clipboard
        case .shelf: .shelf
        case .notes: .notes
        case .timers: .timer
        case .calendar: .calendar
        case .media: .music
        case .stats: .stats
        case .screenTime: .hourglass
        case .converter: .convert
        case .revenue: .revenue
        case .aiUsage: .aiUsage
        }
    }
}
