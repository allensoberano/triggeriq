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

final class LiveNotificationCenter: NotificationCenterProtocol {
    private let center = UNUserNotificationCenter.current()

    func notificationSettings() async -> NotificationSettingsProtocol {
        await center.notificationSettings()
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await center.requestAuthorization(options: options)
    }

    func add(_ request: UNNotificationRequest) async throws {
        try await center.add(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}

@MainActor
final class NotificationPermissionManager {
    private let center: NotificationCenterProtocol

    init(center: NotificationCenterProtocol = LiveNotificationCenter()) {
        self.center = center
    }

    func requestPermissionIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }
}
