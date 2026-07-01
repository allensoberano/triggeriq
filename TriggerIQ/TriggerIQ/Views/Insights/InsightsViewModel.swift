import SwiftUI
import SwiftData
import Combine

struct ScorePoint: Identifiable {
    let id = UUID()
    let date: Date
    let score: Double
    let mealType: MealType
}

extension Array where Element == ScorePoint {
    /// Returns a smoothed series where each point's score is the average of
    /// itself and up to `windowSize - 1` preceding points (a trailing rolling average).
    func rollingAveraged(windowSize: Int) -> [ScorePoint] {
        guard !isEmpty, windowSize > 0 else { return self }
        return indices.map { index in
            let start = Swift.max(0, index - windowSize + 1)
            let window = self[start...index]
            let avg = window.map(\.score).reduce(0, +) / Double(window.count)
            return ScorePoint(date: self[index].date, score: avg, mealType: self[index].mealType)
        }
    }
}

@MainActor
final class InsightsViewModel: ObservableObject {
    @Published var scorePoints: [ScorePoint] = []
    @Published var patterns: [SuspectFoodPattern] = []
    @Published var baselineSeverity: Double = 0
    @Published var mealCount: Int = 0
    @Published var checkInCount: Int = 0

    private let patternEngine: PatternEngineProtocol

    init(patternEngine: PatternEngineProtocol = resolve()) {
        self.patternEngine = patternEngine
    }

    func load(context: ModelContext) {
        let meals = (try? context.fetch(
            FetchDescriptor<Meal>(sortBy: [SortDescriptor(\.timestamp)])
        )) ?? []

        scorePoints = meals.map {
            ScorePoint(date: $0.timestamp, score: $0.predictedScore, mealType: $0.mealType)
        }
        mealCount = meals.count

        let allCheckIns = meals.flatMap { $0.checkIns }.filter { !$0.skipped && $0.completedTime != nil }
        checkInCount = allCheckIns.count

        let allPatterns = (try? context.fetch(
            FetchDescriptor<SuspectFoodPattern>(sortBy: [SortDescriptor(\.avgSymptomSeverity, order: .reverse)])
        )) ?? []
        patterns = allPatterns
        baselineSeverity = allPatterns.first?.baselineSeverity ?? 0
    }

    func recomputePatterns(context: ModelContext) {
        patternEngine.recompute(context: context)
        load(context: context)
    }
}
