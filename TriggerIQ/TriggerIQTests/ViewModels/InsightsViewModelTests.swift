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

    // MARK: - hydration & stool trends

    private func insertBowelMovement(scale: Int, daysAgo: Double = 0) -> BowelMovementEntry {
        let entry = BowelMovementEntry(timestamp: Date().addingTimeInterval(-daysAgo * 86400), bristolScale: scale)
        context.insert(entry)
        return entry
    }

    private func insertHydration(colorScale: Int, daysAgo: Double = 0) -> HydrationEntry {
        let entry = HydrationEntry(timestamp: Date().addingTimeInterval(-daysAgo * 86400), colorScale: colorScale)
        context.insert(entry)
        return entry
    }

    @Test func loadPopulatesStoolPoints() throws {
        _ = insertBowelMovement(scale: 4, daysAgo: 1)
        _ = insertBowelMovement(scale: 2, daysAgo: 0)
        try context.save()

        let (vm, _) = makeVM()
        vm.load(context: context)
        #expect(vm.mealCount == 0)
        #expect(vm.stoolPoints.count == 2)
        #expect(vm.stoolPoints.first?.value == 4)
        #expect(vm.stoolPoints.last?.value == 2)
    }

    @Test func loadPopulatesHydrationPoints() throws {
        _ = insertHydration(colorScale: 1, daysAgo: 1)
        _ = insertHydration(colorScale: 6, daysAgo: 0)
        try context.save()

        let (vm, _) = makeVM()
        vm.load(context: context)
        #expect(vm.mealCount == 0)
        #expect(vm.hydrationPoints.count == 2)
        #expect(vm.hydrationPoints.first?.value == 1)
        #expect(vm.hydrationPoints.last?.value == 6)
    }

    @Test func stoolRollingAverageUsesLastFiveLogs() throws {
        // 6 entries, oldest to newest: 1,2,3,4,5,6
        for (i, scale) in [1, 2, 3, 4, 5, 6].enumerated() {
            _ = insertBowelMovement(scale: scale, daysAgo: Double(5 - i))
        }
        try context.save()

        let (vm, _) = makeVM()
        vm.load(context: context)
        #expect(vm.stoolPoints.count == 6)
        // First point: only itself in window -> avg == 1
        #expect(vm.stoolPoints[0].rollingAverage == 1)
        // Last point: average of last 5 logs (2,3,4,5,6) == 4
        #expect(vm.stoolPoints[5].rollingAverage == 4)
    }

    @Test func hydrationRollingAverageUsesLastFiveLogs() throws {
        for (i, scale) in [8, 7, 6, 5, 4, 3].enumerated() {
            _ = insertHydration(colorScale: scale, daysAgo: Double(5 - i))
        }
        try context.save()

        let (vm, _) = makeVM()
        vm.load(context: context)
        #expect(vm.hydrationPoints.count == 6)
        #expect(vm.hydrationPoints[0].rollingAverage == 8)
        // Last point: average of last 5 logs (7,6,5,4,3) == 5
        #expect(vm.hydrationPoints[5].rollingAverage == 5)
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

    // MARK: - rollingAveraged

    private func makePoints(_ scores: [Double]) -> [ScorePoint] {
        scores.enumerated().map { index, score in
            ScorePoint(date: Date().addingTimeInterval(Double(index) * 3600), score: score, mealType: .lunch)
        }
    }

    @Test func rollingAveragedReturnsEmptyForEmptyInput() {
        let result: [ScorePoint] = [].rollingAveraged(windowSize: 5)
        #expect(result.isEmpty)
    }

    @Test func rollingAveragedAveragesFullWindowWhenEnoughPoints() {
        let points = makePoints([1, 2, 3, 4, 5, 6])
        let result = points.rollingAveraged(windowSize: 5)
        // Last point averages the trailing 5: (2+3+4+5+6)/5 = 4.0
        #expect(result.last?.score == 4.0)
    }

    @Test func rollingAveragedUsesPartialWindowNearStart() {
        let points = makePoints([2, 4, 6])
        let result = points.rollingAveraged(windowSize: 5)
        #expect(result[0].score == 2.0)
        #expect(result[1].score == 3.0)
        #expect(result[2].score == 4.0)
    }

    @Test func rollingAveragedPreservesDateAndMealType() {
        let points = makePoints([1, 2, 3])
        let result = points.rollingAveraged(windowSize: 5)
        #expect(result[1].date == points[1].date)
        #expect(result[1].mealType == points[1].mealType)
    }

    @Test func rollingAveragedPreservesId() {
        let points = makePoints([1, 2, 3])
        let result = points.rollingAveraged(windowSize: 5)
        for index in points.indices {
            #expect(result[index].id == points[index].id)
        }
    }

    @Test func rollingAveragedSmoothsSingleOutlier() {
        let points = makePoints([2, 2, 2, 10, 2])
        let result = points.rollingAveraged(windowSize: 5)
        // The outlier point itself (index 3) should be smoothed by averaging the trailing window.
        #expect(result[3].score == 4.0)
    }
}
