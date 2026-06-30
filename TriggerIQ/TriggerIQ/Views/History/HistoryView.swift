import SwiftUI
import SwiftData

struct HistoryView: View {
    @Environment(\.modelContext) private var context
    @State private var meals: [Meal] = []
    @State private var selectedMeal: Meal?

    var body: some View {
        NavigationStack {
            Group {
                if meals.isEmpty {
                    ContentUnavailableView(
                        "No meals yet",
                        systemImage: "fork.knife",
                        description: Text("Meals you log will appear here.")
                    )
                } else {
                    List {
                        ForEach(groupedByDay, id: \.date) { group in
                            Section(group.date.formatted(date: .complete, time: .omitted)) {
                                ForEach(group.meals) { meal in
                                    NavigationLink(destination: MealDetailView(meal: meal)) {
                                        MealRow(meal: meal)
                                    }
                                }
                                .onDelete { indexSet in
                                    deleteMeals(from: group.meals, at: indexSet)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("History")
            .task { loadMeals() }
        }
    }

    private func deleteMeals(from group: [Meal], at indexSet: IndexSet) {
        let photoStorage = resolve(PhotoStorageServiceProtocol.self)
        for index in indexSet {
            let meal = group[index]
            if let fileName = meal.photoFileName {
                photoStorage.delete(fileName: fileName)
            }
            context.delete(meal)
        }
        try? context.save()
        loadMeals()
    }

    private func loadMeals() {
        let descriptor = FetchDescriptor<Meal>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        meals = (try? context.fetch(descriptor)) ?? []
    }

    private var groupedByDay: [(date: Date, meals: [Meal])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: meals) { meal in
            calendar.startOfDay(for: meal.timestamp)
        }
        return groups
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, meals: $0.value) }
    }
}
