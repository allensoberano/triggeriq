import UserNotifications

protocol NotificationSettingsProtocol {
    var authorizationStatus: UNAuthorizationStatus { get }
}

extension UNNotificationSettings: NotificationSettingsProtocol {}

protocol NotificationCenterProtocol {
    func notificationSettings() async -> NotificationSettingsProtocol
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    func add(_ request: UNNotificationRequest) async throws
    func removePendingNotificationRequests(withIdentifiers: [String])
}

extension UNUserNotificationCenter: NotificationCenterProtocol {
    func notificationSettings() async -> NotificationSettingsProtocol {
        await self.notificationSettings() as UNNotificationSettings
    }
}

@MainActor
final class NotificationPermissionManager {
    private let center: NotificationCenterProtocol

    init(center: NotificationCenterProtocol = UNUserNotificationCenter.current()) {
        self.center = center
    }

    func requestPermissionIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }
}
