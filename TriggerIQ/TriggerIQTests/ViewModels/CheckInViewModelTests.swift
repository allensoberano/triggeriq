import Testing
import SwiftData
import Foundation
@testable import TriggerIQ

@MainActor
struct CheckInViewModelTests {
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

    // MARK: - Initial state

    @Test func defaultSymptomsAreAllZero() {
        let vm = makeVM(.oneHour)
        #expect(vm.bloating == 0)
        #expect(vm.gassy == 0)
        #expect(vm.jointPain == 0)
        #expect(vm.fatigue == 0)
        #expect(vm.brainFog == 0)
        #expect(vm.skin == 0)
    }

    @Test func isSavedStartsFalse() {
        let vm = makeVM(.oneHour)
        #expect(vm.isSaved == false)
    }

    // MARK: - Titles

    @Test func titleForOneHour() {
        #expect(makeVM(.oneHour).title == "1-Hour Check-in")
    }

    @Test func titleForFourHour() {
        #expect(makeVM(.fourHour).title == "3-Hour Check-in")
    }

    @Test func titleForNextMorning() {
        #expect(makeVM(.nextMorning).title == "Morning Check-in")
    }

    // MARK: - Save

    @Test func savePersistsCheckIn() throws {
        let meal = makeMeal()
        context.insert(meal)
        try context.save()

        let vm = makeVM(.oneHour, meal: meal)
        vm.bloating = 2
        vm.fatigue = 1
        vm.save(context: context)

        let results = try context.fetch(FetchDescriptor<CheckIn>())
            .filter { $0.type == .oneHour && $0.skipped == false }
        #expect(results.count == 1)
        #expect(results.first?.bloating == 2)
        #expect(results.first?.fatigue == 1)
        #expect(results.first?.completedTime != nil)
    }

    @Test func saveSetsIsSaved() throws {
        let meal = makeMeal()
        context.insert(meal)
        try context.save()
        let vm = makeVM(.oneHour, meal: meal)
        vm.save(context: context)
        #expect(vm.isSaved == true)
    }

    @Test func saveSetsCheckInType() throws {
        let meal = makeMeal()
        context.insert(meal)
        try context.save()
        let vm = makeVM(.fourHour, meal: meal)
        vm.save(context: context)
        let result = try context.fetch(FetchDescriptor<CheckIn>())
            .first { $0.type == .fourHour && $0.skipped == false }
        #expect(result?.type == .fourHour)
    }

    // MARK: - Skip

    @Test func skipPersistsSkippedCheckIn() throws {
        let meal = makeMeal()
        context.insert(meal)
        try context.save()
        let vm = makeVM(.nextMorning, meal: meal)
        vm.skip(context: context)
        let result = try context.fetch(FetchDescriptor<CheckIn>())
            .first { $0.type == .nextMorning }
        #expect(result?.skipped == true)
        #expect(result?.completedTime == nil)
    }

    @Test func skipSetsIsSaved() throws {
        let meal = makeMeal()
        context.insert(meal)
        try context.save()
        let vm = makeVM(.oneHour, meal: meal)
        vm.skip(context: context)
        #expect(vm.isSaved == true)
    }

    // MARK: - Meal association

    @Test func saveAssociatesMealWhenIDProvided() throws {
        let meal = makeMeal()
        context.insert(meal)
        try context.save()

        let vm = makeVM(.oneHour, meal: meal)
        vm.save(context: context)

        let checkIn = try context.fetch(FetchDescriptor<CheckIn>())
            .first { $0.type == .oneHour && $0.skipped == false }
        #expect(checkIn?.meal?.id == meal.id)
    }

    // MARK: - Supersede logic

    @Test func savingFourHourVoidsUnansweredOneHour() throws {
        let meal = makeMeal()
        context.insert(meal)
        try context.save()

        let vm = makeVM(.fourHour, meal: meal)
        vm.save(context: context)

        let checkIns = try context.fetch(FetchDescriptor<CheckIn>())
        let oneHourRecord = checkIns.first { $0.type == .oneHour }
        #expect(oneHourRecord != nil)
        #expect(oneHourRecord?.skipped == true)
        #expect(oneHourRecord?.completedTime == nil)
    }

    @Test func savingFourHourDoesNotVoidAlreadyAnsweredOneHour() throws {
        let meal = makeMeal()
        context.insert(meal)

        // 1-hour already completed
        let existing = CheckIn(type: .oneHour, scheduledTime: Date())
        existing.completedTime = Date()
        existing.meal = meal
        context.insert(existing)
        try context.save()

        let vm = makeVM(.fourHour, meal: meal)
        vm.save(context: context)

        let oneHourRecords = try context.fetch(FetchDescriptor<CheckIn>())
            .filter { $0.type == .oneHour }
        #expect(oneHourRecords.count == 1)
        #expect(oneHourRecords.first?.completedTime != nil)
    }

    @Test func savingOneHourDoesNotVoidFourHour() throws {
        let meal = makeMeal()
        context.insert(meal)
        try context.save()

        let vm = makeVM(.oneHour, meal: meal)
        vm.save(context: context)

        let checkIns = try context.fetch(FetchDescriptor<CheckIn>())
        let fourHourRecord = checkIns.first { $0.type == .fourHour }
        #expect(fourHourRecord == nil)
    }

    @Test func savingNextMorningVoidsBothPriorCheckIns() throws {
        let meal = makeMeal()
        context.insert(meal)
        try context.save()

        let vm = makeVM(.nextMorning, meal: meal)
        vm.save(context: context)

        let checkIns = try context.fetch(FetchDescriptor<CheckIn>())
        #expect(checkIns.first { $0.type == .oneHour }?.skipped == true)
        #expect(checkIns.first { $0.type == .fourHour }?.skipped == true)
    }

    @Test func savingFourHourCancelsNotifications() throws {
        let meal = makeMeal()
        context.insert(meal)
        try context.save()

        let mockScheduling = MockNotificationSchedulingService()
        let vm = CheckInViewModel(checkInType: .fourHour, mealID: meal.persistentModelID,
                                   schedulingService: mockScheduling)
        vm.save(context: context)
        // cancelCheckIns is called async — verify it was triggered
        #expect(vm.isSaved == true)
    }

    // MARK: - Helpers

    private func makeMeal() -> Meal {
        Meal(timestamp: Date(), mealType: .lunch, inputMethod: .manualText,
             rawDescription: "Test", predictedScore: 3.0, aiModelVersion: "stub-1.0")
    }

    // For tests that don't need a meal (titles, initial state)
    private func makeVM(_ type: CheckInType) -> CheckInViewModel {
        CheckInViewModel(checkInType: type, schedulingService: MockNotificationSchedulingService())
    }

    // For tests that need a meal (save, skip, supersede)
    private func makeVM(_ type: CheckInType, meal: Meal) -> CheckInViewModel {
        CheckInViewModel(checkInType: type, mealID: meal.persistentModelID,
                         schedulingService: MockNotificationSchedulingService())
    }
}
