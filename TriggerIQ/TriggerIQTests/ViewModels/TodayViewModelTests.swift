import Testing
import SwiftData
import Foundation
@testable import TriggerIQ

@MainActor
struct TodayViewModelTests {
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

    private func makeVM() -> (TodayViewModel, MockHealthKitService) {
        let mock = MockHealthKitService()
        let vm = TodayViewModel(healthKitService: mock)
        return (vm, mock)
    }

    private func makeMeal(minutesAgo: Double = 0, type: MealType = .lunch) -> Meal {
        Meal(
            timestamp: Date().addingTimeInterval(-minutesAgo * 60),
            mealType: type,
            inputMethod: .manualText,
            rawDescription: "Test meal",
            predictedScore: 3.0,
            aiModelVersion: "stub-1.0"
        )
    }

    // MARK: - load

    @Test func loadCreatesDailyLogIfMissing() throws {
        let (vm, _) = makeVM()
        vm.load(context: context)
        let logs = try context.fetch(FetchDescriptor<DailyLog>())
        #expect(logs.count == 1)
    }

    @Test func loadFetchesTodaysMeals() throws {
        let meal = makeMeal()
        context.insert(meal)
        try context.save()

        let (vm, _) = makeVM()
        vm.load(context: context)
        #expect(vm.todayMeals.count == 1)
    }

    @Test func loadDoesNotFetchYesterdaysMeals() throws {
        let yesterday = Meal(
            timestamp: Date().addingTimeInterval(-60 * 60 * 25),
            mealType: .dinner,
            inputMethod: .manualText,
            rawDescription: "Yesterday",
            predictedScore: 2.0,
            aiModelVersion: "stub-1.0"
        )
        context.insert(yesterday)
        try context.save()

        let (vm, _) = makeVM()
        vm.load(context: context)
        #expect(vm.todayMeals.isEmpty)
    }

    @Test func loadRestoresConfounderValues() throws {
        let today = Calendar.current.startOfDay(for: Date())
        let log = DailyLog(date: today)
        log.stressLevel = 2
        log.alcoholDrinks = 1
        log.caffeineDrinks = 3
        context.insert(log)
        try context.save()

        let (vm, _) = makeVM()
        vm.load(context: context)
        #expect(vm.stress == 2)
        #expect(vm.alcoholDrinks == 1)
        #expect(vm.caffeineDrinks == 3)
    }

    // MARK: - saveConfounders

    @Test func saveConfoundersPersistsValues() throws {
        let (vm, _) = makeVM()
        vm.load(context: context)
        vm.stress = 3
        vm.alcoholDrinks = 2
        vm.saveConfounders(context: context)

        let log = try context.fetch(FetchDescriptor<DailyLog>()).first!
        #expect(log.stressLevel == 3)
        #expect(log.alcoholDrinks == 2)
    }

    // MARK: - hasPendingCheckIn

    @Test func hasPendingCheckInFalseWhenNoMeals() {
        let (vm, _) = makeVM()
        #expect(vm.hasPendingCheckIn == false)
    }

    @Test func hasPendingCheckInFalseForRecentMeal() {
        let (vm, _) = makeVM()
        vm.todayMeals = [makeMeal(minutesAgo: 30)]
        #expect(vm.hasPendingCheckIn == false)
    }

    @Test func hasPendingCheckInTrueForMealOverOneHourAgo() {
        let (vm, _) = makeVM()
        let meal = makeMeal(minutesAgo: 70)
        context.insert(meal)
        vm.todayMeals = [meal]
        #expect(vm.hasPendingCheckIn == true)
    }

    @Test func hasPendingCheckInTrueForMealOverFourHoursAgo() {
        let (vm, _) = makeVM()
        let meal = makeMeal(minutesAgo: 250)
        context.insert(meal)
        vm.todayMeals = [meal]
        #expect(vm.hasPendingCheckIn == true)
    }

    @Test func hasPendingCheckInFalseWhenOneHourCheckInDone() throws {
        let meal = makeMeal(minutesAgo: 70)
        context.insert(meal)
        let checkIn = CheckIn(type: .oneHour, scheduledTime: Date())
        checkIn.meal = meal
        context.insert(checkIn)
        try context.save()

        let (vm, _) = makeVM()
        vm.todayMeals = [meal]
        #expect(vm.hasPendingCheckIn == false)
    }

    @Test func hasPendingCheckInTrueWhenFourHourCheckInMissing() throws {
        let meal = makeMeal(minutesAgo: 250)
        context.insert(meal)
        let checkIn = CheckIn(type: .oneHour, scheduledTime: Date())
        checkIn.meal = meal
        context.insert(checkIn)
        try context.save()

        let (vm, _) = makeVM()
        vm.todayMeals = [meal]
        #expect(vm.hasPendingCheckIn == true)
    }

    // MARK: - pendingCheckInType

    @Test func pendingCheckInTypeNilForRecentMeal() {
        let (vm, _) = makeVM()
        let meal = makeMeal(minutesAgo: 30)
        #expect(vm.pendingCheckInType(for: meal) == nil)
    }

    @Test func pendingCheckInTypeOneHourForOldMeal() {
        let (vm, _) = makeVM()
        let meal = makeMeal(minutesAgo: 70)
        context.insert(meal)
        #expect(vm.pendingCheckInType(for: meal) == .oneHour)
    }

    @Test func pendingCheckInTypeFourHourTakesPriorityOverOneHour() throws {
        let meal = makeMeal(minutesAgo: 250)
        context.insert(meal)
        let oneHourCheckIn = CheckIn(type: .oneHour, scheduledTime: Date())
        oneHourCheckIn.meal = meal
        context.insert(oneHourCheckIn)
        try context.save()

        let (vm, _) = makeVM()
        #expect(vm.pendingCheckInType(for: meal) == .fourHour)
    }

    // MARK: - firstPendingMeal

    @Test func firstPendingMealReturnsNilWhenNoPending() {
        let (vm, _) = makeVM()
        vm.todayMeals = [makeMeal(minutesAgo: 10)]
        #expect(vm.firstPendingMeal() == nil)
    }

    @Test func firstPendingMealReturnsMealAndType() {
        let (vm, _) = makeVM()
        let meal = makeMeal(minutesAgo: 70)
        context.insert(meal)
        vm.todayMeals = [meal]
        let result = vm.firstPendingMeal()
        #expect(result?.meal.id == meal.id)
        #expect(result?.type == .oneHour)
    }
}
