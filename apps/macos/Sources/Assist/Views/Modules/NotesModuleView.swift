import SwiftUI

private typealias Mono = AssistDesignTokens.Mono
private typealias ModuleTokens = AssistDesignTokens.ModuleIsland

/// The Notes module: one scratchpad, saved as you type. While it has focus,
/// the island stays open until you click elsewhere.
struct NotesModuleView: View {
    @ObservedObject var store: ScratchpadStore
    @ObservedObject var viewModel: PillViewModel
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleTokens.toolbarSpacing) {
            IslandModuleToolbar {
                IslandModuleTitle(title: "Notes", detail: wordCountText)
            } trailing: {
                IslandIconButton(
                    icon: .copy,
                    tooltip: "Copy notes",
                    isEnabled: !store.isEmpty,
                    size: Tokens.Control.compactHeight
                ) {
                    if store.copyToPasteboard() {
                        viewModel.showCopyFeedback(badge: "Copied", preview: "Notes")
                    }
                }
            }

            ZStack(alignment: .topLeading) {
                TextEditor(text: $store.text)
                    .font(Tokens.Typography.label())
                    .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
                    .scrollContentBackground(.hidden)
                    .scrollIndicators(.never)
                    .focused($isFocused)
                    .padding(.horizontal, Tokens.Spacing.small)
                    .padding(.vertical, Tokens.Spacing.small)
                    .accessibilityLabel("Notes")

                if store.text.isEmpty {
                    Text("Jot something down. Notes stay on this Mac.")
                        .font(Tokens.Typography.label())
                        .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.subtle))
                        .padding(.horizontal, Tokens.Spacing.medium + 3)
                        .padding(.vertical, Tokens.Spacing.small)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
            .frame(height: ModuleTokens.bodyHeight)
            .background(IslandTileBackground())
        }
        .onChange(of: isFocused) { _, focused in
            viewModel.isEditingText = focused
        }
        .onChange(of: viewModel.isEditingText) { _, editing in
            // The island clears editing when its panel loses key focus.
            if !editing, isFocused {
                isFocused = false
            }
        }
        .onDisappear {
            viewModel.isEditingText = false
        }
    }

    private var wordCountText: String? {
        switch store.wordCount {
        case 0: nil
        case 1: "1 word"
        default: "\(store.wordCount) words"
        }
    }
}
