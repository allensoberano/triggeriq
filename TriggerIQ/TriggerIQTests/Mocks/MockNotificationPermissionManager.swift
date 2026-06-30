import Foundation
@testable import TriggerIQ

final class MockNotificationPermissionManager: NotificationPermissionManagerProtocol {
    var requestPermissionCalled = false

    func requestPermissionIfNeeded() async {
        requestPermissionCalled = true
    }
}
