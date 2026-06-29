import SwiftUI
import SwiftData
import UserNotifications

struct ContentView: View {
    @State private var showLogMeal = false
    @State private var debugInfo = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("TriggerIQ")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Button("Log Meal") {
                    showLogMeal = true
                }
                .buttonStyle(.borderedProminent)

                // DEBUG BUTTONS — remove before Epic 5
                Divider()

                Button("Check notification status") {
                    Task {
                        let center = UNUserNotificationCenter.current()
                        let settings: UNNotificationSettings = await center.notificationSettings()
                        let pending = await center.pendingNotificationRequests()
                        debugInfo = "Auth: \(settings.authorizationStatus.rawValue)\nPending: \(pending.count)\n"
                            + pending.map { "• \($0.identifier)" }.joined(separator: "\n")
                    }
                }
                .buttonStyle(.bordered)

                Button("Open Check-in (direct)") {
                    NotificationCenter.default.post(
                        name: .openCheckIn,
                        object: CheckInDestination(checkInType: .oneHour, mealID: nil)
                    )
                }
                .buttonStyle(.bordered)

                if !debugInfo.isEmpty {
                    Text(debugInfo)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .padding(.horizontal)
                }
            }
            .padding(.top, 24)
            .navigationTitle("Today")
        }
        .sheet(isPresented: $showLogMeal) {
            LogMealSheet()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Meal.self, FoodTag.self, CheckIn.self, DailyLog.self,
            BowelMovementEntry.self, HydrationEntry.self,
            UserProfile.self, SuspectFoodPattern.self
        ], inMemory: true)
}
