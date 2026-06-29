import Swinject

final class HealthKitServiceAssembly: Assembly {
    func assemble(container: Container) {
        container.register(HealthKitServiceProtocol.self) { _ in
            HealthKitService()
        }.inObjectScope(.container)
    }
}
