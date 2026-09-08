import Combine
import Foundation

enum KeyboardSoundPack: String, CaseIterable, Codable, Identifiable, Sendable {
    case soft, thock, clicky, typewriter
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var detail: String {
        switch self {
        case .soft: "Quiet, cushioned taps"
        case .thock: "Deep, rounded taps"
        case .clicky: "Bright, crisp taps"
        case .typewriter: "Vintage-inspired mechanical taps"
        }
    }
    var sampleOffset: Int { Self.allCases.firstIndex(of: self)! * 12 }
}

struct KeyboardSoundConfiguration: Codable, Equatable, Sendable {
    var enabled = false
    var pack: KeyboardSoundPack = .thock
    var volume: Double = 0.35
    var stereo = true
    var visualizerEnabled = false
    var visualizerPosition: KeyboardVisualizerPosition = .followPointer

    var validated: Self {
        var result = self
        result.volume = volume.isFinite ? min(1, max(0, volume)) : 0.35
        return result
    }
}

extension KeyboardSoundConfiguration {
    private enum CodingKeys: String, CodingKey {
        case enabled, pack, volume, stereo, visualizerEnabled, visualizerPosition
    }

    init(from decoder: any Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            enabled: try values.decode(Bool.self, forKey: .enabled),
            pack: try values.decode(KeyboardSoundPack.self, forKey: .pack),
            volume: try values.decode(Double.self, forKey: .volume),
            stereo: try values.decode(Bool.self, forKey: .stereo),
            // Existing sound preferences survive upgrading to the visualizer.
            visualizerEnabled: try values.decodeIfPresent(Bool.self, forKey: .visualizerEnabled) ?? false,
            visualizerPosition: try values.decodeIfPresent(KeyboardVisualizerPosition.self, forKey: .visualizerPosition) ?? .followPointer
        )
    }
}

@MainActor
final class KeyboardSoundSettings: ObservableObject {
    @Published var configuration: KeyboardSoundConfiguration {
        didSet {
            if let data = try? JSONEncoder().encode(configuration.validated) {
                defaults.set(data, forKey: Self.defaultsKey)
            }
        }
    }
    private let defaults: UserDefaults
    static let defaultsKey = "keyboardSounds.configuration.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        configuration = defaults.data(forKey: Self.defaultsKey)
            .flatMap { try? JSONDecoder().decode(KeyboardSoundConfiguration.self, from: $0) }?
            .validated ?? KeyboardSoundConfiguration()
    }
}

enum KeyboardSoundPhase: Sendable { case down, up }

struct KeyboardSoundEvent: Sendable {
    let keyCode: UInt16
    let phase: KeyboardSoundPhase

    func sampleIndex(pack: KeyboardSoundPack, variation: Int) -> Int {
        let key: Int
        switch keyCode {
        case 49: key = 3
        case 36, 76: key = 4
        case 51, 117: key = 5
        default: key = abs(variation % 3)
        }
        return pack.sampleOffset + (phase == .down ? 0 : 6) + key
    }

    var pan: Float {
        // Physical ANSI positions; language/IME text never enters this path.
        for row in Self.rows {
            if let index = row.firstIndex(of: keyCode) {
                return (Float(index) / Float(row.count - 1) * 2 - 1) * 0.65
            }
        }
        switch keyCode {
        case 55, 58, 59, 63: return -0.6
        case 54, 61, 62, 123...126, 65...92: return 0.6
        default: return 0
        }
    }

    private static let rows: [[UInt16]] = [
            [50, 18, 19, 20, 21, 23, 22, 26, 28, 25, 29, 27, 24, 51],
            [48, 12, 13, 14, 15, 17, 16, 32, 34, 31, 35, 33, 30, 42],
            [57, 0, 1, 2, 3, 5, 4, 38, 40, 37, 41, 39, 36],
            [56, 6, 7, 8, 9, 11, 45, 46, 43, 47, 44, 60]
    ]
}

struct KeyboardPressState {
    private(set) var pressed: Set<UInt16> = []

    mutating func event(keyCode: UInt16, isDown: Bool, isRepeat: Bool = false) -> KeyboardSoundEvent? {
        guard !isRepeat else { return nil }
        if isDown {
            guard pressed.insert(keyCode).inserted else { return nil }
        } else {
            guard pressed.remove(keyCode) != nil else { return nil }
        }
        return KeyboardSoundEvent(keyCode: keyCode, phase: isDown ? .down : .up)
    }

    mutating func reset() { pressed.removeAll(keepingCapacity: true) }
}
