import Foundation

struct LicenseActivation: Codable, Equatable {
    let licenseKey: String
    let licenseKeyInstanceID: String
    let customerEmail: String?
    let activatedAt: Date
    let lastValidatedAt: Date

    func validated(now: Date = Date()) -> LicenseActivation {
        LicenseActivation(
            licenseKey: licenseKey,
            licenseKeyInstanceID: licenseKeyInstanceID,
            customerEmail: customerEmail,
            activatedAt: activatedAt,
            lastValidatedAt: now
        )
    }
}

enum LicenseActivationRequirement {
    static var isRequired: Bool {
        #if DEBUG
        false
        #else
        true
        #endif
    }
}
