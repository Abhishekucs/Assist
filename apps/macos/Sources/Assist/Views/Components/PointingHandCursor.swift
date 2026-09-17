import AppKit
import SwiftUI

private struct PointingHandCursorModifier: ViewModifier {
    let isEnabled: Bool
    @State private var isHovering = false
    @State private var isCursorPushed = false

    func body(content: Content) -> some View {
        content
            .onHover { isHovering in
                self.isHovering = isHovering
                updateCursor()
            }
            // A control can be enabled or disabled while the pointer rests on it.
            .onChange(of: isEnabled) {
                updateCursor()
            }
            .onDisappear {
                isHovering = false
                updateCursor()
            }
    }

    private func updateCursor() {
        let wantsPointingHand = isHovering && isEnabled
        if wantsPointingHand, !isCursorPushed {
            NSCursor.pointingHand.push()
            isCursorPushed = true
        } else if !wantsPointingHand, isCursorPushed {
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
