import Combine
import Foundation

enum KeyboardVisualizerPosition: String, CaseIterable, Codable, Identifiable, Sendable {
    case followPointer, bottomLeft, bottomRight
    var id: String { rawValue }
    var title: String {
        switch self {
        case .followPointer: "Follow pointer"
        case .bottomLeft: "Bottom left"
        case .bottomRight: "Bottom right"
        }
    }
}

/// Holds only the keys currently down, with no text or event history.
@MainActor
final class KeyboardVisualizerState: ObservableObject {
    @Published private(set) var isVisible = false
    @Published private(set) var pressedKeys: Set<UInt16> = []

    func setVisible(_ visible: Bool) {
        if !visible { reset() }
        if isVisible != visible { isVisible = visible }
    }

    func receive(_ event: KeyboardSoundEvent) {
        guard isVisible, KeyboardVisualizerLayout.keyCodes.contains(event.keyCode) else { return }
        switch event.phase {
        case .down:
            if !pressedKeys.contains(event.keyCode) { pressedKeys.insert(event.keyCode) }
        case .up:
            if pressedKeys.contains(event.keyCode) { pressedKeys.remove(event.keyCode) }
        }
    }

    func reset() {
        if !pressedKeys.isEmpty { pressedKeys.removeAll(keepingCapacity: true) }
    }
}

struct KeyboardVisualizerKey: Identifiable, Sendable {
    let code: UInt16
    let label: String
    var units: CGFloat = 1
    var id: UInt16 { code }
}

/// Physical US ANSI layout. Labels are static key legends, never translated text.
enum KeyboardVisualizerLayout {
    static let rows: [[KeyboardVisualizerKey]] = [
        [.init(code: 53, label: "esc", units: 1.5),
         .init(code: 122, label: "F1"), .init(code: 120, label: "F2"), .init(code: 99, label: "F3"),
         .init(code: 118, label: "F4"), .init(code: 96, label: "F5"), .init(code: 97, label: "F6"),
         .init(code: 98, label: "F7"), .init(code: 100, label: "F8"), .init(code: 101, label: "F9"),
         .init(code: 109, label: "F10"), .init(code: 103, label: "F11"), .init(code: 111, label: "F12"),
         .init(code: 117, label: "del", units: 1.5)],
        [.init(code: 50, label: "`"), .init(code: 18, label: "1"), .init(code: 19, label: "2"),
         .init(code: 20, label: "3"), .init(code: 21, label: "4"), .init(code: 23, label: "5"),
         .init(code: 22, label: "6"), .init(code: 26, label: "7"), .init(code: 28, label: "8"),
         .init(code: 25, label: "9"), .init(code: 29, label: "0"), .init(code: 27, label: "−"),
         .init(code: 24, label: "="), .init(code: 51, label: "delete", units: 2)],
        [.init(code: 48, label: "tab", units: 1.5),
         .init(code: 12, label: "Q"), .init(code: 13, label: "W"), .init(code: 14, label: "E"),
         .init(code: 15, label: "R"), .init(code: 17, label: "T"), .init(code: 16, label: "Y"),
         .init(code: 32, label: "U"), .init(code: 34, label: "I"), .init(code: 31, label: "O"),
         .init(code: 35, label: "P"), .init(code: 33, label: "["), .init(code: 30, label: "]"),
         .init(code: 42, label: "\\", units: 1.5)],
        [.init(code: 57, label: "caps", units: 1.75),
         .init(code: 0, label: "A"), .init(code: 1, label: "S"), .init(code: 2, label: "D"),
         .init(code: 3, label: "F"), .init(code: 5, label: "G"), .init(code: 4, label: "H"),
         .init(code: 38, label: "J"), .init(code: 40, label: "K"), .init(code: 37, label: "L"),
         .init(code: 41, label: ";"), .init(code: 39, label: "'"),
         .init(code: 36, label: "return", units: 2.25)],
        [.init(code: 56, label: "shift", units: 2.25),
         .init(code: 6, label: "Z"), .init(code: 7, label: "X"), .init(code: 8, label: "C"),
         .init(code: 9, label: "V"), .init(code: 11, label: "B"), .init(code: 45, label: "N"),
         .init(code: 46, label: "M"), .init(code: 43, label: ","), .init(code: 47, label: "."),
         .init(code: 44, label: "/"), .init(code: 60, label: "shift", units: 1.75),
         .init(code: 126, label: "↑")],
        [.init(code: 63, label: "fn"), .init(code: 59, label: "ctrl"), .init(code: 58, label: "opt"),
         .init(code: 55, label: "⌘", units: 1.25), .init(code: 49, label: "space", units: 4.5),
         .init(code: 54, label: "⌘", units: 1.25), .init(code: 61, label: "opt"),
         .init(code: 62, label: "ctrl"), .init(code: 123, label: "←"),
         .init(code: 125, label: "↓"), .init(code: 124, label: "→")]
    ]
    static let keyCodes = Set(rows.flatMap { $0.map(\.code) })
    static let rowUnits: CGFloat = 15
}
