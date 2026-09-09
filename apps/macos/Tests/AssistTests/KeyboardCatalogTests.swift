import AppKit
import CryptoKit
import SwiftUI
import XCTest
@testable import Assist

final class KeyboardCatalogTests: XCTestCase {
    func testEverySoundAndDesignRoundTripsWithoutChangingOtherPreferences() throws {
        for sound in KeyboardSoundPack.allCases {
            for style in KeyboardVisualizerStyle.allCases {
                let configuration = KeyboardSoundConfiguration(enabled: true, pack: sound, volume: 0.62,
                    stereo: false, visualizerEnabled: true, visualizerPosition: .bottomLeft, visualizerStyle: style)
                let restored = try JSONDecoder().decode(KeyboardSoundConfiguration.self, from: JSONEncoder().encode(configuration))
                XCTAssertEqual(restored, configuration)
            }
        }
    }

    @MainActor
    func testAllDesignsRenderDistinctPreviewsAndVisiblePressFeedback() throws {
        let state = KeyboardVisualizerState()
        state.setEnabled(true)
        var rendered: Set<Data> = []
        for style in KeyboardVisualizerStyle.allCases {
            let idle = try render(state: state, style: style)
            rendered.insert(idle)
            state.receive(.init(keyCode: 0, phase: .down))
            let pressed = try render(state: state, style: style)
            XCTAssertNotEqual(idle, pressed, "No press feedback for \(style)")
            state.reset()
            XCTAssertEqual(try render(state: state, style: style), idle)
        }
        XCTAssertEqual(rendered.count, KeyboardVisualizerStyle.allCases.count)
    }

    func testRecordedManifestMatchesEveryPackAndAssetHash() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Sources/Assist/Resources/Sounds")
        let manifest = try JSONDecoder().decode(RecordedManifest.self, from: Data(contentsOf: root.appendingPathComponent("recorded-manifest.json")))
        XCTAssertEqual(Set(manifest.packs.map(\.id)), Set(KeyboardSoundPack.allCases.filter(\.isRecordedSwitch).map(\.rawValue)))
        for pack in manifest.packs {
            XCTAssertEqual(pack.samples.count, 12)
            for sample in pack.samples {
                let data = try Data(contentsOf: root.appendingPathComponent(sample.file))
                let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                XCTAssertEqual(hash, sample.sha256, sample.file)
                XCTAssertEqual(sample.sourceSha256.count, 64)
            }
        }
    }

    @MainActor
    private func render(state: KeyboardVisualizerState, style: KeyboardVisualizerStyle) throws -> Data {
        let content = KeyboardVisualizerView(state: state, style: style)
            .frame(width: KeyboardVisualizerLayout.size.width, height: KeyboardVisualizerLayout.size.height)
            .environment(\.assistTheme, AssistTheme(colorScheme: .dark))
            .transaction { $0.disablesAnimations = true }
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.cgImage)
        XCTAssertEqual(image.width, 560)
        XCTAssertEqual(image.height, 234)
        let data = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        if let output = ProcessInfo.processInfo.environment["ASSIST_KEYBOARD_PREVIEW_DIR"], state.pressedKeys.isEmpty {
            let folder = URL(fileURLWithPath: output, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try data.write(to: folder.appendingPathComponent("\(style.rawValue).png"))
        }
        return data
    }
}

private struct RecordedManifest: Decodable {
    struct Pack: Decodable {
        struct Sample: Decodable {
            let file: String
            let sha256: String
            let sourceSha256: String
        }
        let id: String
        let samples: [Sample]
    }
    let packs: [Pack]
}
