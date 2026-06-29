import SwiftUI
import SwiftData

struct MealConfirmView: View {
    @ObservedObject var vm: LogMealViewModel
    let result: AnalysisResult
    let context: ModelContext

    @State private var editedDescription: String
    @State private var foodTags: [ParsedFoodTag]

    init(vm: LogMealViewModel, result: AnalysisResult, context: ModelContext) {
        self.vm = vm
        self.result = result
        self.context = context
        self._editedDescription = State(initialValue: result.rawDescription)
        self._foodTags = State(initialValue: result.foodTags)
    }

    var body: some View {
        List {
            Section("Meal type") {
                Picker("Type", selection: $vm.mealType) {
                    Text("Breakfast").tag(MealType.breakfast)
                    Text("Lunch").tag(MealType.lunch)
                    Text("Dinner").tag(MealType.dinner)
                    Text("Snack").tag(MealType.snack)
                }
                .pickerStyle(.segmented)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            Section("Description") {
                TextField("What did you eat?", text: $editedDescription, axis: .vertical)
                    .lineLimit(3...8)
            }

            Section("Inflammation score") {
                ScoreRow(score: result.predictedScore)
            }

            if !foodTags.isEmpty {
                Section("Detected ingredients") {
                    ForEach(foodTags, id: \.rawName) { tag in
                        FoodTagRow(tag: tag)
                    }
                    .onDelete { indices in
                        foodTags.remove(atOffsets: indices)
                    }
                }
            }

            if let portion = result.portionEstimate {
                Section("Portion") {
                    Label(portion, systemImage: "chart.bar.fill")
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Button {
                    Task { await vm.save(result: result, editedDescription: editedDescription, editedTags: foodTags, context: context) }
                } label: {
                    Text("Save Meal")
                        .frame(maxWidth: .infinity)
                        .fontWeight(.semibold)
                }
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }
        }
        .navigationTitle("Confirm Meal")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { vm.retry() }
            }
        }
    }
}

// MARK: - Score Row

private struct ScoreRow: View {
    let score: Double

    var color: Color {
        switch score {
        case ..<3.5: return .green
        case ..<6.5: return .orange
        default: return .red
        }
    }

    var label: String {
        switch score {
        case ..<3.5: return "Low"
        case ..<6.5: return "Moderate"
        default: return "High"
        }
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(color)
            Spacer()
            Text(String(format: "%.1f / 10", score))
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundStyle(color)
        }
    }
}

// MARK: - Food Tag Row

private struct FoodTagRow: View {
    let tag: ParsedFoodTag

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(tag.rawName.capitalized)
                    .font(.subheadline)
                if let category = tag.category {
                    Text(category)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(tag.canonicalTag)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color(.tertiarySystemFill))
                .clipShape(Capsule())
        }
    }
}
