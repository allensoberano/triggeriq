import Swinject

final class AppContainer {
    static let shared = AppContainer()

    private let assembler: Assembler

    var resolver: Resolver { assembler.resolver }

    private init() {
        assembler = Assembler([
            NotificationServiceAssembly(),
        ])
    }
}

func resolve<T>(_ type: T.Type = T.self) -> T {
    AppContainer.shared.resolver.resolve(T.self)!
}
