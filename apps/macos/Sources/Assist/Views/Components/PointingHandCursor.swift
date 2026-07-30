import AppKit
import SwiftUI

private struct PointingHandCursorModifier: ViewModifier {
    let isEnabled: Bool
    @State private var isCursorPushed = false

    func body(content: Content) -> some View {
        content
            .onHover { isHovering in
                if isHovering && isEnabled {
                    guard !isCursorPushed else { return }
                    NSCursor.pointingHand.push()
                    isCursorPushed = true
                } else if isCursorPushed {
                    NSCursor.pop()
                    isCursorPushed = false
                }
            }
            .onDisappear {
                guard isCursorPushed else { return }
                NSCursor.pop()
                isCursorPushed = false
            }
    }
}

extension View {
    func pointingHandCursor(isEnabled: Bool = true) -> some View {
        modifier(PointingHandCursorModifier(isEnabled: isEnabled))
    }
}
