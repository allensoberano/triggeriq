import SwiftUI
import SwiftData
import UserNotifications
import TipKit

@main
struct TriggerIQApp: App {
    @StateObject private var notificationDelegate = NotificationDelegate.shared

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        try? Tips.configure()
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Meal.self,
            FoodTag.self,
            CheckIn.self,
            DailyLog.self,
            BowelMovementEntry.self,
            HydrationEntry.self,
            UserProfile.self,
            SuspectFoodPattern.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .sheet(item: $notificationDelegate.pendingCheckIn) { destination in
                    CheckInView(vm: CheckInViewModel(
                        checkInType: destination.checkInType,
                        mealID: destination.mealID
                    ))
                }
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Notification deep-link

struct CheckInDestination: Identifiable {
    let id = UUID()
    let checkInType: CheckInType
    let mealID: PersistentIdentifier?
}

extension CheckInDestination: Equatable {}
