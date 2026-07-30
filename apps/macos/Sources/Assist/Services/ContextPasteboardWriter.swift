import AppKit
import Foundation

enum ContextPasteboardError: LocalizedError {
    case contextNotReady
    case contextFileRequired
    case contextUnavailable(String)
    case imageUnavailable(String)
    case imageRepresentationFailed
    case pasteboardWriteFailed

    var errorDescription: String? {
        switch self {
        case .contextNotReady:
            "The capture context is still being prepared."
        case .contextFileRequired:
            "This legacy capture does not have a context.md file."
        case let .contextUnavailable(path):
            "The saved Markdown context could not be read at \(path)."
        case let .imageUnavailable(path):
            "The annotated screenshot could not be loaded at \(path)."
        case .imageRepresentationFailed:
            "Assist could not create all required screenshot representations."
        case .pasteboardWriteFailed:
            "macOS rejected the context and image pasteboard write."
        }
    }
}

struct ContextPasteboardWriter {
    private let pasteboard: NSPasteboard

    init(pasteboard: NSPasteboard = .general) {
        self.pasteboard = pasteboard
    }

    func write(_ item: CaptureItem, willWrite: () -> Void = {}) throws {
        let markdown = try Self.markdown(for: item)

        let imageURL = URL(fileURLWithPath: item.imagePath)
        guard let pngData = try? Data(contentsOf: imageURL),
              let image = NSImage(data: pngData) else {
            throw ContextPasteboardError.imageUnavailable(item.imagePath)
        }
        guard let tiffData = image.tiffRepresentation else {
            throw ContextPasteboardError.imageRepresentationFailed
        }

        let textItem = NSPasteboardItem()
        let imageItem = NSPasteboardItem()
        guard textItem.setString(markdown, forType: .string),
              imageItem.setData(pngData, forType: .png),
              imageItem.setData(tiffData, forType: .tiff),
              imageItem.setString(imageURL.absoluteString, forType: .fileURL) else {
            throw ContextPasteboardError.imageRepresentationFailed
        }

        willWrite()
        pasteboard.clearContents()
        guard pasteboard.writeObjects([textItem, imageItem]) else {
            throw ContextPasteboardError.pasteboardWriteFailed
        }
    }

    func writeMarkdownOnly(_ item: CaptureItem, willWrite: () -> Void = {}) throws {
        guard let contextFileURL = item.contextFileURL else {
            throw ContextPasteboardError.contextFileRequired
        }
        guard item.context.dictation?.status != .transcribing else {
            throw ContextPasteboardError.contextNotReady
        }

        let markdown: String
        do {
            markdown = try String(contentsOf: contextFileURL, encoding: .utf8)
        } catch {
            throw ContextPasteboardError.contextUnavailable(contextFileURL.path)
        }

        let textItem = NSPasteboardItem()
        guard textItem.setString(markdown, forType: .string) else {
            throw ContextPasteboardError.pasteboardWriteFailed
        }

        willWrite()
        pasteboard.clearContents()
        guard pasteboard.writeObjects([textItem]) else {
            throw ContextPasteboardError.pasteboardWriteFailed
        }
    }

    static func markdown(for item: CaptureItem) throws -> String {
        if let contextFileURL = item.contextFileURL {
            if item.context.dictation?.status == .transcribing {
                throw ContextPasteboardError.contextNotReady
            }

            do {
                return try String(contentsOf: contextFileURL, encoding: .utf8)
            } catch {
                throw ContextPasteboardError.contextUnavailable(contextFileURL.path)
            }
        }

        guard let dictation = item.context.dictation,
              dictation.status == .ready,
              !dictation.transcript.isEmpty else {
            throw ContextPasteboardError.contextNotReady
        }
        return CaptureContextMarkdown.render(item: item)
    }
}
