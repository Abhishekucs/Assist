import AppKit
import SwiftUI

@MainActor
final class PillHostingView: NSHostingView<PillView> {
    var visibleChromeRectProvider: (() -> CGRect)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard acceptsHit(at: point) else { return nil }
        return super.hitTest(point)
    }

    private func acceptsHit(at point: NSPoint) -> Bool {
        guard let chromeRect = visibleChromeRectProvider?() else { return true }
        return chromeRect.insetBy(dx: -2, dy: -2).contains(point)
    }
}
