import AppKit
import Foundation

struct AppUpdateRelease: Equatable {
    let version: String
    let tagName: String
    let assetName: String
    let downloadURL: URL
}

enum AppUpdateOutcome: Equatable {
    case upToDate(version: String)
    case installStarted(version: String)
}

enum AppUpdateError: LocalizedError {
    case releaseRequestFailed(Int)
    case noCompatibleRelease
    case currentAppLocationUnavailable
    case helperLaunchFailed

    var errorDescription: String? {
        switch self {
        case let .releaseRequestFailed(statusCode):
            "Update check failed with HTTP \(statusCode)."
        case .noCompatibleRelease:
            "No compatible macOS update was found."
        case .currentAppLocationUnavailable:
            "Assist could not find its installed app bundle."
        case .helperLaunchFailed:
            "Assist could not start the update installer."
        }
    }
}

@MainActor
final class AppUpdateService {
    private static let expectedReleaseBundleIdentifier = "com.thinkingsoundlab.assist"
    private static let expectedReleaseTeamIdentifier = "4M5LV534N5"

    private let session: URLSession
    private let fileManager: FileManager

    init(session: URLSession = .shared, fileManager: FileManager = .default) {
        self.session = session
        self.fileManager = fileManager
    }

    func checkAndInstallIfAvailable() async throws -> AppUpdateOutcome {
        let currentVersion = Self.currentVersion
        let release = try await latestCompatibleRelease()

        guard Self.isVersion(release.version, newerThan: currentVersion) else {
            return .upToDate(version: currentVersion)
        }

        let dmgURL = try await downloadUpdate(release)
        try await startInstaller(for: dmgURL)
        return .installStarted(version: release.version)
    }

    private func latestCompatibleRelease() async throws -> AppUpdateRelease {
        var request = URLRequest(url: AppIdentity.releasesAPIURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Assist/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        if let httpResponse = response as? HTTPURLResponse,
           !(200..<300).contains(httpResponse.statusCode) {
            throw AppUpdateError.releaseRequestFailed(httpResponse.statusCode)
        }

        let releases = try JSONDecoder().decode([GitHubRelease].self, from: data)
        guard let release = releases.compactMap(Self.compatibleRelease(from:)).first else {
            throw AppUpdateError.noCompatibleRelease
        }

        return release
    }

    private func downloadUpdate(_ release: AppUpdateRelease) async throws -> URL {
        let updateDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("AssistUpdate-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: updateDirectory, withIntermediateDirectories: true)

        let targetURL = updateDirectory.appendingPathComponent(release.assetName)
        let (downloadedURL, _) = try await session.download(from: release.downloadURL)
        if fileManager.fileExists(atPath: targetURL.path) {
            try fileManager.removeItem(at: targetURL)
        }
        try fileManager.moveItem(at: downloadedURL, to: targetURL)
        return targetURL
    }

    private func startInstaller(for dmgURL: URL) async throws {
        guard let currentAppURL = Bundle.main.bundleURL.nearestAppBundle else {
            throw AppUpdateError.currentAppLocationUnavailable
        }

        let helperURL = dmgURL
            .deletingLastPathComponent()
            .appendingPathComponent("install-assist-update.sh")
        try installerScript.write(to: helperURL, atomically: true, encoding: .utf8)
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helperURL.path)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = [
            helperURL.path,
            "\(ProcessInfo.processInfo.processIdentifier)",
            dmgURL.path,
            currentAppURL.path
        ]

        try process.run()
        if !process.isRunning {
            throw AppUpdateError.helperLaunchFailed
        }

        await MainActor.run {
            NSApp.terminate(nil)
        }
    }

    private var installerScript: String {
        """
        #!/bin/zsh
        set -euo pipefail

        APP_PID="$1"
        DMG_PATH="$2"
        CURRENT_APP_PATH="$3"
        MOUNT_DIR="$(mktemp -d /tmp/assist-update-mount.XXXXXX)"
        CLEANUP_DIR="$(dirname "$DMG_PATH")"
        ATTACHED=0

        cleanup() {
          if [[ "$ATTACHED" == "1" ]]; then
            /usr/bin/hdiutil detach "$MOUNT_DIR" -quiet >/dev/null 2>&1 || /usr/bin/hdiutil detach "$MOUNT_DIR" -force -quiet >/dev/null 2>&1 || true
          fi
          /bin/rm -rf "$MOUNT_DIR" "$CLEANUP_DIR"
        }
        trap cleanup EXIT

        while /bin/kill -0 "$APP_PID" >/dev/null 2>&1; do
          /bin/sleep 0.2
        done

        /usr/bin/hdiutil attach "$DMG_PATH" -nobrowse -quiet -mountpoint "$MOUNT_DIR"
        ATTACHED=1

        SOURCE_APP="$(/usr/bin/find "$MOUNT_DIR" -maxdepth 1 -name "*.app" -print -quit)"
        if [[ -z "$SOURCE_APP" ]]; then
          exit 1
        fi

        SOURCE_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SOURCE_APP/Contents/Info.plist" 2>/dev/null || true)"
        if [[ "$SOURCE_BUNDLE_ID" != "\(Self.expectedReleaseBundleIdentifier)" ]]; then
          echo "Unexpected update bundle identifier: $SOURCE_BUNDLE_ID" >&2
          exit 1
        fi

        /usr/bin/codesign --verify --deep --strict --verbose=2 "$SOURCE_APP"

        SOURCE_TEAM_ID="$(/usr/bin/codesign -dv --verbose=4 "$SOURCE_APP" 2>&1 | /usr/bin/awk -F= '/^TeamIdentifier=/{print $2; exit}')"
        if [[ "$SOURCE_TEAM_ID" != "\(Self.expectedReleaseTeamIdentifier)" ]]; then
          echo "Unexpected update team identifier: $SOURCE_TEAM_ID" >&2
          exit 1
        fi

        /usr/sbin/spctl --assess --type execute --verbose=2 "$SOURCE_APP"

        TARGET_APP="$CURRENT_APP_PATH"
        if [[ "$(basename "$CURRENT_APP_PATH")" == "Assist Dev.app" ]]; then
          TARGET_APP="/Applications/$(basename "$SOURCE_APP")"
        fi

        TARGET_PARENT="$(dirname "$TARGET_APP")"
        TEMP_TARGET="$TARGET_PARENT/.$(basename "$TARGET_APP").updating"
        /bin/mkdir -p "$TARGET_PARENT"
        /bin/rm -rf "$TEMP_TARGET"
        /usr/bin/ditto "$SOURCE_APP" "$TEMP_TARGET"
        /usr/bin/xattr -dr com.apple.quarantine "$TEMP_TARGET" >/dev/null 2>&1 || true
        /bin/rm -rf "$TARGET_APP"
        /bin/mv "$TEMP_TARGET" "$TARGET_APP"
        /usr/bin/open "$TARGET_APP"
        """
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let draft: Bool
    let prerelease: Bool
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case draft
        case prerelease
        case assets
    }
}

private struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadURL: URL

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

private extension AppUpdateService {
    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0.0"
    }

