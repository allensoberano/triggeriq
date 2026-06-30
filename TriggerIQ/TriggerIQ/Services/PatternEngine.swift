import Foundation
import SwiftData

@MainActor
protocol PatternEngineProtocol {
    func recompute(context: ModelContext)
}

@MainActor
final class PatternEngine: PatternEngineProtocol {

    func recompute(context: ModelContext) {
        let meals = (try? context.fetch(FetchDescriptor<Meal>())) ?? []
        let completedCheckIns = meals.flatMap { $0.checkIns }.filter { !$0.skipped && $0.completedTime != nil }

        guard !completedCheckIns.isEmpty else { return }

        let baseline = averageSeverity(completedCheckIns)

        // Group check-ins by canonical food tag
        var tagSeverities: [String: [Double]] = [:]
        for meal in meals {
            let severities = completedCheckIns
                .filter { $0.meal?.id == meal.id }
                .map { maxSeverity($0) }
            guard !severities.isEmpty else { continue }
            let avg = severities.reduce(0, +) / Double(severities.count)
            for tag in meal.foodTags {
                tagSeverities[tag.canonicalTag, default: []].append(avg)
            }
        }

        // Upsert SuspectFoodPattern rows
        let existing = (try? context.fetch(FetchDescriptor<SuspectFoodPattern>())) ?? []
        let existingByTag = Dictionary(uniqueKeysWithValues: existing.map { ($0.canonicalTag, $0) })

        for (tag, severities) in tagSeverities {
            let pattern = existingByTag[tag] ?? {
                let p = SuspectFoodPattern(canonicalTag: tag)
                context.insert(p)
                return p
            }()
            pattern.avgSymptomSeverity = severities.reduce(0, +) / Double(severities.count)
            pattern.baselineSeverity = baseline
            pattern.sampleSize = severities.count
            pattern.confidence = confidence(for: severities.count)
            pattern.lastComputed = .now
        }

        // Remove patterns for tags no longer in any meal
        let activeTags = Set(tagSeverities.keys)
        for pattern in existing where !activeTags.contains(pattern.canonicalTag) {
            context.delete(pattern)
        }

        try? context.save()
    }

    // MARK: - Helpers

    private func maxSeverity(_ checkIn: CheckIn) -> Double {
        let vals = [checkIn.bloating, checkIn.gassy, checkIn.jointPain, checkIn.fatigue,
                    checkIn.brainFog, checkIn.skin].compactMap { $0 }
        return Double(vals.max() ?? 0)
    }

    private func averageSeverity(_ checkIns: [CheckIn]) -> Double {
        let vals = checkIns.map { maxSeverity($0) }
        guard !vals.isEmpty else { return 0 }
        return vals.reduce(0, +) / Double(vals.count)
    }

    private func confidence(for sampleSize: Int) -> PatternConfidence {
        switch sampleSize {
        case ..<5:  return .low
        case ..<10: return .emerging
        default:    return .strong
        }
    }
}
