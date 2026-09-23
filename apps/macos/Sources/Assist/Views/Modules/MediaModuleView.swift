import SwiftUI

private typealias Mono = AssistDesignTokens.Mono
private typealias ModuleTokens = AssistDesignTokens.ModuleIsland

/// The Media module: what Music or Spotify is playing, with previous,
/// play/pause, and next controls for whichever app owns Now Playing.
struct MediaModuleView: View {
    @ObservedObject var service: NowPlayingService

    private static let artworkSize: CGFloat = 104

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleTokens.toolbarSpacing) {
            IslandModuleToolbar {
                IslandModuleTitle(title: "Now Playing", detail: service.info?.source.appName)
            } trailing: {
                IslandIconButton(icon: .music, tooltip: "Open \(playerName)", size: Tokens.Control.compactHeight) {
                    service.openPlayer()
                }
            }

            HStack(alignment: .center, spacing: Tokens.Spacing.xLarge) {
                ZStack {
                    IslandTileBackground()
                    HugeIcon(.music, size: 34, color: Mono.ink.opacity(Tokens.Opacity.subtle))
                }
                .frame(width: Self.artworkSize, height: Self.artworkSize)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: Tokens.Spacing.xxSmall) {
                    Text(service.info?.title ?? "Nothing playing")
                        .font(Tokens.Typography.headline)
                        .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
                        .lineLimit(2)

                    Text(subtitle)
                        .font(Tokens.Typography.footnote(.medium))
                        .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
                        .lineLimit(service.needsAccessibility ? 1 : 2)

                    Spacer(minLength: Tokens.Spacing.small)

                    HStack(spacing: Tokens.Spacing.small) {
                        IslandIconButton(icon: .previous, tooltip: "Previous track") {
                            service.send(.previous)
                        }
                        IslandTextButton(
                            title: isPlaying ? "Pause" : "Play",
                            icon: isPlaying ? .pause : .play,
                            isProminent: true
                        ) {
                            service.send(.playPause)
                        }
                        IslandIconButton(icon: .next, tooltip: "Next track") {
                            service.send(.next)
                        }
                    }

                    if service.needsAccessibility {
                        HStack(spacing: Tokens.Spacing.small) {
                            Text("Allow Accessibility to control playback.")
                                .font(Tokens.Typography.caption(.medium))
                                .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.secondary))
                                .lineLimit(1)
                            IslandTextButton(title: "Open Settings") {
                                service.openAccessibilitySettings()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(height: ModuleTokens.bodyHeight)
        }
    }

    private var isPlaying: Bool {
        service.info?.isPlaying ?? false
    }

    private var playerName: String {
        service.info?.source.appName ?? NowPlayingInfo.Source.music.appName
    }

    private var subtitle: String {
        guard let info = service.info else {
            return "Play something in Music or Spotify. The controls also reach other players."
        }
        return [info.artist, info.album]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }
}
