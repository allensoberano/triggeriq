import Testing
import SwiftData
import Foundation
@testable import TriggerIQ

@MainActor
struct InsightsViewModelTests {
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

    private func makeVM() -> (InsightsViewModel, MockPatternEngine) {
        let mock = MockPatternEngine()
        let vm = InsightsViewModel(patternEngine: mock)
        return (vm, mock)
    }

    private func insertMeal(score: Double = 3.0, daysAgo: Double = 0) -> Meal {
        let meal = Meal(
            timestamp: Date().addingTimeInterval(-daysAgo * 86400),
            mealType: .lunch,
            inputMethod: .manualText,
            rawDescription: "Test",
            predictedScore: score,
            aiModelVersion: "stub-1.0"
        )
        context.insert(meal)
        return meal
    }

    // MARK: - load

    @Test func loadPopulatesScorePoints() throws {
        _ = insertMeal(score: 2.5)
        _ = insertMeal(score: 6.0)
        try context.save()

        let (vm, _) = makeVM()
        vm.load(context: context)
        #expect(vm.scorePoints.count == 2)
    }

    @Test func loadCountsMeals() throws {
        _ = insertMeal()
        _ = insertMeal()
        _ = insertMeal()
        try context.save()

        let (vm, _) = makeVM()
        vm.load(context: context)
        #expect(vm.mealCount == 3)
    }

    @Test func loadCountsCompletedCheckIns() throws {
        let meal = insertMeal()
        let c1 = CheckIn(type: .oneHour, scheduledTime: Date())
        c1.completedTime = Date()
        c1.meal = meal
        context.insert(c1)
        let c2 = CheckIn(type: .fourHour, scheduledTime: Date())
        c2.skipped = true
        c2.meal = meal
        context.insert(c2)
        try context.save()

        let (vm, _) = makeVM()
        vm.load(context: context)
        #expect(vm.checkInCount == 1)
    }

    @Test func loadPatternsOrderedBySeverityDescending() throws {
        let p1 = SuspectFoodPattern(canonicalTag: "dairy")
        p1.avgSymptomSeverity = 1.0
        let p2 = SuspectFoodPattern(canonicalTag: "gluten")
        p2.avgSymptomSeverity = 2.5
        context.insert(p1)
        context.insert(p2)
        try context.save()

        let (vm, _) = makeVM()
        vm.load(context: context)
        #expect(vm.patterns.first?.canonicalTag == "gluten")
    }

    @Test func loadSetsBaselineSeverityFromFirstPattern() throws {
        let p = SuspectFoodPattern(canonicalTag: "soy")
        p.avgSymptomSeverity = 2.0
        p.baselineSeverity = 0.8
        context.insert(p)
        try context.save()

        let (vm, _) = makeVM()
        vm.load(context: context)
        #expect(vm.baselineSeverity == 0.8)
    }

    @Test func scorePointsPreserveScoreValues() throws {
        _ = insertMeal(score: 7.5)
        try context.save()

        let (vm, _) = makeVM()
        vm.load(context: context)
        #expect(vm.scorePoints.first?.score == 7.5)
    }

    @Test func scorePointsOrderedChronologically() throws {
        _ = insertMeal(score: 3.0, daysAgo: 2)
        _ = insertMeal(score: 8.0, daysAgo: 0)
        try context.save()

        let (vm, _) = makeVM()
        vm.load(context: context)
        #expect(vm.scorePoints.first?.score == 3.0)
        #expect(vm.scorePoints.last?.score == 8.0)
    }

    // MARK: - recomputePatterns

    @Test func recomputeCallsPatternEngine() {
        let (vm, mock) = makeVM()
        vm.recomputePatterns(context: context)
        #expect(mock.recomputeCalled == true)
    }

    @Test func recomputeCallsEngineAndReloads() throws {
        _ = insertMeal(score: 4.0)
        try context.save()
        let (vm, mock) = makeVM()
        vm.recomputePatterns(context: context)
        #expect(mock.recomputeCalled == true)
        #expect(vm.mealCount == 1)
    }
}
