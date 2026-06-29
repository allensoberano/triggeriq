import SwiftUI
import SwiftData
import UserNotifications

@main
struct TriggerIQApp: App {
    @State private var pendingCheckIn: CheckInDestination?

    init() {
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
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
            ContentView()
                .task {
                    await resolve(NotificationPermissionManager.self).requestPermissionIfNeeded()
                    try? await resolve(HealthKitServiceProtocol.self).requestAuthorization()
                }
                .sheet(item: $pendingCheckIn) { destination in
                    CheckInView(vm: CheckInViewModel(
                        checkInType: destination.checkInType,
                        mealID: destination.mealID
                    ))
                }
                .onReceive(NotificationCenter.default.publisher(for: .openCheckIn)) { note in
                    guard let destination = note.object as? CheckInDestination else { return }
                    pendingCheckIn = destination
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

extension Notification.Name {
    static let openCheckIn = Notification.Name("openCheckIn")
}