    static func compatibleRelease(from release: GitHubRelease) -> AppUpdateRelease? {
        guard !release.draft, !release.prerelease,
              let version = normalizedVersion(from: release.tagName),
              let asset = release.assets.first(where: isCompatibleAsset) else {
            return nil
        }

        return AppUpdateRelease(
            version: version,
            tagName: release.tagName,
            assetName: asset.name,
            downloadURL: asset.browserDownloadURL
        )
    }

    static func isCompatibleAsset(_ asset: GitHubAsset) -> Bool {
        let lowercasedName = asset.name.lowercased()
        return lowercasedName.hasSuffix(".dmg") && lowercasedName.contains("assist")
    }

    static func normalizedVersion(from tagName: String) -> String? {
        let lowercasedTag = tagName.lowercased()
        guard let firstDigitIndex = lowercasedTag.firstIndex(where: { $0.isNumber }) else {
            return nil
        }

        let suffix = lowercasedTag[firstDigitIndex...]
        let versionCharacters = suffix.prefix { character in
            character.isNumber || character == "."
        }
        let version = String(versionCharacters)
        return version.isEmpty ? nil : version
    }

    static func isVersion(_ version: String, newerThan currentVersion: String) -> Bool {
        let proposedParts = numericVersionParts(version)
        let currentParts = numericVersionParts(currentVersion)
        let maxCount = max(proposedParts.count, currentParts.count)

        for index in 0..<maxCount {
            let proposedPart = index < proposedParts.count ? proposedParts[index] : 0
            let currentPart = index < currentParts.count ? currentParts[index] : 0

            if proposedPart > currentPart {
                return true
            }
            if proposedPart < currentPart {
                return false
            }
        }

        return false
    }

    static func numericVersionParts(_ version: String) -> [Int] {
        version
            .split(separator: ".")
            .map { Int($0) ?? 0 }
    }
}

private extension URL {
    var nearestAppBundle: URL? {
        var currentURL = self
        while currentURL.path != "/" {
            if currentURL.pathExtension == "app" {
                return currentURL
            }
            currentURL.deleteLastPathComponent()
        }

        return nil
    }
}
