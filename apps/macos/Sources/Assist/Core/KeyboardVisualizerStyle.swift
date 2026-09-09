import Foundation

enum KeyboardVisualizerStyle: String, CaseIterable, Codable, Identifiable, Sendable {
    case assist, classic, mint, royal, dolch, sand, scarlet
    var id: String { rawValue }
    var title: String { self == .assist ? "Match Assist" : rawValue.capitalized }
}
