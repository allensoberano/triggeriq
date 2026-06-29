import SwiftUI
import SwiftData

struct ContentView: View {
    @State private var showLogMeal = false

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
