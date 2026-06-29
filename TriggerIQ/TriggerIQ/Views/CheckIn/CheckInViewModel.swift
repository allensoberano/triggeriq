import SwiftUI
import SwiftData
internal import Combine

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

    init(checkInType: CheckInType, mealID: PersistentIdentifier? = nil) {
        self.checkInType = checkInType
        self.mealID = mealID
    }

    func save(context: ModelContext) {
        let checkIn = CheckIn(type: checkInType, scheduledTime: Date())
        checkIn.completedTime = Date()
        checkIn.bloating = bloating
        checkIn.jointPain = jointPain
        checkIn.fatigue = fatigue
        checkIn.brainFog = brainFog
        checkIn.skin = skin

        if let mealID {
            checkIn.meal = context.model(for: mealID) as? Meal
        }

        context.insert(checkIn)
        try? context.save()
        isSaved = true
    }

    func skip(context: ModelContext) {
        let checkIn = CheckIn(type: checkInType, scheduledTime: Date())
        checkIn.skipped = true
        context.insert(checkIn)
        try? context.save()
        isSaved = true
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
