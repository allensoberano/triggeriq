import Swinject

final class AnalysisServiceAssembly: Assembly {
    func assemble(container: Container) {
        container.register(AnalysisServiceProtocol.self) { _ in
            // Resolve API key: Keychain first, then dev Secrets.plist, then stub
            if let key = APIKeyStore.load() ?? APIKeyStore.loadFromPlist() {
                let client = AnthropicClient(apiKey: key)
                return LiveAnalysisService(client: client)
            }
            return StubAnalysisService()
        }.inObjectScope(.container)
    }
}
