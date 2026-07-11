import AppKit

extension ClipboardHistoryItem {
    var dragProvider: NSItemProvider {
        switch self {
        case let .screenshot(capture):
            capture.dragProvider
        case let .text(textClip):
            textClip.dragProvider
        }
    }
}

extension CaptureItem {
    var dragProvider: NSItemProvider {
        let imageURL = URL(fileURLWithPath: imagePath)
        let provider: NSItemProvider

        if FileManager.default.fileExists(atPath: imageURL.path),
           let fileProvider = NSItemProvider(contentsOf: imageURL) {
            provider = fileProvider
            provider.registerObject(imageURL as NSURL, visibility: .all)
        } else {
            provider = NSItemProvider(object: imagePath as NSString)
        }

        provider.suggestedName = imageURL.lastPathComponent
        provider.registerObject(imagePath as NSString, visibility: .all)
        return provider
    }
}

extension TextClipItem {
    var dragProvider: NSItemProvider {
        NSItemProvider(object: text as NSString)
    }
}
