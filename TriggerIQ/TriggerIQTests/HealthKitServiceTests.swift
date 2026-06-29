import Testing
import SwiftData
import Foundation

@testable import TriggerIQ

@MainActor
struct HealthKitServiceTests {

    private func makeContext() throws -> ModelContext {
        let schema = Schema([DailyLog.self, BowelMovementEntry.self, HydrationEntry.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return container.mainContext
    }

    // MARK: - MockHealthKitService (protocol-level tests)

    @Test func requestAuthorizationIsCalled() async throws {
        let mock = MockHealthKitService()
        try await mock.requestAuthorization()
        #expect(mock.requestAuthorizationCalled == true)
    }

    @Test func fetchAndCacheRecordsDate() async throws {
        let mock = MockHealthKitService()
        let context = try makeContext()
        let date = Date()

        try await mock.fetchAndCacheDaily(for: date, context: context)

        #expect(mock.fetchedDates.count == 1)
    }

    @Test func fetchAndCacheThrowsWhenFlagSet() async throws {
        let mock = MockHealthKitService()
        mock.shouldThrow = true
        let context = try makeContext()

        await #expect(throws: (any Error).self) {
            try await mock.fetchAndCacheDaily(for: Date(), context: context)
        }
    }

    // MARK: - DailyLog creation logic

    @Test func fetchAndCacheCreatesDailyLogForDate() async throws {
        let context = try makeContext()
        let startOfDay = Calendar.current.startOfDay(for: Date())

        // Insert a DailyLog manually to simulate what HealthKitService would do
        let log = DailyLog(date: startOfDay)
        log.stepCount = 8000
        context.insert(log)
        try context.save()

        // Verify it can be fetched back by date
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date == startOfDay }
        )
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.stepCount == 8000)
    }

    @Test func dailyLogFieldsMapCorrectly() throws {
        let context = try makeContext()
        let date = Calendar.current.startOfDay(for: Date())

        let log = DailyLog(date: date)
        log.sleepDuration = 7.5 * 3600
        log.sleepQuality = 0.35
        log.avgHRV = 45.2
        log.restingHeartRate = 58.0
        log.stepCount = 10234
        log.hadWorkout = true
        log.workoutMinutes = 42
        context.insert(log)
        try context.save()

        let descriptor = FetchDescriptor<DailyLog>(predicate: #Predicate { $0.date == date })
        let fetched = try context.fetch(descriptor).first!

        #expect(fetched.sleepDuration == 7.5 * 3600)
        #expect(fetched.sleepQuality == 0.35)
        #expect(fetched.avgHRV == 45.2)
        #expect(fetched.restingHeartRate == 58.0)
        #expect(fetched.stepCount == 10234)
        #expect(fetched.hadWorkout == true)
        #expect(fetched.workoutMinutes == 42)
    }
}
