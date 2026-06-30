import Swinject

final class IngredientInflammationAdvisorAssembly: Assembly {
    func assemble(container: Container) {
        container.register(IngredientInflammationAdvisorProtocol.self) { _ in
            IngredientInflammationAdvisor()
        }.inObjectScope(.container)
    }
}
