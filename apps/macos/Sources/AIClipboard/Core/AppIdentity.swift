import Foundation

enum AppIdentity {
    static let name = "Assist"
    static let bundleIdentifier = "dev.assist.app"
    static let supportDirectoryName = "Assist"
    static let legacySupportDirectoryName = "AIClipboard"
    static let repositoryURL = URL(string: "https://github.com/Abhishekucs/Assist")!
    static let releasesURL = URL(string: "https://github.com/Abhishekucs/Assist/releases")!
    static let supportEmail = "abhishek@thinkingsoundlab.com"
    static let privacyPolicyURL = URL(string: "https://assist.thinkingsoundlab.com/privacy")!
    static var licenseVerificationURL: URL {
        if let urlString = Bundle.main.object(forInfoDictionaryKey: "AssistLicenseVerificationURL") as? String,
           let url = URL(string: urlString) {
            return url
        }

        return URL(string: "https://assist-woad.vercel.app/api/license/verify")!
    }
}
