import Swinject

final class PatternEngineAssembly: Assembly {
    func assemble(container: Container) {
        container.register(PatternEngineProtocol.self) { _ in
            PatternEngine()
        }.inObjectScope(.container)
    }
}
