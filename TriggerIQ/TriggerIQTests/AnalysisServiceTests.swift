import Testing
import SwiftData
import Foundation
@testable import TriggerIQ

@MainActor
struct AnalysisServiceTests {
    let container: ModelContainer
    let context: ModelContext

    init() throws {
        let schema = Schema([Meal.self, FoodTag.self, CheckIn.self, DailyLog.self,
                             BowelMovementEntry.self, HydrationEntry.self, UserProfile.self,
                             SuspectFoodPattern.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [config])
        context = container.mainContext
    }

    // MARK: - StubAnalysisService

    @Test func stubAnalyzeTextReturnsResult() async throws {
        let service = StubAnalysisService()
        let result = try await service.analyze(text: "pasta with tomato sauce")
        #expect(!result.rawDescription.isEmpty)
        #expect(result.predictedScore >= 0)
        #expect(result.predictedScore <= 10)
        #expect(!result.modelVersion.isEmpty)
    }

    @Test func stubAnalyzeImageReturnsResult() async throws {
        let service = StubAnalysisService()
        let data = Data(repeating: 0, count: 100)
        let result = try await service.analyze(imageData: data)
        #expect(!result.rawDescription.isEmpty)
        #expect(!result.foodTags.isEmpty)
    }

    // MARK: - MockAnalysisService

    @Test func mockAnalyzeImageSetsCalled() async throws {
        let mock = MockAnalysisService()
        _ = try await mock.analyze(imageData: Data())
        #expect(mock.analyzeImageCalled == true)
    }

    @Test func mockAnalyzeTextSetsCalled() async throws {
        let mock = MockAnalysisService()
        _ = try await mock.analyze(text: "salad")
        #expect(mock.analyzeTextCalled == true)
    }

    @Test func mockThrowsWhenFlagSet() async throws {
        let mock = MockAnalysisService()
        mock.shouldThrow = true
        await #expect(throws: (any Error).self) {
            _ = try await mock.analyze(text: "anything")
        }
    }

    // MARK: - LogMealViewModel save logic

    @Test func savePersistsMealToContext() async throws {
        let mockAnalysis = MockAnalysisService()
        let mockScheduling = MockNotificationSchedulingService()
        let vm = LogMealViewModel(analysisService: mockAnalysis, schedulingService: mockScheduling)

        let result = AnalysisResult(
            rawDescription: "Grilled chicken",
            predictedScore: 2.0,
            foodTags: [ParsedFoodTag(rawName: "chicken", canonicalTag: "poultry", category: "protein")],
            portionEstimate: "medium",
            modelVersion: "mock-1.0"
        )

        await vm.save(result: result, editedDescription: "Grilled chicken", context: context)

        let descriptor = FetchDescriptor<Meal>()
        let meals = try context.fetch(descriptor)
        #expect(meals.count == 1)
        #expect(meals.first?.rawDescription == "Grilled chicken")
        #expect(meals.first?.predictedScore == 2.0)
    }

    @Test func savePersistsFoodTags() async throws {
        let mockAnalysis = MockAnalysisService()
        let mockScheduling = MockNotificationSchedulingService()
        let vm = LogMealViewModel(analysisService: mockAnalysis, schedulingService: mockScheduling)

        let result = AnalysisResult(
            rawDescription: "Salad",
            predictedScore: 1.5,
            foodTags: [
                ParsedFoodTag(rawName: "romaine", canonicalTag: "leafy greens", category: "vegetable"),
                ParsedFoodTag(rawName: "olive oil", canonicalTag: "olive oil", category: "fat")
            ],
            portionEstimate: nil,
            modelVersion: "mock-1.0"
        )

        await vm.save(result: result, editedDescription: "Salad", context: context)

        let descriptor = FetchDescriptor<FoodTag>()
        let tags = try context.fetch(descriptor)
        #expect(tags.count == 2)
    }

    @Test func saveMarksMealAsUserEditedWhenDescriptionChanged() async throws {
        let mockAnalysis = MockAnalysisService()
        let mockScheduling = MockNotificationSchedulingService()
        let vm = LogMealViewModel(analysisService: mockAnalysis, schedulingService: mockScheduling)

        let result = AnalysisResult(
            rawDescription: "Original AI description",
            predictedScore: 3.0,
            foodTags: [],
            portionEstimate: nil,
            modelVersion: "mock-1.0"
        )

        await vm.save(result: result, editedDescription: "User edited description", context: context)

        let descriptor = FetchDescriptor<Meal>()
        let meal = try context.fetch(descriptor).first!
        #expect(meal.userEdited == true)
    }

    @Test func saveTriggersCheckInScheduling() async throws {
        let mockAnalysis = MockAnalysisService()
        let mockScheduling = MockNotificationSchedulingService()
        let vm = LogMealViewModel(analysisService: mockAnalysis, schedulingService: mockScheduling)

        let result = AnalysisResult(
            rawDescription: "Test",
            predictedScore: 3.0,
            foodTags: [],
            portionEstimate: nil,
            modelVersion: "mock-1.0"
        )

        await vm.save(result: result, editedDescription: "Test", context: context)

        #expect(mockScheduling.scheduleCheckInsCalled == true)
        #expect(mockScheduling.scheduleMorningSummaryCalled == true)
    }
}
