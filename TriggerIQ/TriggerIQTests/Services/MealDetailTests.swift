import Testing
import SwiftData
import Foundation
@testable import TriggerIQ

@MainActor
struct MealDetailTests {
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

    private func makeMeal(minutesAgo: Double = 0) -> Meal {
        Meal(
            timestamp: Date().addingTimeInterval(-minutesAgo * 60),
            mealType: .lunch,
            inputMethod: .manualText,
            rawDescription: "Test meal",
            predictedScore: 4.5,
            aiModelVersion: "stub-1.0"
        )
    }

    // MARK: - CheckIn timeline ordering

    @Test func checkInsOrderedByScheduledTime() throws {
        let meal = makeMeal(minutesAgo: 300)
        context.insert(meal)

        let fourHour = CheckIn(type: .fourHour, scheduledTime: Date().addingTimeInterval(-60))
        fourHour.meal = meal
        let oneHour = CheckIn(type: .oneHour, scheduledTime: Date().addingTimeInterval(-240 * 60))
        oneHour.meal = meal
        context.insert(fourHour)
        context.insert(oneHour)
        try context.save()

        let sorted = meal.checkIns.sorted { $0.scheduledTime < $1.scheduledTime }
        #expect(sorted.first?.type == .oneHour)
        #expect(sorted.last?.type == .fourHour)
    }

    // MARK: - Skipped vs unanswered

    @Test func skippedCheckInHasNoCompletedTime() throws {
        let meal = makeMeal()
        context.insert(meal)

        let checkIn = CheckIn(type: .oneHour, scheduledTime: Date())
        checkIn.skipped = true
        checkIn.meal = meal
        context.insert(checkIn)
        try context.save()

        #expect(meal.checkIns.first?.skipped == true)
        #expect(meal.checkIns.first?.completedTime == nil)
    }

    @Test func completedCheckInHasCompletedTime() throws {
        let meal = makeMeal()
        context.insert(meal)

        let checkIn = CheckIn(type: .oneHour, scheduledTime: Date())
        checkIn.completedTime = Date()
        checkIn.bloating = 2
        checkIn.fatigue = 1
        checkIn.meal = meal
        context.insert(checkIn)
        try context.save()

        #expect(meal.checkIns.first?.completedTime != nil)
        #expect(meal.checkIns.first?.bloating == 2)
    }

    // MARK: - Food tags

    @Test func mealFoodTagsCascadeDelete() throws {
        let meal = makeMeal()
        context.insert(meal)

        let tag = FoodTag(rawName: "chicken", canonicalTag: "poultry", category: "protein")
        tag.meal = meal
        meal.foodTags.append(tag)
        context.insert(tag)
        try context.save()

        #expect(meal.foodTags.count == 1)
        context.delete(meal)
        try context.save()

        let tags = try context.fetch(FetchDescriptor<FoodTag>())
        #expect(tags.isEmpty)
    }

    // MARK: - DailyLog confounder linkage

    @Test func dailyLogConfoundersSavedForMealDay() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let log = DailyLog(date: today)
        log.stressLevel = 2
        log.alcoholDrinks = 1
        context.insert(log)
        try context.save()

        let descriptor = FetchDescriptor<DailyLog>(predicate: #Predicate { $0.date == today })
        let fetched = try context.fetch(descriptor).first
        #expect(fetched?.stressLevel == 2)
        #expect(fetched?.alcoholDrinks == 1)
    }
}
