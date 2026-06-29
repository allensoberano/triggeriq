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
        let vm = CheckInViewModel(checkInType: .oneHour)
        #expect(vm.bloating == 0)
        #expect(vm.jointPain == 0)
        #expect(vm.fatigue == 0)
        #expect(vm.brainFog == 0)
        #expect(vm.skin == 0)
    }

    @Test func isSavedStartsFalse() {
        let vm = CheckInViewModel(checkInType: .oneHour)
        #expect(vm.isSaved == false)
    }

    // MARK: - Titles

    @Test func titleForOneHour() {
        let vm = CheckInViewModel(checkInType: .oneHour)
        #expect(vm.title == "1-Hour Check-in")
    }

    @Test func titleForFourHour() {
        let vm = CheckInViewModel(checkInType: .fourHour)
        #expect(vm.title == "4-Hour Check-in")
    }

    @Test func titleForNextMorning() {
        let vm = CheckInViewModel(checkInType: .nextMorning)
        #expect(vm.title == "Morning Check-in")
    }

    // MARK: - Save

    @Test func savePersistsCheckIn() throws {
        let vm = CheckInViewModel(checkInType: .oneHour)
        vm.bloating = 2
        vm.fatigue = 1

        vm.save(context: context)

        let results = try context.fetch(FetchDescriptor<CheckIn>())
        #expect(results.count == 1)
        #expect(results.first?.bloating == 2)
        #expect(results.first?.fatigue == 1)
        #expect(results.first?.skipped == false)
        #expect(results.first?.completedTime != nil)
    }

    @Test func saveSetsIsSaved() {
        let vm = CheckInViewModel(checkInType: .oneHour)
        vm.save(context: context)
        #expect(vm.isSaved == true)
    }

    @Test func saveSetsCheckInType() throws {
        let vm = CheckInViewModel(checkInType: .fourHour)
        vm.save(context: context)
        let result = try context.fetch(FetchDescriptor<CheckIn>()).first!
        #expect(result.type == .fourHour)
    }

    // MARK: - Skip

    @Test func skipPersistsSkippedCheckIn() throws {
        let vm = CheckInViewModel(checkInType: .nextMorning)
        vm.skip(context: context)
        let result = try context.fetch(FetchDescriptor<CheckIn>()).first!
        #expect(result.skipped == true)
        #expect(result.completedTime == nil)
    }

    @Test func skipSetsIsSaved() {
        let vm = CheckInViewModel(checkInType: .oneHour)
        vm.skip(context: context)
        #expect(vm.isSaved == true)
    }

    // MARK: - Meal association

    @Test func saveAssociatesMealWhenIDProvided() throws {
        let meal = Meal(
            timestamp: Date(),
            mealType: .lunch,
            inputMethod: .manualText,
            rawDescription: "Test meal",
            predictedScore: 3.0,
            aiModelVersion: "stub-1.0"
        )
        context.insert(meal)
        try context.save()

        let vm = CheckInViewModel(checkInType: .oneHour, mealID: meal.persistentModelID)
        vm.save(context: context)

        let checkIn = try context.fetch(FetchDescriptor<CheckIn>()).first!
        #expect(checkIn.meal?.id == meal.id)
    }
}
