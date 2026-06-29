import Testing
import Foundation
@testable import TriggerIQ

struct NotificationDelegateTests {
    private let delegate = NotificationDelegate.shared

    @Test func parsesOneHourIdentifier() {
        let id = "checkin-\(UUID().uuidString)-oneHour"
        #expect(delegate.checkInDestination(from: id)?.checkInType == .oneHour)
    }

    @Test func parsesFourHourIdentifier() {
        let id = "checkin-\(UUID().uuidString)-fourHour"
        #expect(delegate.checkInDestination(from: id)?.checkInType == .fourHour)
    }

    @Test func parsesNextMorningSummaryIdentifier() {
        let result = delegate.checkInDestination(from: "next-morning-summary")
        #expect(result?.checkInType == .nextMorning)
        #expect(result?.mealID == nil)
    }

    @Test func returnsNilForUnknownIdentifier() {
        #expect(delegate.checkInDestination(from: "some-random-identifier") == nil)
    }

    @Test func returnsNilForEmptyIdentifier() {
        #expect(delegate.checkInDestination(from: "") == nil)
    }
}
