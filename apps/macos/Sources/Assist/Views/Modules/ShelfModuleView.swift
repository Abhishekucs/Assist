import AppKit
import SwiftUI

private typealias Mono = AssistDesignTokens.Mono
private typealias ModuleTokens = AssistDesignTokens.ModuleIsland

/// The Shelf module: files dropped on the notch, ready to drag out anywhere.
struct ShelfModuleView: View {
    @ObservedObject var store: ShelfStore
    @ObservedObject var viewModel: PillViewModel
    let onDragChanged: (Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleTokens.toolbarSpacing) {
            IslandModuleToolbar {
                IslandModuleTitle(title: "Shelf", detail: countText)
            } trailing: {
                if !store.items.isEmpty {
                    IslandTextButton(title: "Clear shelf") {
                        store.removeAll()
                    }
                    .help("Remove every file from the shelf. The files themselves stay where they are.")
                }
            }

            Group {
                if store.items.isEmpty {
                    IslandDropZone(
                        icon: .drop,
                        title: "Drop files here",
                        message: "Keep files one hover away, then drag them into any app. Nothing is copied or moved.",
                        isTargeted: viewModel.isFileDropTargeted
                    )
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: Tokens.Spacing.small) {
                            ForEach(store.items) { item in
                                ShelfTile(
                                    item: item,
                                    icon: store.icon(for: item),
                                    onDragChanged: onDragChanged,
                                    open: { store.open(item) },
                                    reveal: { store.reveal(item) },
                                    remove: { store.remove(item) }
                                )
                            }
                        }
                    }
                    .overlay {
                        if viewModel.isFileDropTargeted {
                            RoundedRectangle(cornerRadius: ModuleTokens.tileRadius, style: .continuous)
                                .strokeBorder(
                                    Mono.dropTargetOutline,
                                    style: StrokeStyle(
                                        lineWidth: ModuleTokens.dropOutlineWidth,
                                        dash: ModuleTokens.dropOutlineDash
                                    )
                                )
                                .allowsHitTesting(false)
                        }
                    }
                }
            }
            .frame(height: ModuleTokens.bodyHeight)
        }
        .onAppear {
            store.refresh()
        }
    }

    private var countText: String? {
        switch store.items.count {
        case 0: nil
        case 1: "1 file"
        default: "\(store.items.count) files"
        }
    }
}

private struct ShelfTile: View {
    let item: ShelfItem
    let icon: NSImage
    let onDragChanged: (Bool) -> Void
    let open: () -> Void
    let reveal: () -> Void
    let remove: () -> Void

    @State private var isHovered = false
    @State private var isActionHovered = false

    private var showsActions: Bool {
        isHovered || isActionHovered
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            IslandDraggableCard(
                pasteboardWriter: { item.url as NSURL },
                dragImage: { dragImage },
                onClick: open,
                onDragChanged: onDragChanged
            ) {
                VStack(spacing: Tokens.Spacing.small) {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 56, height: 56)
                        .grayscale(1)
                        .padding(.top, Tokens.Spacing.xLarge)

                    Text(item.displayName)
                        .font(Tokens.Typography.caption(.medium))
                        .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .truncationMode(.middle)
                        .padding(.horizontal, Tokens.Spacing.small)

                    Spacer(minLength: 0)
                }
                .frame(width: ModuleTokens.shelfTileWidth, height: ModuleTokens.bodyHeight)
                .background(
                    RoundedRectangle(cornerRadius: ModuleTokens.tileRadius, style: .continuous)
                        .fill(isHovered ? Mono.hoverSurface : Mono.surface)
                )
            }
            .help("Click to open \(item.displayName), or drag it into another app")
            .accessibilityLabel(item.displayName)
            .accessibilityAddTraits(.isButton)

            HStack(spacing: 0) {
                ShelfTileAction(icon: .folder, tooltip: "Show in Finder", isHovered: $isActionHovered, action: reveal)
                ShelfTileAction(icon: .close, tooltip: "Remove from shelf", isHovered: $isActionHovered, action: remove)
            }
            .padding(AssistDesignTokens.Spacing.xxxSmall)
            .background(Mono.selectedFill, in: Capsule())
            .padding(AssistDesignTokens.Spacing.xxSmall)
            .opacity(showsActions ? 1 : 0)
            .allowsHitTesting(showsActions)
            .accessibilityHidden(!showsActions)
        }
        .frame(width: ModuleTokens.shelfTileWidth, height: ModuleTokens.bodyHeight)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .animation(Tokens.Motion.quick, value: showsActions)
    }

    private var dragImage: NSImage? {
        guard let copy = icon.copy() as? NSImage else { return nil }
        copy.size = NSSize(width: 64, height: 64)
        return copy
    }
}

private struct ShelfTileAction: View {
    let icon: HugeIconKind
    let tooltip: String
    @Binding var isHovered: Bool
    let action: () -> Void

    @State private var isSelfHovered = false

    var body: some View {
        Button(action: action) {
            HugeIcon(
                icon,
                size: Tokens.Icon.small,
                color: Mono.selectedForeground.opacity(isSelfHovered ? 1 : Tokens.Opacity.strong)
            )
            .frame(width: AssistDesignTokens.HistoryShelf.actionControl, height: AssistDesignTokens.HistoryShelf.actionControl)
            .background(
                isSelfHovered ? AssistDesignTokens.Palette.softPaper : .clear,
                in: RoundedRectangle(cornerRadius: Tokens.Radius.control, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .accessibilityLabel(tooltip)
        .onHover { hovering in
            isSelfHovered = hovering
            isHovered = hovering
        }
    }
}
