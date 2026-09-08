import CoreGraphics

enum KeyboardVisualizerPlacement {
    static let size = CGSize(width: 364, height: 156)
    static let margin: CGFloat = 18

    /// AppKit screen coordinates, including displays left of or below the primary.
    static func frame(position: KeyboardVisualizerPosition, pointer: CGPoint, visibleFrame: CGRect) -> CGRect {
        let bounds = visibleFrame.insetBy(dx: margin, dy: margin)
        let size = CGSize(width: min(Self.size.width, bounds.width), height: min(Self.size.height, bounds.height))
        var origin: CGPoint
        switch position {
        case .followPointer:
            let right = pointer.x + margin
            let below = pointer.y - margin - size.height
            origin = CGPoint(
                x: right + size.width <= bounds.maxX ? right : pointer.x - margin - size.width,
                y: below >= bounds.minY ? below : pointer.y + margin
            )
        case .bottomLeft:
            origin = CGPoint(x: bounds.minX, y: bounds.minY)
        case .bottomRight:
            origin = CGPoint(x: bounds.maxX - size.width, y: bounds.minY)
        }
        origin.x = min(max(origin.x, bounds.minX), bounds.maxX - size.width)
        origin.y = min(max(origin.y, bounds.minY), bounds.maxY - size.height)
        return CGRect(origin: origin, size: size)
    }
}
