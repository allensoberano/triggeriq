import SwiftUI
import SwiftData
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var conditionsText: String = ""
    @Published var allergiesText: String = ""
    @Published var oneHourEnabled: Bool = true
    @Published var fourHourEnabled: Bool = true
    @Published var nextMorningEnabled: Bool = true

    private(set) var profile: UserProfile?
    private let photoStorage: PhotoStorageServiceProtocol

    init(photoStorage: PhotoStorageServiceProtocol? = nil) {
        self.photoStorage = photoStorage ?? resolve()
    }

    func load(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        let p = existing.first ?? {
            let newProfile = UserProfile()
            context.insert(newProfile)
            return newProfile
        }()
        profile = p
        conditionsText = p.knownConditions.joined(separator: ", ")
        allergiesText = p.knownAllergies.joined(separator: ", ")
        oneHourEnabled = p.oneHourCheckInEnabled
        fourHourEnabled = p.fourHourCheckInEnabled
        nextMorningEnabled = p.nextMorningCheckInEnabled
    }

    func save(context: ModelContext) {
        guard let profile else { return }
        profile.knownConditions = parse(conditionsText)
        profile.knownAllergies = parse(allergiesText)
        profile.oneHourCheckInEnabled = oneHourEnabled
        profile.fourHourCheckInEnabled = fourHourEnabled
        profile.nextMorningCheckInEnabled = nextMorningEnabled
        try? context.save()
    }

    func clearAllData(context: ModelContext) {
        let meals = (try? context.fetch(FetchDescriptor<Meal>())) ?? []
        for meal in meals {
            if let fileName = meal.photoFileName {
                photoStorage.delete(fileName: fileName)
            }
            context.delete(meal)
        }
        let patterns = (try? context.fetch(FetchDescriptor<SuspectFoodPattern>())) ?? []
        patterns.forEach { context.delete($0) }
        let logs = (try? context.fetch(FetchDescriptor<DailyLog>())) ?? []
        logs.forEach { context.delete($0) }
        try? context.save()
    }

    private func parse(_ text: String) -> [String] {
        text.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
