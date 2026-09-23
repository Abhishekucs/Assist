import Foundation

/// What Music or Spotify is playing, as announced in their public
/// distributed notifications. Reading these needs no permission.
struct NowPlayingInfo: Equatable, Sendable {
    enum Source: String, CaseIterable, Sendable {
        case music
        case spotify

        var appName: String {
            switch self {
            case .music: "Music"
            case .spotify: "Spotify"
            }
        }

        var bundleIdentifier: String {
            switch self {
            case .music: "com.apple.Music"
            case .spotify: "com.spotify.client"
            }
        }

        var notificationName: Notification.Name {
            switch self {
            case .music: Notification.Name("com.apple.Music.playerInfo")
            case .spotify: Notification.Name("com.spotify.client.PlaybackStateChanged")
            }
        }
    }

    let source: Source
    let title: String
    let artist: String
    let album: String
    let isPlaying: Bool

    /// Reads a player notification's `userInfo`. A stopped player, or one
    /// with no track, yields nil so the module shows its idle state.
    init?(source: Source, userInfo: [AnyHashable: Any]) {
        guard let state = userInfo["Player State"] as? String, state != "Stopped" else { return nil }
        let title = (userInfo["Name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !title.isEmpty else { return nil }

        self.source = source
        self.title = title
        artist = (userInfo["Artist"] as? String) ?? ""
        album = (userInfo["Album"] as? String) ?? ""
        isPlaying = state == "Playing"
    }
}

/// The hardware media keys, which the system routes to whichever app owns
/// Now Playing (Music, Spotify, a browser, Podcasts, and so on).
enum MediaKey: Int, Sendable {
    // NX_KEYTYPE_PLAY, NX_KEYTYPE_NEXT, and NX_KEYTYPE_PREVIOUS from IOKit's ev_keymap.h.
    case playPause = 16
    case next = 17
    case previous = 18
}
