import SwiftUI
import SwiftData
import PhotosUI

@MainActor
final class LogMealViewModel: ObservableObject {
    enum Step {
        case inputMethod
        case analyzing
        case confirm(AnalysisResult)
        case error(String)
    }

    @Published var step: Step = .inputMethod
    @Published var selectedPhotoItem: PhotosPickerItem?
    @Published var manualText: String = ""
    @Published var mealType: MealType = .lunch
    @Published var isSaved = false

    private let analysisService: AnalysisServiceProtocol
    private let schedulingService: NotificationSchedulingServiceProtocol

    init(
        analysisService: AnalysisServiceProtocol = resolve(),
        schedulingService: NotificationSchedulingServiceProtocol = resolve()
    ) {
        self.analysisService = analysisService
        self.schedulingService = schedulingService
    }

    func analyzePhoto(_ item: PhotosPickerItem) async {
        step = .analyzing
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                step = .error("Could not load photo.")
                return
            }
            let result = try await analysisService.analyze(imageData: data)
            step = .confirm(result)
        } catch {
            step = .error(error.localizedDescription)
        }
    }

    func analyzeText() async {
        guard !manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        step = .analyzing
        do {
            let result = try await analysisService.analyze(text: manualText)
            step = .confirm(result)
        } catch {
            step = .error(error.localizedDescription)
        }
    }

    func save(result: AnalysisResult, editedDescription: String, context: ModelContext) async {
        let meal = Meal(
            timestamp: Date(),
            mealType: mealType,
            inputMethod: selectedPhotoItem != nil ? .photo : .manualText,
            rawDescription: editedDescription,
            predictedScore: result.predictedScore,
            aiModelVersion: result.modelVersion
        )
        meal.portionEstimate = result.portionEstimate
        meal.userEdited = editedDescription != result.rawDescription

        for tag in result.foodTags {
            let foodTag = FoodTag(
                rawName: tag.rawName,
                canonicalTag: tag.canonicalTag,
                category: tag.category
            )
            meal.foodTags.append(foodTag)
            context.insert(foodTag)
        }

        context.insert(meal)
        try? context.save()

        await schedulingService.scheduleCheckIns(for: meal)
        await schedulingService.scheduleNextMorningSummary()

        isSaved = true
    }

    func retry() {
        step = .inputMethod
        manualText = ""
        selectedPhotoItem = nil
    }
}
