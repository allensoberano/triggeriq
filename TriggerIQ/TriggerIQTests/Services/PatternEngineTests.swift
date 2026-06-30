import Testing
import SwiftData
import Foundation
@testable import TriggerIQ

@MainActor
struct PatternEngineTests {
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

    private func makeMeal(tags: [(raw: String, canonical: String)],
                          checkInSeverities: [Int]) -> Meal {
        let meal = Meal(timestamp: Date(), mealType: .lunch, inputMethod: .manualText,
                        rawDescription: "Test", predictedScore: 3.0, aiModelVersion: "stub-1.0")
        context.insert(meal)

        for (raw, canonical) in tags {
            let tag = FoodTag(rawName: raw, canonicalTag: canonical, category: nil)
            tag.meal = meal
            context.insert(tag)
        }

        for severity in checkInSeverities {
            let checkIn = CheckIn(type: .oneHour, scheduledTime: Date())
            checkIn.completedTime = Date()
            checkIn.bloating = severity
            checkIn.meal = meal
            context.insert(checkIn)
        }

        return meal
    }

    @Test func recomputeCreatesPatternForTag() throws {
        _ = makeMeal(tags: [("mozzarella", "dairy")], checkInSeverities: [2])
        try context.save()

        PatternEngine().recompute(context: context)

        let patterns = try context.fetch(FetchDescriptor<SuspectFoodPattern>())
        #expect(patterns.count == 1)
        #expect(patterns.first?.canonicalTag == "dairy")
    }

    @Test func recomputeAveragesSeverityAcrossMeals() throws {
        _ = makeMeal(tags: [("cheese", "dairy")], checkInSeverities: [2])
        _ = makeMeal(tags: [("milk", "dairy")], checkInSeverities: [0])
        try context.save()

        PatternEngine().recompute(context: context)

        let pattern = try context.fetch(FetchDescriptor<SuspectFoodPattern>()).first
        #expect(pattern?.avgSymptomSeverity == 1.0)
    }

    @Test func recomputeSampleSizeMatchesMealCount() throws {
        _ = makeMeal(tags: [("chicken", "poultry")], checkInSeverities: [1])
        _ = makeMeal(tags: [("turkey", "poultry")], checkInSeverities: [1])
        _ = makeMeal(tags: [("duck", "poultry")], checkInSeverities: [1])
        try context.save()

        PatternEngine().recompute(context: context)

        let pattern = try context.fetch(FetchDescriptor<SuspectFoodPattern>()).first { $0.canonicalTag == "poultry" }
        #expect(pattern?.sampleSize == 3)
    }

    @Test func confidenceLowUnder5Samples() throws {
        _ = makeMeal(tags: [("gluten", "gluten")], checkInSeverities: [3])
        try context.save()

        PatternEngine().recompute(context: context)

        let pattern = try context.fetch(FetchDescriptor<SuspectFoodPattern>()).first
        #expect(pattern?.confidence == .low)
    }

    @Test func confidenceEmergingAt5To9Samples() throws {
        for _ in 0..<7 {
            _ = makeMeal(tags: [("wheat", "gluten")], checkInSeverities: [2])
        }
        try context.save()

        PatternEngine().recompute(context: context)

        let pattern = try context.fetch(FetchDescriptor<SuspectFoodPattern>()).first
        #expect(pattern?.confidence == .emerging)
    }

    @Test func confidenceStrongAt10PlusSamples() throws {
        for _ in 0..<12 {
            _ = makeMeal(tags: [("bread", "gluten")], checkInSeverities: [3])
        }
        try context.save()

        PatternEngine().recompute(context: context)

        let pattern = try context.fetch(FetchDescriptor<SuspectFoodPattern>()).first
        #expect(pattern?.confidence == .strong)
    }

    @Test func skippedCheckInsAreExcluded() throws {
        let meal = Meal(timestamp: Date(), mealType: .lunch, inputMethod: .manualText,
                        rawDescription: "Test", predictedScore: 3.0, aiModelVersion: "stub-1.0")
        context.insert(meal)
        let tag = FoodTag(rawName: "soy", canonicalTag: "soy")
        tag.meal = meal
        context.insert(tag)

        let skipped = CheckIn(type: .oneHour, scheduledTime: Date())
        skipped.skipped = true
        skipped.meal = meal
        context.insert(skipped)
        try context.save()

        PatternEngine().recompute(context: context)

        // No completed check-ins → no patterns should be created
        let patterns = try context.fetch(FetchDescriptor<SuspectFoodPattern>())
        #expect(patterns.isEmpty)
    }

    @Test func removesPatternForDeletedTag() throws {
        let meal = makeMeal(tags: [("corn", "corn")], checkInSeverities: [1])
        try context.save()

        PatternEngine().recompute(context: context)
        var patterns = try context.fetch(FetchDescriptor<SuspectFoodPattern>())
        #expect(patterns.count == 1)

        // Remove all food tags from the meal
        for tag in meal.foodTags { context.delete(tag) }
        try context.save()

        PatternEngine().recompute(context: context)
        patterns = try context.fetch(FetchDescriptor<SuspectFoodPattern>())
        #expect(patterns.isEmpty)
    }

    @Test func recomputeIsIdempotent() throws {
        _ = makeMeal(tags: [("egg", "egg")], checkInSeverities: [2])
        try context.save()

        let engine = PatternEngine()
        engine.recompute(context: context)
        engine.recompute(context: context)

        let patterns = try context.fetch(FetchDescriptor<SuspectFoodPattern>())
        #expect(patterns.count == 1)
    }
}
