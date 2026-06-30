import Testing
import SwiftData
import Foundation
@testable import TriggerIQ

@MainActor
struct SettingsViewModelTests {
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

    private func makeVM() -> SettingsViewModel {
        SettingsViewModel(photoStorage: MockPhotoStorageService())
    }

    private func insertProfile(conditions: [String] = [], allergies: [String] = [],
                                oneHour: Bool = true, fourHour: Bool = true,
                                morning: Bool = true) throws -> UserProfile {
        let p = UserProfile()
        p.knownConditions = conditions
        p.knownAllergies = allergies
        p.oneHourCheckInEnabled = oneHour
        p.fourHourCheckInEnabled = fourHour
        p.nextMorningCheckInEnabled = morning
        context.insert(p)
        try context.save()
        return p
    }

    // MARK: - load

    @Test func loadPopulatesConditionsText() throws {
        try insertProfile(conditions: ["IBS", "Eczema"])
        let vm = makeVM()
        vm.load(context: context)
        #expect(vm.conditionsText == "IBS, Eczema")
    }

    @Test func loadPopulatesAllergiesText() throws {
        try insertProfile(allergies: ["peanuts", "gluten"])
        let vm = makeVM()
        vm.load(context: context)
        #expect(vm.allergiesText == "peanuts, gluten")
    }

    @Test func loadRestoresCheckInToggles() throws {
        try insertProfile(oneHour: false, fourHour: true, morning: false)
        let vm = makeVM()
        vm.load(context: context)
        #expect(vm.oneHourEnabled == false)
        #expect(vm.fourHourEnabled == true)
        #expect(vm.nextMorningEnabled == false)
    }

    @Test func loadCreatesProfileIfNoneExists() throws {
        let vm = makeVM()
        vm.load(context: context)
        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        #expect(profiles.count == 1)
    }

    // MARK: - save

    @Test func savePersistsConditions() throws {
        try insertProfile()
        let vm = makeVM()
        vm.load(context: context)
        vm.conditionsText = "Crohn's, IBS"
        vm.save(context: context)
        let profile = try context.fetch(FetchDescriptor<UserProfile>()).first
        #expect(profile?.knownConditions == ["Crohn's", "IBS"])
    }

    @Test func savePersistsAllergies() throws {
        try insertProfile()
        let vm = makeVM()
        vm.load(context: context)
        vm.allergiesText = "dairy, soy"
        vm.save(context: context)
        let profile = try context.fetch(FetchDescriptor<UserProfile>()).first
        #expect(profile?.knownAllergies == ["dairy", "soy"])
    }

    @Test func savePersistsCheckInToggles() throws {
        try insertProfile()
        let vm = makeVM()
        vm.load(context: context)
        vm.oneHourEnabled = false
        vm.nextMorningEnabled = false
        vm.save(context: context)
        let profile = try context.fetch(FetchDescriptor<UserProfile>()).first
        #expect(profile?.oneHourCheckInEnabled == false)
        #expect(profile?.nextMorningCheckInEnabled == false)
    }

    @Test func saveTrimsWhitespaceFromConditions() throws {
        try insertProfile()
        let vm = makeVM()
        vm.load(context: context)
        vm.conditionsText = "  IBS  ,  Eczema  "
        vm.save(context: context)
        let profile = try context.fetch(FetchDescriptor<UserProfile>()).first
        #expect(profile?.knownConditions == ["IBS", "Eczema"])
    }

    // MARK: - clearAllData

    @Test func clearAllDataDeletesMeals() throws {
        let meal = Meal(timestamp: Date(), mealType: .lunch, inputMethod: .manualText,
                        rawDescription: "Test", predictedScore: 3.0, aiModelVersion: "stub")
        context.insert(meal)
        try context.save()

        let vm = makeVM()
        vm.clearAllData(context: context)

        let meals = try context.fetch(FetchDescriptor<Meal>())
        #expect(meals.isEmpty)
    }

    @Test func clearAllDataDeletesPatterns() throws {
        let pattern = SuspectFoodPattern(canonicalTag: "dairy")
        context.insert(pattern)
        try context.save()

        let vm = makeVM()
        vm.clearAllData(context: context)

        let patterns = try context.fetch(FetchDescriptor<SuspectFoodPattern>())
        #expect(patterns.isEmpty)
    }

    @Test func clearAllDataDeletesDailyLogs() throws {
        let log = DailyLog(date: Calendar.current.startOfDay(for: Date()))
        context.insert(log)
        try context.save()

        let vm = makeVM()
        vm.clearAllData(context: context)

        let logs = try context.fetch(FetchDescriptor<DailyLog>())
        #expect(logs.isEmpty)
    }

    @Test func clearAllDataCallsDeleteOnPhotoStorage() throws {
        let meal = Meal(timestamp: Date(), mealType: .lunch, inputMethod: .photo,
                        rawDescription: "Test", predictedScore: 3.0, aiModelVersion: "stub")
        meal.photoFileName = "photo123.jpg"
        context.insert(meal)
        try context.save()

        let mockStorage = MockPhotoStorageService()
        let vm = SettingsViewModel(photoStorage: mockStorage)
        vm.clearAllData(context: context)

        #expect(mockStorage.deletedFileNames.contains("photo123.jpg"))
    }
}
