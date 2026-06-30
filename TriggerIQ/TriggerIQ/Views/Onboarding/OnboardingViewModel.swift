import SwiftUI
import SwiftData
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var page = 0
    @Published var selectedConditions: Set<String> = []
    @Published var customConditions: String = ""
    @Published var selectedAllergies: Set<String> = []
    @Published var customAllergies: String = ""
    @Published var notificationStepDone = false
    @Published var healthKitStepDone = false

    let totalPages = 5
    var isLastPage: Bool { page == totalPages - 1 }

    static let presetConditions = [
        "IBS", "Crohn's Disease", "Ulcerative Colitis", "Celiac Disease",
        "Eczema", "Psoriasis", "Rheumatoid Arthritis", "Lupus",
        "Migraines", "Fibromyalgia"
    ]

    static let presetAllergies = [
        "Dairy", "Gluten / Wheat", "Peanuts", "Tree Nuts",
        "Eggs", "Soy", "Shellfish", "Fish", "Sesame"
    ]

    private let notificationService: NotificationPermissionManagerProtocol
    private let healthKitService: HealthKitServiceProtocol

    init(notificationService: NotificationPermissionManagerProtocol? = nil,
         healthKitService: HealthKitServiceProtocol? = nil) {
        self.notificationService = notificationService ?? resolve()
        self.healthKitService = healthKitService ?? resolve()
    }

    func requestNotifications() async {
        try? await notificationService.requestPermissionIfNeeded()
        notificationStepDone = true
    }

    func requestHealthKit() async {
        try? await healthKitService.requestAuthorization()
        healthKitStepDone = true
    }

    func finish(context: ModelContext) {
        let profile = fetchOrCreateProfile(context: context)
        profile.knownConditions = mergedList(selected: selectedConditions, custom: customConditions)
        profile.knownAllergies = mergedList(selected: selectedAllergies, custom: customAllergies)
        profile.onboardingCompleted = true
        try? context.save()
    }

    // MARK: - Helpers

    func fetchOrCreateProfile(context: ModelContext) -> UserProfile {
        let existing = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        if let profile = existing.first { return profile }
        let profile = UserProfile()
        context.insert(profile)
        return profile
    }

    func mergedList(selected: Set<String>, custom: String) -> [String] {
        let fromCustom = custom
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return Array(selected).sorted() + fromCustom.filter { !selected.contains($0) }
    }
}
