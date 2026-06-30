import Foundation
import SwiftData

// Assumes SwiftData (iOS 17+) as the persistence layer. If you need to support
// older iOS versions, these translate directly to Core Data entities instead —
// same fields, different annotations.

// MARK: - Meal

@Model
final class Meal {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var mealType: MealType
    var inputMethod: InputMethod

    // Photo handling — lives in app's own local file storage, never in Photos.
    var photoFileName: String?     // nil once manual entry, or once expired/deleted
    var photoExpiryDate: Date      // = timestamp + 14 days, set on creation
    var photoDeleted: Bool = false

    // AI output
    var rawDescription: String     // AI-generated (or manually typed) text — this is
                                    // what survives after the photo is gone
    var portionEstimate: String?   // simple descriptive size for V1, e.g. "medium plate"
    var predictedScore: Double     // 0–10 predicted inflammatory potential (NOT a measured
                                    // physiological value — see CheckIn for the real signal)
    var aiModelVersion: String     // which model/version produced this; lets you re-run
                                    // older meals if you improve the scoring model later
    var userEdited: Bool = false   // user corrected the AI's tags/description — useful
                                    // signal for how trustworthy the auto-tagging is

    @Relationship(deleteRule: .cascade, inverse: \FoodTag.meal)
    var foodTags: [FoodTag] = []

    @Relationship(deleteRule: .cascade, inverse: \CheckIn.meal)
    var checkIns: [CheckIn] = []

    init(timestamp: Date, mealType: MealType, inputMethod: InputMethod,
         rawDescription: String, predictedScore: Double, aiModelVersion: String) {
        self.id = UUID()
        self.timestamp = timestamp
        self.mealType = mealType
        self.inputMethod = inputMethod
        self.rawDescription = rawDescription
        self.predictedScore = predictedScore
        self.aiModelVersion = aiModelVersion
        self.photoExpiryDate = timestamp.addingTimeInterval(60 * 60 * 24 * 14)
    }
}

enum MealType: String, Codable { case breakfast, lunch, dinner, snack }
enum InputMethod: String, Codable { case photo, manualText }

// MARK: - FoodTag
// A separate entity, not a string array on Meal, so the pattern engine can query
// "every meal containing dairy" across all history. canonicalTag is what makes that
// possible — "cheese"/"mozzarella"/"parmesan" all need to bucket together or the
// correlation math is meaningless.

@Model
final class FoodTag {
    @Attribute(.unique) var id: UUID
    var rawName: String         // what the AI actually detected, e.g. "mozzarella"
    var canonicalTag: String    // normalized bucket, e.g. "dairy"
    var category: String?       // optional broader grouping: protein / grain / dairy / etc.

    var meal: Meal?

    init(rawName: String, canonicalTag: String, category: String? = nil) {
        self.id = UUID()
        self.rawName = rawName
        self.canonicalTag = canonicalTag
        self.category = category
    }
}

// MARK: - CheckIn
// This is the "ground truth" half of the score gap — what the user actually
// reported, vs. Meal.predictedScore.

@Model
final class CheckIn {
    @Attribute(.unique) var id: UUID
    var type: CheckInType
    var scheduledTime: Date
    var completedTime: Date?
    var skipped: Bool = false   // distinguishes "never answered" from "answered, felt
                                 // fine" — missing data must never silently read as zero

    // Fixed dimensions for V1. Flat optional fields are simpler than a relationship
    // for a small, known set of symptoms.
    var bloating: Int?      // 0 none, 1 mild, 2 moderate, 3 severe
    var gassy: Int?
    var jointPain: Int?
    var fatigue: Int?
    var brainFog: Int?
    var skin: Int?

    var meal: Meal?   // nil for the next-morning check-in, which covers the whole
                       // prior day rather than one specific meal

    init(type: CheckInType, scheduledTime: Date) {
        self.id = UUID()
        self.type = type
        self.scheduledTime = scheduledTime
    }
}

enum CheckInType: String, Codable { case oneHour, fourHour, nextMorning, adHoc }

// MARK: - DailyLog
// One row per calendar day. Holds manual confounders (anything HealthKit can't see)
// plus a cached HealthKit snapshot, so the insights engine isn't re-querying
// HealthKit on every analysis pass.

@Model
final class DailyLog {
    @Attribute(.unique) var date: Date   // normalized to midnight; the natural key

    // Manual confounders
    var stressLevel: Int?      // 0–3
    var alcoholDrinks: Int?
    var caffeineDrinks: Int?
    var waterGlasses: Int?     // 8oz glasses

    // Cached HealthKit snapshot
    var sleepDuration: TimeInterval?
    var sleepQuality: Double?        // % time deep/REM if available, else nil
    var avgHRV: Double?
    var restingHeartRate: Double?
    var stepCount: Int?
    var hadWorkout: Bool = false
    var workoutMinutes: Int?

    @Relationship(deleteRule: .cascade, inverse: \BowelMovementEntry.day)
    var bowelMovements: [BowelMovementEntry] = []

    @Relationship(deleteRule: .cascade, inverse: \HydrationEntry.day)
    var hydrationEntries: [HydrationEntry] = []

    init(date: Date) {
        self.date = date
    }
}

// MARK: - BowelMovementEntry

@Model
final class BowelMovementEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var bristolScale: Int   // 1–7, the clinical standard scale
    var notes: String?
    var day: DailyLog?

    init(timestamp: Date, bristolScale: Int) {
        self.id = UUID()
        self.timestamp = timestamp
        self.bristolScale = bristolScale
    }
}

// MARK: - HydrationEntry

@Model
final class HydrationEntry {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var colorScale: Int     // 1–8, standard urine color chart
    var day: DailyLog?

    init(timestamp: Date, colorScale: Int) {
        self.id = UUID()
        self.timestamp = timestamp
        self.colorScale = colorScale
    }
}

// MARK: - UserProfile (single row, app-wide settings)

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var knownConditions: [String] = []
    var knownAllergies: [String] = []
    var onboardingCompleted: Bool = false
    var healthKitAuthorized: Bool = false

    var oneHourCheckInEnabled: Bool = true
    var fourHourCheckInEnabled: Bool = true
    var nextMorningCheckInEnabled: Bool = true

    init() {
        self.id = UUID()
    }
}

// MARK: - SuspectFoodPattern
// Derived/cached data, recomputed periodically (e.g. nightly, or whenever Insights
// is opened). This is the pattern engine's OUTPUT, never user-entered directly.

@Model
final class SuspectFoodPattern {
    @Attribute(.unique) var canonicalTag: String
    var avgSymptomSeverity: Double     // avg reported severity across check-ins when
                                        // this tag was present in the meal
    var baselineSeverity: Double       // user's overall average, for comparison
    var sampleSize: Int                // number of meals containing this tag
    var confidence: PatternConfidence  // derived from sampleSize — don't surface
                                        // "strong" patterns off 3 data points
    var lastComputed: Date

    init(canonicalTag: String) {
        self.canonicalTag = canonicalTag
        self.avgSymptomSeverity = 0
        self.baselineSeverity = 0
        self.sampleSize = 0
        self.confidence = .low
        self.lastComputed = .now
    }
}

enum PatternConfidence: String, Codable { case low, emerging, strong }
