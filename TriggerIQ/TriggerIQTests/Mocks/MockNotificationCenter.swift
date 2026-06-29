import UserNotifications
@testable import TriggerIQ

struct MockNotificationSettings: NotificationSettingsProtocol {
    let authorizationStatus: UNAuthorizationStatus
}

final class MockNotificationCenter: NotificationCenterProtocol, @unchecked Sendable {
    var stubbedStatus: UNAuthorizationStatus = .notDetermined
    var requestAuthorizationCalled = false
    var requestAuthorizationResult = true
    var addedRequests: [UNNotificationRequest] = []
    var removedIdentifiers: [String] = []

    func notificationSettings() async -> NotificationSettingsProtocol {
        MockNotificationSettings(authorizationStatus: stubbedStatus)
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestAuthorizationCalled = true
        return requestAuthorizationResult
    }

    func add(_ request: UNNotificationRequest) async throws {
        addedRequests.append(request)
    }

    func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
        removedIdentifiers.append(contentsOf: identifiers)
    }
}
