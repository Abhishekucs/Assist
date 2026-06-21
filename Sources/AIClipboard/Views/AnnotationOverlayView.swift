import AppKit

final class AnnotationOverlayView: NSView {
    var stroke: Stroke? {
        didSet { needsDisplay = true }
    }

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard let stroke else { return }

        NSColor.black.withAlphaComponent(0.08).setFill()
        bounds.fill()

        let color = NSColor.systemRed
        color.setStroke()
        color.setFill()

        let points = stroke.points
        if let first = points.first {
            NSColor.white.withAlphaComponent(0.95).setStroke()
            let halo = NSBezierPath(ovalIn: CGRect(
                x: first.x - 9,
                y: first.y - 9,
                width: 18,
                height: 18
            ))
            halo.lineWidth = 3
            halo.stroke()

            color.setFill()
            NSBezierPath(ovalIn: CGRect(
                x: first.x - 5,
                y: first.y - 5,
                width: 10,
                height: 10
            )).fill()
        }

        guard points.count > 1 else { return }

        let path = NSBezierPath()
        path.lineWidth = stroke.width
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        path.move(to: points[0])

        for point in points.dropFirst() {
            path.line(to: point)
        }

        NSColor.white.withAlphaComponent(0.55).setStroke()
        path.lineWidth = stroke.width + 4
        path.stroke()

        color.setStroke()
        path.lineWidth = stroke.width
        path.stroke()
    }
}
