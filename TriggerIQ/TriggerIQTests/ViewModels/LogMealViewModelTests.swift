import Testing
import SwiftData
import Foundation
@testable import TriggerIQ

@MainActor
struct LogMealViewModelTests {
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

    private func makeVM(shouldThrow: Bool = false) -> (LogMealViewModel, MockAnalysisService, MockNotificationSchedulingService) {
        let analysis = MockAnalysisService()
        analysis.shouldThrow = shouldThrow
        let scheduling = MockNotificationSchedulingService()
        let vm = LogMealViewModel(analysisService: analysis, schedulingService: scheduling)
        return (vm, analysis, scheduling)
    }

    // MARK: - Initial state

    @Test func initialStepIsInputMethod() {
        let (vm, _, _) = makeVM()
        guard case .inputMethod = vm.step else {
            Issue.record("Expected .inputMethod, got \(vm.step)")
            return
        }
    }

    // MARK: - analyzeText

    @Test func analyzeTextTransitionsToConfirmOnSuccess() async throws {
        let (vm, _, _) = makeVM()
        vm.manualText = "pasta with tomato sauce"
        await vm.analyzeText()
        guard case .confirm = vm.step else {
            Issue.record("Expected .confirm, got \(vm.step)")
            return
        }
    }

    @Test func analyzeTextDoesNothingWhenTextIsEmpty() async {
        let (vm, _, _) = makeVM()
        vm.manualText = ""
        await vm.analyzeText()
        guard case .inputMethod = vm.step else {
            Issue.record("Expected .inputMethod, got \(vm.step)")
            return
        }
    }

    @Test func analyzeTextDoesNothingWhenTextIsWhitespaceOnly() async {
        let (vm, _, _) = makeVM()
        vm.manualText = "   "
        await vm.analyzeText()
        guard case .inputMethod = vm.step else {
            Issue.record("Expected .inputMethod, got \(vm.step)")
            return
        }
    }

    @Test func analyzeTextTransitionsToErrorOnThrow() async {
        let (vm, _, _) = makeVM(shouldThrow: true)
        vm.manualText = "anything"
        await vm.analyzeText()
        guard case .error = vm.step else {
            Issue.record("Expected .error, got \(vm.step)")
            return
        }
    }

    @Test func analyzeTextCallsService() async {
        let (vm, mock, _) = makeVM()
        vm.manualText = "salad"
        await vm.analyzeText()
        #expect(mock.analyzeTextCalled == true)
    }

    // MARK: - retry

    @Test func retryResetsStepToInputMethod() async {
        let (vm, _, _) = makeVM(shouldThrow: true)
        vm.manualText = "anything"
        await vm.analyzeText()
        vm.retry()
        guard case .inputMethod = vm.step else {
            Issue.record("Expected .inputMethod after retry, got \(vm.step)")
            return
        }
    }

    @Test func retryClearsManualText() async {
        let (vm, _, _) = makeVM(shouldThrow: true)
        vm.manualText = "some food"
        await vm.analyzeText()
        vm.retry()
        #expect(vm.manualText == "")
    }

    // MARK: - save

    @Test func saveSetsisSaved() async {
        let (vm, _, _) = makeVM()
        let result = AnalysisResult(
            rawDescription: "Test",
            predictedScore: 3.0,
            foodTags: [],
            portionEstimate: nil,
            modelVersion: "mock-1.0"
        )
        await vm.save(result: result, editedDescription: "Test", editedTags: [], context: context)
        #expect(vm.isSaved == true)
    }
}
