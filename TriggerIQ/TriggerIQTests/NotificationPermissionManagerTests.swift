import Testing
@testable import TriggerIQ
import UserNotifications

// MARK: - Tests

@MainActor
struct NotificationPermissionManagerTests {
    let mockCenter: MockNotificationCenter
    let manager: NotificationPermissionManager
    
    // MARK: - Setup
    
    init() {
        mockCenter = MockNotificationCenter()
        manager = NotificationPermissionManager(center: mockCenter)
    }
    
    // MARK: - Tests
    
    @Test func requestsAuthorizationWhenNotDetermined() async {
        mockCenter.stubbedStatus = .notDetermined
        
        await manager.requestPermissionIfNeeded()
        
        #expect(mockCenter.requestAuthorizationCalled == true)
    }
    
    @Test func skipsRequestWhenAlreadyAuthorized() async {
        mockCenter.stubbedStatus = .authorized
        
        await manager.requestPermissionIfNeeded()
        
        #expect(mockCenter.requestAuthorizationCalled == false)
    }
    
    @Test func skipsRequestWhenDenied() async {
        mockCenter.stubbedStatus = .denied
        
        await manager.requestPermissionIfNeeded()
        
        #expect(mockCenter.requestAuthorizationCalled == false)
    }
}
