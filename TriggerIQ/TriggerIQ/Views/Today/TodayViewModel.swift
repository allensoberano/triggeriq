import SwiftUI
import SwiftData
import Combine

@MainActor
final class TodayViewModel: ObservableObject {
    @Published var todayMeals: [Meal] = []
    @Published var todayLog: DailyLog?
    @Published var pendingCheckIn: CheckInDestination?
    @Published var stress: Int = 0
    @Published var alcoholDrinks: Int = 0
    @Published var caffeineDrinks: Int = 0

    private let healthKitService: HealthKitServiceProtocol

    init(healthKitService: HealthKitServiceProtocol? = nil) {
        self.healthKitService = healthKitService ?? resolve()
    }

    func load(context: ModelContext) {
        let today = Calendar.current.startOfDay(for: Date())
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)!

        let mealDescriptor = FetchDescriptor<Meal>(
            predicate: #Predicate { $0.timestamp >= today && $0.timestamp < tomorrow },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        todayMeals = (try? context.fetch(mealDescriptor)) ?? []

        let logDescriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date == today }
        )
        if let log = try? context.fetch(logDescriptor).first {
            todayLog = log
            stress = log.stressLevel ?? 0
            alcoholDrinks = log.alcoholDrinks ?? 0
            caffeineDrinks = log.caffeineDrinks ?? 0
        } else {
            let log = DailyLog(date: today)
            context.insert(log)
            try? context.save()
            todayLog = log
        }
    }

    func saveConfounders(context: ModelContext) {
        guard let log = todayLog else { return }
        log.stressLevel = stress
        log.alcoholDrinks = alcoholDrinks
        log.caffeineDrinks = caffeineDrinks
        try? context.save()
    }

    func refreshHealthKit(context: ModelContext) async {
        try? await healthKitService.fetchAndCacheDaily(for: Date(), context: context)
        load(context: context)
    }

    var hasPendingCheckIn: Bool {
        todayMeals.contains { pendingCheckInType(for: $0) != nil }
    }

    func firstPendingMeal() -> (meal: Meal, type: CheckInType)? {
        for meal in todayMeals {
            if let type = pendingCheckInType(for: meal) {
                return (meal, type)
            }
        }
        return nil
    }

    func pendingCheckInType(for meal: Meal) -> CheckInType? {
        let oneHourAgo = Date().addingTimeInterval(-60 * 60)
        let fourHoursAgo = Date().addingTimeInterval(-4 * 60 * 60)
        let hasOneHour = meal.checkIns.contains { $0.type == .oneHour }
        let hasFourHour = meal.checkIns.contains { $0.type == .fourHour }

        if meal.timestamp <= fourHoursAgo && !hasFourHour { return .fourHour }
        if meal.timestamp <= oneHourAgo && !hasOneHour { return .oneHour }
        return nil
    }
}
