import SwiftUI

private typealias Mono = AssistDesignTokens.Mono
private typealias ModuleTokens = AssistDesignTokens.ModuleIsland

/// The Convert module: drop images on the notch to convert and shrink them.
/// Results are saved beside the originals.
struct ConverterModuleView: View {
    @ObservedObject var service: ImageConversionService
    @ObservedObject var viewModel: PillViewModel

    private static let dropZoneWidth: CGFloat = 196

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleTokens.toolbarSpacing) {
            IslandModuleToolbar {
                HStack(spacing: Tokens.Spacing.xxSmall) {
                    ForEach(ImageConversionFormat.allCases) { format in
                        IslandChip(
                            title: format.title,
                            isSelected: service.options.format == format,
                            accessibilityLabel: "Convert to \(format.title)"
                        ) {
                            service.options.format = format
                        }
                    }
                }
            } trailing: {
                HStack(spacing: Tokens.Spacing.xxSmall) {
                    if service.isConverting {
                        ProgressView()
                            .controlSize(.small)
                            .accessibilityLabel("Converting")
                    }
                    if service.options.format.usesQuality {
                        ForEach(ImageQuality.allCases) { quality in
                            IslandChip(
                                title: quality.title,
                                isSelected: service.options.quality == quality,
                                accessibilityLabel: "\(quality.title) quality",
                                horizontalPadding: Tokens.Spacing.small
                            ) {
                                service.options.quality = quality
                            }
                        }
                    }
                }
            }

            HStack(alignment: .top, spacing: Tokens.Spacing.large) {
                VStack(spacing: Tokens.Spacing.xSmall) {
                    IslandDropZone(
                        icon: .convert,
                        title: "Drop images here",
                        message: "Saved next to the originals.",
                        isTargeted: viewModel.isFileDropTargeted
                    )

                    HStack(spacing: 0) {
                        ForEach(ImageMaxDimension.allCases) { dimension in
                            IslandChip(
                                title: dimension == .original ? "Original" : "\(dimension.rawValue)",
                                isSelected: service.options.maxDimension == dimension,
                                accessibilityLabel: dimension == .original
                                    ? "Keep original size"
                                    : "Longest side \(dimension.rawValue) pixels",
                                horizontalPadding: Tokens.Spacing.xSmall
                            ) {
                                service.options.maxDimension = dimension
                            }
                        }
                    }
                }
                .frame(width: Self.dropZoneWidth)

                results
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(height: ModuleTokens.bodyHeight)
        }
    }

    @ViewBuilder
    private var results: some View {
        if service.results.isEmpty {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xSmall) {
                Text("Convert and shrink")
                    .font(Tokens.Typography.footnote(.semibold))
                    .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
                Text("Pick a format and size, then drop JPEG, PNG, HEIC, TIFF, or other images. Originals are never changed.")
                    .font(Tokens.Typography.caption(.medium))
                    .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Tokens.Spacing.medium)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(IslandTileBackground())
        } else {
            VStack(alignment: .leading, spacing: Tokens.Spacing.xxSmall) {
                HStack {
                    Text("Recent")
                        .font(Tokens.Typography.caption(.semibold))
                        .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
                    Spacer()
                    Button("Clear") {
                        service.clearResults()
                    }
                    .buttonStyle(.plain)
                    .font(Tokens.Typography.caption(.medium))
                    .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.secondary))
                    .pointingHandCursor()
                    .help("Clear this list. Converted files stay where they are.")
                }

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: Tokens.Spacing.xxSmall) {
                        ForEach(service.results) { result in
                            ConversionResultRow(result: result) {
                                service.reveal(result)
                            }
                        }
                    }
                }
            }
            .padding(Tokens.Spacing.medium)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(IslandTileBackground())
        }
    }
}

private struct ConversionResultRow: View {
    let result: ImageConversionResult
    let reveal: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: reveal) {
            HStack(spacing: Tokens.Spacing.small) {
                HugeIcon(
                    result.errorMessage == nil ? .file : .info,
                    size: Tokens.Icon.regular,
                    color: Mono.ink.opacity(Tokens.Opacity.secondary)
                )

                VStack(alignment: .leading, spacing: 0) {
                    Text(result.outputURL?.lastPathComponent ?? result.sourceName)
                        .font(Tokens.Typography.footnote(.medium))
                        .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Text(detail)
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(
                            result.errorMessage == nil
                                ? Mono.ink.opacity(Tokens.Opacity.muted)
                                : AssistDesignTokens.Palette.warning
                        )
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if result.outputURL != nil {
                    HugeIcon(.folder, size: Tokens.Icon.small, color: Mono.ink.opacity(isHovered ? Tokens.Opacity.primary : Tokens.Opacity.subtle))
                }
            }
            .padding(.vertical, Tokens.Spacing.xxxSmall)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(result.outputURL == nil)
        .pointingHandCursor(isEnabled: result.outputURL != nil)
        .help(result.outputURL == nil ? detail : "Show in Finder")
        .onHover { isHovered = $0 }
    }

    private var detail: String {
        if let errorMessage = result.errorMessage {
            return "\(result.sourceName): \(errorMessage)"
        }
        guard let original = result.originalBytes, let output = result.outputBytes else {
            return "Converted"
        }
        let change = original > 0 ? Double(output - original) / Double(original) : 0
        let changeText = change < 0 ? " (\(StatsFormatting.percent(-change)) smaller)" : ""
        return "\(StatsFormatting.fileBytes(original)) → \(StatsFormatting.fileBytes(output))\(changeText)"
    }
}
