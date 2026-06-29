import Testing
import SwiftData
@testable import TriggerIQ

@MainActor
struct NotificationSchedulingServiceTests {
    let mock: MockNotificationCenter
    let service: NotificationSchedulingService

    init() {
        mock = MockNotificationCenter()
        service = NotificationSchedulingService(center: mock)
    }

    private func makeMeal(minutesAgo: Double = 0) -> Meal {
        let meal = Meal(
            timestamp: Date().addingTimeInterval(-minutesAgo * 60),
            mealType: .lunch,
            inputMethod: .manualText,
            rawDescription: "Test meal",
            predictedScore: 3.0,
            aiModelVersion: "stub-1.0"
        )
        return meal
    }

    // MARK: - scheduleCheckIns

    @Test func schedulesOneHourAndFourHourNotificationsWhenAuthorized() async {
        mock.stubbedStatus = .authorized
        let meal = makeMeal()

        await service.scheduleCheckIns(for: meal)

        #expect(mock.addedRequests.count == 2)
        let ids = mock.addedRequests.map(\.identifier)
        #expect(ids.contains("checkin-\(meal.id.uuidString)-oneHour"))
        #expect(ids.contains("checkin-\(meal.id.uuidString)-fourHour"))
    }

    @Test func skipsSchedulingWhenNotAuthorized() async {
        mock.stubbedStatus = .denied
        let meal = makeMeal()

        await service.scheduleCheckIns(for: meal)

        #expect(mock.addedRequests.isEmpty)
    }

    @Test func skipsSchedulingWhenNotDetermined() async {
        mock.stubbedStatus = .notDetermined
        let meal = makeMeal()

        await service.scheduleCheckIns(for: meal)

        #expect(mock.addedRequests.isEmpty)
    }

    @Test func schedulesWhenProvisional() async {
        mock.stubbedStatus = .provisional
        let meal = makeMeal()

        await service.scheduleCheckIns(for: meal)

        #expect(mock.addedRequests.count == 2)
    }

    // MARK: - cancelCheckIns

    @Test func cancelRemovesBothCheckInIdentifiers() async {
        let meal = makeMeal()

        await service.cancelCheckIns(for: meal)

        #expect(mock.removedIdentifiers.contains("checkin-\(meal.id.uuidString)-oneHour"))
        #expect(mock.removedIdentifiers.contains("checkin-\(meal.id.uuidString)-fourHour"))
    }

    // MARK: - scheduleNextMorningSummary

    @Test func schedulesNextMorningSummaryWhenAuthorized() async {
        mock.stubbedStatus = .authorized

        await service.scheduleNextMorningSummary()

        #expect(mock.addedRequests.count == 1)
        #expect(mock.addedRequests.first?.identifier == "next-morning-summary")
    }

    @Test func skipsNextMorningSummaryWhenDenied() async {
        mock.stubbedStatus = .denied

        await service.scheduleNextMorningSummary()

        #expect(mock.addedRequests.isEmpty)
    }
}
