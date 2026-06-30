import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }

            HistoryView()
                .tabItem { Label("History", systemImage: "clock.fill") }

            InsightsView()
                .tabItem { Label("Insights", systemImage: "chart.line.uptrend.xyaxis") }
        }
        .task {
            resolve(PhotoStorageServiceProtocol.self).purgeExpired(context: context)
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
