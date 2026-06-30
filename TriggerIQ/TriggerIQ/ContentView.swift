import SwiftUI
import SwiftData

// MARK: - Root — gates on onboarding completion

struct RootView: View {
    @Query private var profiles: [UserProfile]
    @State private var sessionCompleted = false

    private var showOnboarding: Bool {
        #if DEBUG
        return !sessionCompleted
        #else
        return !(profiles.first?.onboardingCompleted ?? false)
        #endif
    }

    var body: some View {
        if showOnboarding {
            OnboardingView(onComplete: { sessionCompleted = true })
        } else {
            ContentView()
        }
    }
}

// MARK: - Main tab view

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

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
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
