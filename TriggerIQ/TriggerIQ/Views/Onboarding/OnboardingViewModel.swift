import SwiftUI
import SwiftData
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    @Published var page = 0
    @Published var conditions: String = ""
    @Published var allergies: String = ""
    @Published var notificationStepDone = false
    @Published var healthKitStepDone = false

    let totalPages = 5

    var isLastPage: Bool { page == totalPages - 1 }

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
        profile.knownConditions = parse(conditions)
        profile.knownAllergies = parse(allergies)
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

    private func parse(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
