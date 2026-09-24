import AppKit
import SwiftUI

/// Connects a module presentation to its actual AppKit window and view lifetime.
struct ModuleVisibilityObserver: NSViewRepresentable {
    let service: any VisibleModuleService

    func makeNSView(context: Context) -> ModuleVisibilityView {
        let view = ModuleVisibilityView()
        view.setService(service)
        return view
    }

    func updateNSView(_ view: ModuleVisibilityView, context: Context) {
        view.setService(service)
    }

    static func dismantleNSView(_ view: ModuleVisibilityView, coordinator: ()) {
        view.detach()
    }
}

final class ModuleVisibilityView: NSView {
    private var visibility: ModuleVisibility?

    func setService(_ service: any VisibleModuleService) {
        guard visibility?.service !== service else { return }
        detach()
        visibility = ModuleVisibility(service: service)
        visibility?.setViewVisible(!isHiddenOrHasHiddenAncestor)
        visibility?.attach(to: window)
    }

    func detach() {
        visibility?.attach(to: nil)
        visibility = nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        visibility?.setViewVisible(!isHiddenOrHasHiddenAncestor)
        visibility?.attach(to: window)
    }

    override func viewDidHide() {
        super.viewDidHide()
        visibility?.setViewVisible(false)
    }

    override func viewDidUnhide() {
        super.viewDidUnhide()
        visibility?.setViewVisible(!isHiddenOrHasHiddenAncestor)
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
