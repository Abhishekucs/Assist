import Foundation

enum LicenseValidationError: LocalizedError {
    case invalidResponse
    case inactive(String)
    case server(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The license server returned an unreadable response."
        case let .inactive(message):
            message
        case let .server(message):
            message
        }
    }
}

@MainActor
final class LicenseValidationService {
    private let endpointURL: URL
    private let session: URLSession
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        endpointURL: URL = AppIdentity.licenseVerificationURL,
        session: URLSession = .shared
    ) {
        self.endpointURL = endpointURL
        self.session = session
    }

    func activate(licenseKey: String) async throws -> LicenseActivation {
        let response = try await verify(
            licenseKey: licenseKey,
            licenseKeyInstanceID: nil
        )

        guard response.valid, let instanceID = response.licenseKeyInstanceID else {
            throw LicenseValidationError.inactive(response.error ?? "License key is not active.")
        }

        let now = Date()

        return LicenseActivation(
            licenseKey: normalizedLicenseKey(licenseKey),
            licenseKeyInstanceID: instanceID,
            customerEmail: response.customerEmail,
            activatedAt: now,
            lastValidatedAt: now
        )
    }

    func validate(_ activation: LicenseActivation) async throws -> LicenseActivation {
        let response = try await verify(
            licenseKey: activation.licenseKey,
            licenseKeyInstanceID: activation.licenseKeyInstanceID
        )

        guard response.valid else {
            throw LicenseValidationError.inactive(response.error ?? "License key is not active on this Mac.")
        }

        return activation.validated()
    }

    private func verify(
        licenseKey: String,
        licenseKeyInstanceID: String?
    ) async throws -> LicenseVerificationResponse {
        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 18
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(
            LicenseVerificationRequest(
                licenseKey: normalizedLicenseKey(licenseKey),
                licenseKeyInstanceID: licenseKeyInstanceID,
                deviceName: Host.current().localizedName ?? "Mac",
                appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            )
        )

        let (data, response) = try await session.data(for: request)
        let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        let verification = try? decoder.decode(LicenseVerificationResponse.self, from: data)

        if (200..<300).contains(statusCode), let verification {
            return verification
        }

        if let verification, let error = verification.error {
            throw LicenseValidationError.server(error)
        }

        throw LicenseValidationError.invalidResponse
    }

    private func normalizedLicenseKey(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
            .uppercased()
    }
}

private struct LicenseVerificationRequest: Encodable {
    let licenseKey: String
    let licenseKeyInstanceID: String?
    let deviceName: String
    let appVersion: String?

    enum CodingKeys: String, CodingKey {
        case licenseKey = "license_key"
        case licenseKeyInstanceID = "license_key_instance_id"
        case deviceName = "device_name"
        case appVersion = "app_version"
    }
}

private struct LicenseVerificationResponse: Decodable {
    let valid: Bool
    let licenseKeyInstanceID: String?
    let customerEmail: String?
    let error: String?

    enum CodingKeys: String, CodingKey {
        case valid
        case licenseKeyInstanceID = "license_key_instance_id"
        case customerEmail = "customer_email"
        case error
    }
}
