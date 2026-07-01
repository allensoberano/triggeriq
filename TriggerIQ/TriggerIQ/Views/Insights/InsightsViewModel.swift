import SwiftUI
import SwiftData
import Combine

struct ScorePoint: Identifiable {
    let id: UUID
    let date: Date
    let score: Double
    let mealType: MealType

    init(id: UUID = UUID(), date: Date, score: Double, mealType: MealType) {
        self.id = id
        self.date = date
        self.score = score
        self.mealType = mealType
    }
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
            return ScorePoint(id: self[index].id, date: self[index].date, score: avg, mealType: self[index].mealType)
        }
    }
}

struct TrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
    let rollingAverage: Double
}

@MainActor
final class InsightsViewModel: ObservableObject {
    @Published var scorePoints: [ScorePoint] = []
    @Published var stoolPoints: [TrendPoint] = []
    @Published var hydrationPoints: [TrendPoint] = []
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

        let bowelMovements = (try? context.fetch(
            FetchDescriptor<BowelMovementEntry>(sortBy: [SortDescriptor(\.timestamp)])
        )) ?? []
        stoolPoints = Self.trendPoints(dates: bowelMovements.map(\.timestamp),
                                        values: bowelMovements.map { Double($0.bristolScale) })

        let hydrationEntries = (try? context.fetch(
            FetchDescriptor<HydrationEntry>(sortBy: [SortDescriptor(\.timestamp)])
        )) ?? []
        hydrationPoints = Self.trendPoints(dates: hydrationEntries.map(\.timestamp),
                                            values: hydrationEntries.map { Double($0.colorScale) })

        let allPatterns = (try? context.fetch(
            FetchDescriptor<SuspectFoodPattern>(sortBy: [SortDescriptor(\.avgSymptomSeverity, order: .reverse)])
        )) ?? []
        patterns = allPatterns
        baselineSeverity = allPatterns.first?.baselineSeverity ?? 0
    }

    private static func trendPoints(dates: [Date], values: [Double]) -> [TrendPoint] {
        let averages = rollingAverages(values)
        return zip(zip(dates, values), averages).map { pair, avg in
            TrendPoint(date: pair.0, value: pair.1, rollingAverage: avg)
        }
    }

    /// Number of most-recent logs used to compute the smoothed rolling average.
    private static let trendRollingWindowSize = 5

    /// Computes a trailing rolling average (over up to `trendRollingWindowSize` prior
    /// entries, including the current one) for a chronologically sorted set of values.
    private static func rollingAverages(_ values: [Double]) -> [Double] {
        var result: [Double] = []
        result.reserveCapacity(values.count)
        for i in values.indices {
            let start = max(0, i - trendRollingWindowSize + 1)
            let slice = values[start...i]
            result.append(slice.reduce(0, +) / Double(slice.count))
        }
        return result
    }

    func recomputePatterns(context: ModelContext) {
        patternEngine.recompute(context: context)
        load(context: context)
    }
}
