import Foundation

enum CodingAgentConfiguration {
    static func claudeHome(
        configuredDirectory: String,
        fileManager: FileManager = .default
    ) -> URL {
        let trimmedDirectory = configuredDirectory
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDirectory.isEmpty else {
            return fileManager.homeDirectoryForCurrentUser
                .appendingPathComponent(".claude", isDirectory: true)
        }

        let expandedDirectory = (trimmedDirectory as NSString).expandingTildeInPath
        if expandedDirectory.hasPrefix("/") {
            return URL(fileURLWithPath: expandedDirectory, isDirectory: true)
                .standardizedFileURL
        }

        return fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(expandedDirectory, isDirectory: true)
            .standardizedFileURL
    }
}
