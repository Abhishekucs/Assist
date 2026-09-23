import SwiftUI

private typealias ModuleTokens = AssistDesignTokens.ModuleIsland

/// The expanded island: module tabs split around the notch, the pin and
/// Open Assist actions, and the selected module below.
struct ModuleIslandView: View {
    @ObservedObject var viewModel: PillViewModel
    @ObservedObject var moduleSettings: ModuleSettings
    let modules: ModuleServices
    let islandWidth: CGFloat
    let onDragChanged: (Bool) -> Void

    var body: some View {
        let enabled = moduleSettings.enabledModules
        let layout = ModuleTabLayout(tabCount: enabled.count, preferredIslandWidth: islandWidth)

        VStack(alignment: .leading, spacing: Tokens.Spacing.medium) {
            HStack(spacing: 0) {
                tabs(Array(enabled.prefix(layout.leadingCount)))

                Spacer(minLength: ModuleTabLayout.notchClearance)

                HStack(spacing: ModuleTabLayout.groupSpacing) {
                    if layout.trailingCount > 0 {
                        tabs(Array(enabled.suffix(layout.trailingCount)))
                    }

                    HStack(spacing: ModuleTabLayout.tabSpacing) {
                        IslandToggleIconButton(
                            icon: .pin,
                            tooltip: viewModel.isIslandPinned ? "Unpin island" : "Keep island open",
                            isOn: viewModel.isIslandPinned
                        ) {
                            viewModel.toggleIslandPinned()
                        }

                        IslandIconButton(
                            icon: .grid,
                            tooltip: "Open Assist",
                            size: ModuleTabLayout.tabWidth
                        ) {
                            viewModel.openControls()
                        }
                    }
                }
            }
            .frame(height: ModuleTokens.tabRowHeight)
            .zIndex(1)

            moduleContent(moduleSettings.selectedModule)
                .frame(maxWidth: .infinity)
                .frame(height: ModuleTokens.contentHeight, alignment: .top)
                .id(moduleSettings.selectedModule)
        }
        .padding(.horizontal, ModuleTabLayout.sideInset)
        .padding(.top, Tokens.Spacing.xSmall)
        .padding(.bottom, Tokens.Spacing.xLarge)
        .foregroundStyle(AssistDesignTokens.Mono.ink)
    }

    private func tabs(_ tabModules: [AssistModule]) -> some View {
        HStack(spacing: ModuleTabLayout.tabSpacing) {
            ForEach(tabModules) { module in
                IslandToggleIconButton(
                    icon: module.icon,
                    tooltip: module.title,
                    isOn: module == moduleSettings.selectedModule
                ) {
                    moduleSettings.selectedModule = module
                }
            }
        }
    }

    @ViewBuilder
    private func moduleContent(_ module: AssistModule) -> some View {
        switch module {
        case .clipboard:
            ClipboardModuleView(viewModel: viewModel, onDragChanged: onDragChanged)
        case .shelf:
            ShelfModuleView(store: modules.shelf, viewModel: viewModel, onDragChanged: onDragChanged)
        case .notes:
            NotesModuleView(store: modules.notes, viewModel: viewModel)
        case .timers:
            TimersModuleView(timers: modules.timers)
        case .calendar:
            CalendarModuleView(service: modules.calendar)
        case .media:
            MediaModuleView(service: modules.media)
        case .stats:
            StatsModuleView(service: modules.stats)
        case .screenTime:
            ScreenTimeModuleView(tracker: modules.screenTime)
        case .converter:
            ConverterModuleView(service: modules.converter, viewModel: viewModel)
        }
    }
}
