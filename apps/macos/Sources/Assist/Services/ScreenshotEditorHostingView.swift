import AppKit
import SwiftUI

final class ScreenshotEditorHostingView<Content: View>: NSHostingView<Content> {
    var onHoverChanged: ((Bool) -> Void)?
    /// Points use SwiftUI's top-left origin, independent of the hosting view's orientation.
    var visibleSurfaceContains: ((CGPoint) -> Bool)?
    private var hoverTrackingArea: NSTrackingArea?
    private var lastHoverState: Bool?

    func containsVisibleSurface(_ point: CGPoint) -> Bool {
        let surfacePoint = CGPoint(
            x: point.x - bounds.minX,
            y: isFlipped ? point.y - bounds.minY : bounds.maxY - point.y
        )
        return bounds.contains(point) && (visibleSurfaceContains?(surfacePoint) ?? true)
    }

    func synchronizeHover(at point: CGPoint) {
        // Events during a reveal/resize are intentionally ignored by the window owner.
        // Resynchronize both the recipient and our transition cache when it finishes.
        lastHoverState = nil
        reportHover(containsVisibleSurface(point))
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard containsVisibleSurface(point) else { return nil }
        return super.hitTest(point)
    }

    override func updateTrackingAreas() {
        if let hoverTrackingArea {
            removeTrackingArea(hoverTrackingArea)
        }

        let trackingArea = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
        hoverTrackingArea = trackingArea
        super.updateTrackingAreas()
    }

    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        updateHover(with: event)
    }

    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        updateHover(with: event)
    }

    private func updateHover(with event: NSEvent) {
        reportHover(containsVisibleSurface(convert(event.locationInWindow, from: nil)))
    }

    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        reportHover(false)
    }

    private func reportHover(_ isInside: Bool) {
        guard lastHoverState != isInside else { return }
        lastHoverState = isInside
        onHoverChanged?(isInside)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override var acceptsFirstResponder: Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        // Keep the panel non-activating, but make its own keyboard shortcuts available
        // after the user deliberately interacts with it.
        window?.makeKey()
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}
