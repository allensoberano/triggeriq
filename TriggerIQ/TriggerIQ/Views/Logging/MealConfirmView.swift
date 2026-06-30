import SwiftUI
import SwiftData
import TipKit

struct MealConfirmView: View {
    @ObservedObject var vm: LogMealViewModel
    let result: AnalysisResult
    let context: ModelContext

    @State private var editedDescription: String
    @State private var foodTags: [ParsedFoodTag]
    @State private var selectedTipKey: IngredientTipKey?
    @State private var selectedReplacementTip: IngredientReplacementTip?

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
                        let advice = resolve(IngredientInflammationAdvisorProtocol.self).advice(for: tag)
                        if let replacementTip = advice.replacementTip {
                            let tipKey = IngredientTipKey(tag: tag)
                            Button {
                                if selectedTipKey == tipKey {
                                    selectedTipKey = nil
                                    selectedReplacementTip = nil
                                } else {
                                    selectedTipKey = tipKey
                                    selectedReplacementTip = IngredientReplacementTip(
                                        id: tipKey.id,
                                        ingredientName: tag.rawName.capitalized,
                                        detailMessage: replacementTip
                                    )
                                }
                            } label: {
                                FoodTagRow(tag: tag, advice: advice)
                            }
                            .buttonStyle(.plain)
                            .popoverTip(
                                selectedTipKey == tipKey
                                ? selectedReplacementTip
                                : nil,
                                arrowEdge: .top
                            )
                        } else {
                            FoodTagRow(tag: tag, advice: advice)
                        }
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
    let advice: IngredientInflammationAdvice

    init(tag: ParsedFoodTag, advice: IngredientInflammationAdvice? = nil) {
        self.tag = tag
        self.advice = advice ?? resolve(IngredientInflammationAdvisorProtocol.self).advice(for: tag)
    }

    private var levelColor: Color {
        switch advice.level {
        case .low: return .green
        case .moderate: return .orange
        case .high: return .red
        }
    }

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
                .foregroundStyle(levelColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(levelColor.opacity(0.14))
                .clipShape(Capsule())
            if advice.replacementTip != nil {
                Image(systemName: "lightbulb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct IngredientTipKey: Equatable {
    let rawName: String
    let canonicalTag: String
    let category: String?

    init(tag: ParsedFoodTag) {
        self.rawName = tag.rawName
        self.canonicalTag = tag.canonicalTag
        self.category = tag.category
    }

    var id: String {
        [rawName, canonicalTag, category ?? ""]
            .map { Data($0.lowercased().utf8).base64EncodedString() }
            .joined(separator: ":")
    }
}

private struct IngredientReplacementTip: Tip {
    let id: String
    let ingredientName: String
    let detailMessage: String

    var title: Text {
        Text("\(ingredientName) replacement tip")
    }

    var message: Text? {
        Text(detailMessage)
    }

    var image: Image? {
        Image(systemName: "lightbulb")
    }
}
