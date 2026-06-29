import Testing
import SwiftData
import Foundation

@testable import TriggerIQ

@MainActor
struct HealthKitServiceTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let schema = Schema([DailyLog.self, BowelMovementEntry.self, HydrationEntry.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    // MARK: - MockHealthKitService (protocol-level tests)

    @Test func requestAuthorizationIsCalled() async throws {
        let mock = MockHealthKitService()
        try await mock.requestAuthorization()
        #expect(mock.requestAuthorizationCalled == true)
    }

    @Test func fetchAndCacheRecordsDate() async throws {
        let mock = MockHealthKitService()
        try await mock.fetchAndCacheDaily(for: Date(), context: context)
        #expect(mock.fetchedDates.count == 1)
    }

    @Test func fetchAndCacheThrowsWhenFlagSet() async throws {
        let mock = MockHealthKitService()
        mock.shouldThrow = true
        await #expect(throws: (any Error).self) {
            try await mock.fetchAndCacheDaily(for: Date(), context: context)
        }
    }

    // MARK: - DailyLog creation logic

    @Test func fetchAndCacheCreatesDailyLogForDate() async throws {
        let startOfDay = Calendar.current.startOfDay(for: Date())

        let log = DailyLog(date: startOfDay)
        log.stepCount = 8000
        context.insert(log)
        try context.save()

        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date == startOfDay }
        )
        let results = try context.fetch(descriptor)
        #expect(results.count == 1)
        #expect(results.first?.stepCount == 8000)
    }

    @Test func dailyLogFieldsMapCorrectly() throws {
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
