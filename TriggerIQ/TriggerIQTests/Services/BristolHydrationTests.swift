import Testing
import SwiftData
import Foundation
@testable import TriggerIQ

@MainActor
struct BristolHydrationTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let schema = Schema([Meal.self, FoodTag.self, CheckIn.self, DailyLog.self,
                             BowelMovementEntry.self, HydrationEntry.self, UserProfile.self,
                             SuspectFoodPattern.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    @Test func bowelMovementEntryPersists() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let day = DailyLog(date: today)
        context.insert(day)

        let entry = BowelMovementEntry(timestamp: Date(), bristolScale: 4)
        entry.day = day
        context.insert(entry)
        try context.save()

        let results = try context.fetch(FetchDescriptor<BowelMovementEntry>())
        #expect(results.count == 1)
        #expect(results.first?.bristolScale == 4)
    }

    @Test func hydrationEntryPersists() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let day = DailyLog(date: today)
        context.insert(day)

        let entry = HydrationEntry(timestamp: Date(), colorScale: 3)
        entry.day = day
        context.insert(entry)
        try context.save()

        let results = try context.fetch(FetchDescriptor<HydrationEntry>())
        #expect(results.count == 1)
        #expect(results.first?.colorScale == 3)
    }

    @Test func bowelEntryLinkedToDailyLog() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let day = DailyLog(date: today)
        context.insert(day)

        let entry = BowelMovementEntry(timestamp: Date(), bristolScale: 2)
        entry.day = day
        context.insert(entry)
        try context.save()

        let log = try context.fetch(FetchDescriptor<DailyLog>()).first!
        #expect(log.bowelMovements.count == 1)
    }

    @Test func hydrationEntryLinkedToDailyLog() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let day = DailyLog(date: today)
        context.insert(day)

        let entry = HydrationEntry(timestamp: Date(), colorScale: 5)
        entry.day = day
        context.insert(entry)
        try context.save()

        let log = try context.fetch(FetchDescriptor<DailyLog>()).first!
        #expect(log.hydrationEntries.count == 1)
    }
}
