import SwiftData
import Foundation

@testable import TriggerIQ

final class MockHealthKitService: HealthKitServiceProtocol, @unchecked Sendable {
    var requestAuthorizationCalled = false
    var fetchedDates: [Date] = []
    var shouldThrow = false

    func requestAuthorization() async throws {
        requestAuthorizationCalled = true
        if shouldThrow { throw URLError(.notConnectedToInternet) }
    }

    func fetchAndCacheDaily(for date: Date, context: ModelContext) async throws {
        if shouldThrow { throw URLError(.notConnectedToInternet) }
        fetchedDates.append(date)
    }
}
