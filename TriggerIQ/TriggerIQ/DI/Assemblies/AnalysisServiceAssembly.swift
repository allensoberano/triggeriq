import Swinject

final class AnalysisServiceAssembly: Assembly {
    func assemble(container: Container) {
        container.register(AnalysisServiceProtocol.self) { _ in
            StubAnalysisService()
        }.inObjectScope(.container)
    }
}
