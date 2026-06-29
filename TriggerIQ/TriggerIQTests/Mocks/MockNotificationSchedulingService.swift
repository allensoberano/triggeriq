import Foundation
@testable import TriggerIQ

@MainActor
final class MockNotificationSchedulingService: NotificationSchedulingServiceProtocol {
    var scheduleCheckInsCalled = false
    var cancelCheckInsCalled = false
    var scheduleMorningSummaryCalled = false
    var lastMeal: Meal?

    func scheduleCheckIns(for meal: Meal) async {
        scheduleCheckInsCalled = true
        lastMeal = meal
    }

    func scheduleNextMorningSummary() async {
        scheduleMorningSummaryCalled = true
    }

    func cancelCheckIns(for meal: Meal) async {
        cancelCheckInsCalled = true
        lastMeal = meal
    }
}
