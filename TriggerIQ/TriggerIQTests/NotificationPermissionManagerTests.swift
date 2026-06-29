import Testing
import UserNotifications
@testable import TriggerIQ

// MARK: - Mock

final class MockNotificationCenter: NotificationCenterProtocol, @unchecked Sendable {
    var stubbedStatus: UNAuthorizationStatus = .notDetermined
    var requestAuthorizationCalled = false
    var requestAuthorizationResult = true

    func notificationSettings() async -> UNNotificationSettings {
        MockNotificationSettings(authorizationStatus: stubbedStatus)
    }

    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        requestAuthorizationCalled = true
        return requestAuthorizationResult
    }
}

// UNNotificationSettings has no public initializer, so we subclass to inject status.
final class MockNotificationSettings: UNNotificationSettings {
    private let _authorizationStatus: UNAuthorizationStatus

    init(authorizationStatus: UNAuthorizationStatus) {
        self._authorizationStatus = authorizationStatus
        super.init()
    }

    required init?(coder: NSCoder) { fatalError() }

    override var authorizationStatus: UNAuthorizationStatus { _authorizationStatus }
}

// MARK: - Tests

@MainActor
struct NotificationPermissionManagerTests {

    @Test func requestsAuthorizationWhenNotDetermined() async {
        let mock = MockNotificationCenter()
        mock.stubbedStatus = .notDetermined
        let manager = NotificationPermissionManager(center: mock)

        await manager.requestPermissionIfNeeded()

        #expect(mock.requestAuthorizationCalled == true)
    }

    @Test func skipsRequestWhenAlreadyAuthorized() async {
        let mock = MockNotificationCenter()
        mock.stubbedStatus = .authorized
        let manager = NotificationPermissionManager(center: mock)

        await manager.requestPermissionIfNeeded()

        #expect(mock.requestAuthorizationCalled == false)
    }

    @Test func skipsRequestWhenDenied() async {
        let mock = MockNotificationCenter()
        mock.stubbedStatus = .denied
        let manager = NotificationPermissionManager(center: mock)

        await manager.requestPermissionIfNeeded()

        #expect(mock.requestAuthorizationCalled == false)
    }
}
