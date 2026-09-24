import AppKit
import SwiftUI

/// Wraps island content so a click runs `onClick` and a drag hands
/// `pasteboardWriter` to AppKit, reporting the drag so the island stays open.
struct IslandDraggableCard<Content: View>: View {
    let pasteboardWriter: () -> (any NSPasteboardWriting)?
    let dragImage: () -> NSImage?
    let onClick: () -> Void
    let onDragChanged: (Bool) -> Void
    @ViewBuilder let content: Content

    var body: some View {
        content
            .overlay {
                IslandDragSourceOverlay(
                    pasteboardWriter: pasteboardWriter,
                    dragImage: dragImage,
                    onClick: onClick,
                    onDragChanged: onDragChanged
                )
            }
            .accessibilityAction {
                onClick()
            }
    }
}

private struct IslandDragSourceOverlay: NSViewRepresentable {
    let pasteboardWriter: () -> (any NSPasteboardWriting)?
    let dragImage: () -> NSImage?
    let onClick: () -> Void
    let onDragChanged: (Bool) -> Void

    func makeNSView(context: Context) -> IslandDragSourceView {
        let view = IslandDragSourceView()
        view.pasteboardWriter = pasteboardWriter
        view.dragImage = dragImage
        view.onClick = onClick
        view.onDragChanged = onDragChanged
        return view
    }

    func updateNSView(_ view: IslandDragSourceView, context: Context) {
        view.pasteboardWriter = pasteboardWriter
        view.dragImage = dragImage
        view.onClick = onClick
        view.onDragChanged = onDragChanged
    }
}

private final class IslandDragSourceView: NSView, NSDraggingSource {
    var pasteboardWriter: (() -> (any NSPasteboardWriting)?)?
    var dragImage: (() -> NSImage?)?
    var onClick: (() -> Void)?
    var onDragChanged: ((Bool) -> Void)?

    private var mouseDownEvent: NSEvent?
    private var mouseDownPoint = NSPoint.zero
    private var hasStartedDrag = false

    override var acceptsFirstResponder: Bool { true }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override var mouseDownCanMoveWindow: Bool {
        false
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }

    override func mouseDown(with event: NSEvent) {
        mouseDownEvent = event
        mouseDownPoint = convert(event.locationInWindow, from: nil)
        hasStartedDrag = false
        NSCursor.closedHand.set()
    }

    override func mouseDragged(with event: NSEvent) {
        guard !hasStartedDrag,
              dragDistance(from: mouseDownPoint, to: convert(event.locationInWindow, from: nil)) >= 3,
              let writer = pasteboardWriter?() else { return }

        hasStartedDrag = true
        onDragChanged?(true)

        let draggingItem = NSDraggingItem(pasteboardWriter: writer)
        let previewImage = dragImage?() ?? fallbackDragImage()
        draggingItem.setDraggingFrame(draggingFrame(for: previewImage), contents: previewImage)

        let session = beginDraggingSession(with: [draggingItem], event: event, source: self)
        session.animatesToStartingPositionsOnCancelOrFail = true
    }

    override func mouseUp(with event: NSEvent) {
        if !hasStartedDrag {
            onClick?()
        }

        mouseDownEvent = nil
        setOpenHandIfPointerIsInside(localPoint: convert(event.locationInWindow, from: nil))
    }

    func draggingSession(
        _ session: NSDraggingSession,
        sourceOperationMaskFor context: NSDraggingContext
    ) -> NSDragOperation {
        [.copy]
    }

    func draggingSession(
        _ session: NSDraggingSession,
        endedAt screenPoint: NSPoint,
        operation: NSDragOperation
    ) {
        onDragChanged?(false)
        mouseDownEvent = nil
        hasStartedDrag = false
        setOpenHandIfPointerIsInside(screenPoint: screenPoint)
    }

    private func dragDistance(from start: NSPoint, to end: NSPoint) -> CGFloat {
        hypot(end.x - start.x, end.y - start.y)
    }

    private func setOpenHandIfPointerIsInside(screenPoint: NSPoint) {
        guard let window else { return }

        let windowPoint = window.convertPoint(fromScreen: screenPoint)
        setOpenHandIfPointerIsInside(localPoint: convert(windowPoint, from: nil))
    }

    private func setOpenHandIfPointerIsInside(localPoint: NSPoint) {
        if bounds.contains(localPoint) {
            NSCursor.openHand.set()
        }
    }

    private func draggingFrame(for image: NSImage) -> NSRect {
        let size = image.size.width > 0 && image.size.height > 0 ? image.size : bounds.size

        return NSRect(
            x: bounds.midX - size.width / 2,
            y: bounds.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func fallbackDragImage() -> NSImage {
        let size = bounds.size.width > 0 && bounds.size.height > 0
            ? bounds.size
            : NSSize(width: AssistDesignTokens.HistoryShelf.cardSize, height: AssistDesignTokens.HistoryShelf.cardSize)

        let image = NSImage(size: size)
        image.lockFocus()
        NSColor.white.withAlphaComponent(0.16).setFill()
        NSBezierPath(
            roundedRect: NSRect(origin: .zero, size: size),
            xRadius: AssistDesignTokens.Radius.medium,
            yRadius: AssistDesignTokens.Radius.medium
        ).fill()
        image.unlockFocus()
        return image
    }
}
