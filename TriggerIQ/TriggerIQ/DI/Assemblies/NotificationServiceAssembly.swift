import Swinject
import UserNotifications

final class NotificationServiceAssembly: Assembly {
    func assemble(container: Container) {
        container.register(NotificationCenterProtocol.self) { _ in
            UNUserNotificationCenter.current()
        }

        container.register(NotificationPermissionManager.self) { r in
            NotificationPermissionManager(
                center: r.resolve(NotificationCenterProtocol.self)!
            )
        }.inObjectScope(.container)

        container.register(NotificationSchedulingServiceProtocol.self) { r in
            NotificationSchedulingService(
                center: r.resolve(NotificationCenterProtocol.self)!
            )
        }.inObjectScope(.container)
    }
}
