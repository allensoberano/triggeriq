import UserNotifications
@testable import TriggerIQ

// MARK: - Mock Notification Settings

struct MockNotificationSettings: NotificationSettingsProtocol {
    let authorizationStatus: UNAuthorizationStatus
}

// MARK: - Mock Notification Center

final class MockNotificationCenter: NotificationCenterProtocol, @unchecked Sendable {
    var stubbedStatus: UNAuthorizationStatus = .notDetermined
    var requestAuthorizationCalled = false
    var requestAuthorizationResult = true

    func notificationSettings() async -> NotificationSettingsProtocol {
        MockNotificationSettings(authorizationStatus: stubbedStatus)
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestAuthorizationCalled = true
        return requestAuthorizationResult
    }
}
