import Foundation

enum KeyboardSoundPack: String, CaseIterable, Codable, Identifiable, Sendable {
    case soft, thock, clicky, typewriter
    case alpaca
    case inkBlack = "ink-black"
    case inkRed = "ink-red"
    case turquoiseTealios = "turquoise-tealios"
    case cream
    case holyPanda = "holy-panda"
    case boxNavy = "box-navy"
    case bucklingSpring = "buckling-spring"
    case topre
    case alpsBlue = "alps-blue"

    var id: String { rawValue }
    var title: String {
        switch self {
        case .soft: "Soft"
        case .thock: "Thock"
        case .clicky: "Clicky"
        case .typewriter: "Typewriter"
        case .alpaca: "Alpaca"
        case .inkBlack: "Ink Black"
        case .inkRed: "Ink Red"
        case .turquoiseTealios: "Turquoise Tealios"
        case .cream: "Cream"
        case .holyPanda: "Holy Panda"
        case .boxNavy: "Box Navy"
        case .bucklingSpring: "Buckling Spring"
        case .topre: "Topre"
        case .alpsBlue: "SKCM Blue"
        }
    }
    var detail: String {
        switch self {
        case .soft: "Quiet, cushioned taps"
        case .thock: "Deep, rounded taps"
        case .clicky: "Bright, crisp taps"
        case .typewriter: "Vintage-inspired mechanical taps"
        case .alpaca: "Durock · Linear"
        case .inkBlack: "Gateron · Linear"
        case .inkRed: "Gateron · Linear"
        case .turquoiseTealios: "Gateron · Linear"
        case .cream: "NovelKeys · Linear"
        case .holyPanda: "Drop · Tactile"
        case .boxNavy: "Kailh · Clicky"
        case .bucklingSpring: "IBM · Clicky"
        case .topre: "Topre · Tactile"
        case .alpsBlue: "Alps · Clicky"
        }
    }
    var isRecordedSwitch: Bool { ![Self.soft, .thock, .clicky, .typewriter].contains(self) }
    var sampleOffset: Int { Self.allCases.firstIndex(of: self)! * 12 }
    static var sampleCount: Int { allCases.count * 12 }
}
