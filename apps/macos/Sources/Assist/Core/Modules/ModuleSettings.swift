import Foundation

/// Which notch modules appear, and which one the island opens to. Main-actor
/// isolated because the island and Settings observe it.
@MainActor
final class ModuleSettings: ObservableObject {
    /// Enabled modules in island order (the order of `AssistModule.allCases`).
    @Published private(set) var enabledModules: [AssistModule] {
        didSet {
            defaults.set(enabledModules.map(\.rawValue), forKey: Keys.enabledModules)
        }
    }

    /// The module the island shows. Always one of `enabledModules`.
    @Published var selectedModule: AssistModule {
        didSet {
            if !enabledModules.contains(selectedModule) {
                selectedModule = .clipboard
                return
            }
            defaults.set(selectedModule.rawValue, forKey: Keys.selectedModule)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let enabled = Self.storedModules(defaults: defaults)
        enabledModules = enabled
        let selected = defaults.string(forKey: Keys.selectedModule).flatMap(AssistModule.init(rawValue:))
        selectedModule = selected.flatMap { enabled.contains($0) ? $0 : nil } ?? .clipboard
    }

    func isEnabled(_ module: AssistModule) -> Bool {
        enabledModules.contains(module)
    }

    func setEnabled(_ module: AssistModule, _ isEnabled: Bool) {
        guard !module.isRequired else { return }
        var modules = Set(enabledModules)
        if isEnabled {
            modules.insert(module)
        } else {
            modules.remove(module)
        }
        let ordered = AssistModule.allCases.filter(modules.contains)
        guard ordered != enabledModules else { return }
        enabledModules = ordered

        if !isEnabled, selectedModule == module {
            selectedModule = .clipboard
        }
    }

    /// The module that receives files dropped on the island: the selected one
    /// when it takes files, otherwise the shelf when it is enabled.
    var fileDropTarget: AssistModule? {
        if selectedModule.acceptsFileDrops {
            return selectedModule
        }
        if isEnabled(.shelf) {
            return .shelf
        }
        return enabledModules.first(where: \.acceptsFileDrops)
    }

    private static func storedModules(defaults: UserDefaults) -> [AssistModule] {
        guard let stored = defaults.stringArray(forKey: Keys.enabledModules) else {
            return AssistModule.defaultEnabled
        }
        let modules = Set(stored.compactMap(AssistModule.init(rawValue:)))
            .union(AssistModule.allCases.filter(\.isRequired))
        return AssistModule.allCases.filter(modules.contains)
    }
}

private enum Keys {
    static let enabledModules = "modules.enabled"
    static let selectedModule = "modules.selected"
}
