import SwiftUI
import SwiftData
import Combine

@MainActor
final class CheckInViewModel: ObservableObject {
    @Published var bloating: Int = 0
    @Published var jointPain: Int = 0
    @Published var fatigue: Int = 0
    @Published var brainFog: Int = 0
    @Published var skin: Int = 0
    @Published var isSaved = false
    @Published var showBristolHydration = false

    let checkInType: CheckInType
    let mealID: PersistentIdentifier?   // nil for nextMorning check-in

    private let schedulingService: NotificationSchedulingServiceProtocol

    init(checkInType: CheckInType,
         mealID: PersistentIdentifier? = nil,
         schedulingService: NotificationSchedulingServiceProtocol? = nil) {
        self.checkInType = checkInType
        self.mealID = mealID
        self.schedulingService = schedulingService ?? resolve()
    }

    func save(context: ModelContext) {
        let checkIn = CheckIn(type: checkInType, scheduledTime: Date())
        checkIn.completedTime = Date()
        checkIn.bloating = bloating
        checkIn.jointPain = jointPain
        checkIn.fatigue = fatigue
        checkIn.brainFog = brainFog
        checkIn.skin = skin

        let meal = mealID.flatMap { context.model(for: $0) as? Meal }
        checkIn.meal = meal

        context.insert(checkIn)

        // Void earlier unanswered check-ins so the Today banner clears
        if let meal {
            voidSupersededCheckIns(for: meal, context: context)
        }

        try? context.save()
        isSaved = true

        // Cancel all remaining notifications for this meal
        Task {
            if let meal { await schedulingService.cancelCheckIns(for: meal) }
        }
    }

    func skip(context: ModelContext) {
        let checkIn = CheckIn(type: checkInType, scheduledTime: Date())
        checkIn.skipped = true
        if let mealID { checkIn.meal = context.model(for: mealID) as? Meal }
        context.insert(checkIn)
        try? context.save()
        isSaved = true
    }

    // MARK: - Private

    // When completing a later check-in, mark earlier unanswered ones skipped.
    // This prevents the Today banner from re-showing an already-superseded window.
    private func voidSupersededCheckIns(for meal: Meal, context: ModelContext) {
        let superseded: [CheckInType]
        switch checkInType {
        case .oneHour:     superseded = []
        case .fourHour:    superseded = [.oneHour]
        case .nextMorning: superseded = [.oneHour, .fourHour]
        case .adHoc:       superseded = []
        }

        for type in superseded {
            let alreadyRecorded = meal.checkIns.contains { $0.type == type }
            guard !alreadyRecorded else { continue }
            let skipped = CheckIn(type: type, scheduledTime: Date())
            skipped.skipped = true
            skipped.meal = meal
            context.insert(skipped)
        }
    }

    var title: String {
        switch checkInType {
        case .oneHour: return "1-Hour Check-in"
        case .fourHour: return "4-Hour Check-in"
        case .nextMorning: return "Morning Check-in"
        case .adHoc: return "How Are You Feeling?"
        }
    }

    var subtitle: String {
        switch checkInType {
        case .oneHour: return "It's been an hour since your meal. Any symptoms?"
        case .fourHour: return "4 hours since your meal. How are you feeling?"
        case .nextMorning: return "How did you feel overnight and this morning?"
        case .adHoc: return "Rate any symptoms you're experiencing right now."
        }
    }
}
