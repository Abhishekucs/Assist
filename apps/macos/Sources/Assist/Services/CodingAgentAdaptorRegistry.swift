import Foundation

@MainActor
final class CodingAgentAdaptorRegistry {
    private(set) var adaptors: [CodingAgentAdaptor] = []

    func register(_ adaptor: CodingAgentAdaptor) {
        guard !adaptors.contains(where: { $0.provider == adaptor.provider }) else { return }
        adaptors.append(adaptor)
    }

    func unregister(provider: CodingAgentProvider) {
        adaptors.removeAll { $0.provider == provider }
    }

    func adaptor(for provider: CodingAgentProvider) -> CodingAgentAdaptor? {
        adaptors.first { $0.provider == provider }
    }

    func adaptor(forProviderID providerID: String) -> CodingAgentAdaptor? {
        adaptors.first { $0.provider.id == providerID }
    }

    var allProviders: [CodingAgentProvider] {
        adaptors.map(\.provider)
    }
}
