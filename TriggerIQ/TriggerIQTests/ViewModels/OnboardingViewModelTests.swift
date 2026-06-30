import Testing
import SwiftData
import Foundation
@testable import TriggerIQ

@MainActor
struct OnboardingViewModelTests {
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

    private func makeVM() -> OnboardingViewModel {
        OnboardingViewModel(
            notificationService: MockNotificationPermissionManager(),
            healthKitService: MockHealthKitService()
        )
    }

    // MARK: - Initial state

    @Test func startsOnFirstPage() {
        #expect(makeVM().page == 0)
    }

    @Test func isLastPageFalseOnFirstPage() {
        #expect(makeVM().isLastPage == false)
    }

    @Test func isLastPageTrueOnFinalPage() {
        let vm = makeVM()
        vm.page = vm.totalPages - 1
        #expect(vm.isLastPage == true)
    }

    // MARK: - finish

    @Test func finishSetsOnboardingCompleted() throws {
        let vm = makeVM()
        vm.finish(context: context)
        let profile = try context.fetch(FetchDescriptor<UserProfile>()).first
        #expect(profile?.onboardingCompleted == true)
    }

    @Test func finishPersistsSelectedConditions() throws {
        let vm = makeVM()
        vm.selectedConditions = ["IBS", "Eczema"]
        vm.finish(context: context)
        let profile = try context.fetch(FetchDescriptor<UserProfile>()).first
        #expect(profile?.knownConditions.sorted() == ["Eczema", "IBS"])
    }

    @Test func finishPersistsCustomConditions() throws {
        let vm = makeVM()
        vm.customConditions = "Hashimoto's, SIBO"
        vm.finish(context: context)
        let profile = try context.fetch(FetchDescriptor<UserProfile>()).first
        #expect(profile?.knownConditions == ["Hashimoto's", "SIBO"])
    }

    @Test func finishMergesSelectedAndCustomConditions() throws {
        let vm = makeVM()
        vm.selectedConditions = ["IBS"]
        vm.customConditions = "SIBO"
        vm.finish(context: context)
        let profile = try context.fetch(FetchDescriptor<UserProfile>()).first
        #expect(profile?.knownConditions.contains("IBS") == true)
        #expect(profile?.knownConditions.contains("SIBO") == true)
    }

    @Test func finishPersistsSelectedAllergies() throws {
        let vm = makeVM()
        vm.selectedAllergies = ["Dairy", "Gluten / Wheat"]
        vm.finish(context: context)
        let profile = try context.fetch(FetchDescriptor<UserProfile>()).first
        #expect(profile?.knownAllergies.sorted() == ["Dairy", "Gluten / Wheat"])
    }

    @Test func finishWithNothingSelectedLeavesArrayEmpty() throws {
        let vm = makeVM()
        vm.finish(context: context)
        let profile = try context.fetch(FetchDescriptor<UserProfile>()).first
        #expect(profile?.knownConditions.isEmpty == true)
    }

    @Test func finishUpdatesExistingProfile() throws {
        let existing = UserProfile()
        existing.knownConditions = ["old"]
        context.insert(existing)
        try context.save()

        let vm = makeVM()
        vm.selectedConditions = ["IBS"]
        vm.finish(context: context)

        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        #expect(profiles.count == 1)
        #expect(profiles.first?.knownConditions.contains("IBS") == true)
    }

    // MARK: - mergedList

    @Test func mergedListDeduplicatesCustomThatMatchesSelected() {
        let vm = makeVM()
        let result = vm.mergedList(selected: ["IBS"], custom: "IBS, Eczema")
        #expect(result.filter { $0 == "IBS" }.count == 1)
        #expect(result.contains("Eczema") == true)
    }

    // MARK: - fetchOrCreateProfile

    @Test func fetchOrCreateCreatesProfileWhenNoneExists() throws {
        let vm = makeVM()
        _ = vm.fetchOrCreateProfile(context: context)
        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        #expect(profiles.count == 1)
    }

    @Test func fetchOrCreateReturnsExistingProfile() throws {
        let p = UserProfile()
        context.insert(p)
        try context.save()

        let vm = makeVM()
        let returned = vm.fetchOrCreateProfile(context: context)
        let profiles = try context.fetch(FetchDescriptor<UserProfile>())
        #expect(profiles.count == 1)
        #expect(returned.id == p.id)
    }
}
