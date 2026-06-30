import Swinject

final class PhotoStorageAssembly: Assembly {
    func assemble(container: Container) {
        container.register(PhotoStorageServiceProtocol.self) { _ in
            PhotoStorageService()
        }.inObjectScope(.container)
    }
}
