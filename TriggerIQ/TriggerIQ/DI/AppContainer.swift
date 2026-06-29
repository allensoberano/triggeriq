import Swinject
import UserNotifications

final class AppContainer {
    static let shared = AppContainer()
    let container = Container()

    private init() {
        registerServices()
    }

    private func registerServices() {
        container.register(NotificationCenterProtocol.self) { _ in
            UNUserNotificationCenter.current()
        }

        container.register(NotificationPermissionManager.self) { r in
            NotificationPermissionManager(
                center: r.resolve(NotificationCenterProtocol.self)!
            )
        }.inObjectScope(.container)
    }
}
