import SwiftUI
import SwiftData
import UserNotifications
import TipKit
import OSLog

@main
struct TriggerIQApp: App {
    @StateObject private var notificationDelegate = NotificationDelegate.shared
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "TriggerIQ", category: "TipKit")

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        do {
            try Tips.configure()
        } catch {
            logger.error("TipKit configuration failed: \(error.localizedDescription, privacy: .public)")
        }
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
