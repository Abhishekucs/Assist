import SwiftUI

private typealias Mono = AssistDesignTokens.Mono
private typealias ModuleTokens = AssistDesignTokens.ModuleIsland

/// The Media module: what Music or Spotify is playing, with previous,
/// play/pause, and next controls for whichever app owns Now Playing.
struct MediaModuleView: View {
    @ObservedObject var service: NowPlayingService

    var body: some View {
        VStack(alignment: .leading, spacing: ModuleTokens.toolbarSpacing) {
            IslandModuleToolbar {
                IslandModuleTitle(title: "Now Playing", detail: service.info?.source.appName)
            } trailing: {
                IslandIconButton(icon: .music, tooltip: "Open \(playerName)", size: Tokens.Control.compactHeight) {
                    service.openPlayer()
                }
            }

            VStack(alignment: .leading, spacing: Tokens.Spacing.xxSmall) {
                Text(service.info?.title ?? "Nothing playing")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.primary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(service.info.map { $0.artist.isEmpty ? "Unknown artist" : $0.artist } ?? "Play a track in Music or Spotify")
                    .font(Tokens.Typography.footnote(.medium))
                    .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.secondary))
                    .lineLimit(1)

                if let album = service.info?.album, !album.isEmpty {
                    Text(album)
                        .font(Tokens.Typography.caption())
                        .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
                        .lineLimit(1)
                }

                Spacer(minLength: Tokens.Spacing.small)

                HStack(spacing: Tokens.Spacing.small) {
                    Text(service.needsAccessibility ? "Allow Accessibility to control playback" : playbackStatus)
                        .font(Tokens.Typography.caption(.medium))
                        .foregroundStyle(Mono.ink.opacity(Tokens.Opacity.muted))
                        .lineLimit(1)

                    Spacer(minLength: Tokens.Spacing.small)

                    if service.needsAccessibility {
                        IslandTextButton(title: "Open Settings") {
                            service.openAccessibilitySettings()
                        }
                    } else if service.info != nil {
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
                    } else {
                        IslandTextButton(title: "Open Music", icon: .music) {
                            service.openPlayer()
                        }
                    }
                }
            }
            .padding(Tokens.Spacing.xLarge)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(IslandTileBackground())
            .frame(height: ModuleTokens.bodyHeight)
        }
    }

    private var isPlaying: Bool {
        service.info?.isPlaying ?? false
    }

    private var playerName: String {
        service.info?.source.appName ?? NowPlayingInfo.Source.music.appName
    }

    private var playbackStatus: String {
        guard service.info != nil else { return "Music or Spotify" }
        return isPlaying ? "Playing" : "Paused"
    }
}
