import Foundation

enum AppIdentity {
    static var name: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Assist"
    }

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "prod.Assist.app"
    }

    static var isDevelopmentBundle: Bool {
        bundleIdentifier == "dev.Assist.app"
    }

    static var supportDirectoryName: String {
        isDevelopmentBundle ? "Assist Dev" : "Assist"
    }

    static var legacySupportDirectoryName: String? {
        isDevelopmentBundle ? nil : "AIClipboard"
    }

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
