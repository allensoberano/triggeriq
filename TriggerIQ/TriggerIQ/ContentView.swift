import SwiftUI
import SwiftData

// MARK: - Root — gates on onboarding completion

struct RootView: View {
    @Environment(\.modelContext) private var context
    @State private var onboardingCompleted: Bool? = nil

    var body: some View {
        Group {
            if let completed = onboardingCompleted {
                if completed {
                    ContentView()
                } else {
                    OnboardingView()
                }
            }
        }
        .task { checkOnboarding() }
        .onChange(of: onboardingCompleted) { _, completed in
            // Re-check after onboarding finishes so ContentView loads
            if completed == false { checkOnboarding() }
        }
        // Poll for profile completion after onboarding writes it
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            checkOnboarding()
        }
    }

    private func checkOnboarding() {
        let profiles = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        onboardingCompleted = profiles.first?.onboardingCompleted ?? false
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
