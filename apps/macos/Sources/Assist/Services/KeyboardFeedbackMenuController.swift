import AppKit
import Combine

/// The menu bar and Settings edit the same configuration and use the same
/// controller, so selecting a pack never creates another input tap or player.
@MainActor
final class KeyboardFeedbackMenuController: NSObject {
    private let controller: KeyboardSoundController
    private var subscriptions: Set<AnyCancellable> = []
    private let soundToggle = NSMenuItem(title: "Keyboard sounds", action: nil, keyEquivalent: "")
    private let visualizerToggle = NSMenuItem(title: "Show keyboard while typing", action: nil, keyEquivalent: "")
    private let soundItem = NSMenuItem(title: "Sound pack", action: nil, keyEquivalent: "")
    private let designItem = NSMenuItem(title: "Keyboard design", action: nil, keyEquivalent: "")
    private let positionItem = NSMenuItem(title: "Keyboard position", action: nil, keyEquivalent: "")
    private let previewItem = NSMenuItem(title: "Preview sound", action: nil, keyEquivalent: "")
    private let statusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    init(controller: KeyboardSoundController) {
        self.controller = controller
        super.init()
        configure(soundToggle, action: #selector(toggleSound))
        configure(visualizerToggle, action: #selector(toggleVisualizer))
        configure(previewItem, action: #selector(previewSound))
        soundItem.submenu = choices(KeyboardSoundPack.allCases.map { ($0.rawValue, $0.title) }, action: #selector(selectSound(_:)))
        designItem.submenu = choices(KeyboardVisualizerStyle.allCases.map { ($0.rawValue, $0.title) }, action: #selector(selectDesign(_:)))
        positionItem.submenu = choices(KeyboardVisualizerPosition.allCases.map { ($0.rawValue, $0.title) }, action: #selector(selectPosition(_:)))

        controller.settings.$configuration.removeDuplicates().sink { [weak self] value in
            self?.synchronize(value)
        }.store(in: &subscriptions)
        controller.$status.combineLatest(controller.$previewError).sink { [weak self] status, error in
            self?.synchronizeStatus(status, previewError: error)
        }.store(in: &subscriptions)
    }

    func appendItems(to menu: NSMenu) {
        for item in [soundToggle, soundItem, previewItem, visualizerToggle, designItem, positionItem, statusItem] {
            menu.addItem(item)
        }
    }

    private func configure(_ item: NSMenuItem, action: Selector) {
        item.target = self
        item.action = action
    }

    private func choices(_ values: [(String, String)], action: Selector) -> NSMenu {
        let menu = NSMenu()
        menu.autoenablesItems = false
        for (value, title) in values {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = value
            menu.addItem(item)
        }
        return menu
    }

    private func synchronize(_ value: KeyboardSoundConfiguration) {
        soundToggle.state = value.enabled ? .on : .off
        visualizerToggle.state = value.visualizerEnabled ? .on : .off
        soundItem.title = "Sound pack: \(value.pack.title)"
        designItem.title = "Keyboard design: \(value.visualizerStyle.title)"
        positionItem.title = "Keyboard position: \(value.visualizerPosition.title)"
        previewItem.title = "Preview \(value.pack.title)"
        for (item, selected) in [(soundItem, value.pack.rawValue), (designItem, value.visualizerStyle.rawValue),
                                 (positionItem, value.visualizerPosition.rawValue)] {
            for choice in item.submenu?.items ?? [] {
                choice.state = choice.representedObject as? String == selected ? .on : .off
            }
        }
    }

    private func synchronizeStatus(_ status: KeyboardSoundController.Status, previewError: String?) {
        previewItem.isEnabled = status != .recording && status != .suspended
        statusItem.action = nil
        statusItem.target = nil
        statusItem.isEnabled = false
        statusItem.isHidden = false
        if let previewError {
            statusItem.title = previewError
            return
        }
        switch status {
        case .needsPermission:
            statusItem.title = "Allow Input Monitoring…"
            configure(statusItem, action: #selector(requestPermission))
            statusItem.isEnabled = true
        case .recording: statusItem.title = "Paused while recording voice context"
        case .suspended: statusItem.title = "Keyboard feedback paused"
        case let .failed(message): statusItem.title = message
        case .ready, .off: statusItem.isHidden = true
        }
    }

    @objc private func toggleSound() { controller.settings.configuration.enabled.toggle() }
    @objc private func toggleVisualizer() { controller.settings.configuration.visualizerEnabled.toggle() }
    @objc private func previewSound() { controller.preview(controller.settings.configuration.pack) }
    @objc private func requestPermission() { controller.requestPermission() }

    @objc private func selectSound(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let pack = KeyboardSoundPack(rawValue: raw) else { return }
        controller.settings.configuration.pack = pack
    }

    @objc private func selectDesign(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let style = KeyboardVisualizerStyle(rawValue: raw) else { return }
        controller.settings.configuration.visualizerStyle = style
    }

    @objc private func selectPosition(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let position = KeyboardVisualizerPosition(rawValue: raw) else { return }
        controller.settings.configuration.visualizerPosition = position
    }
}
