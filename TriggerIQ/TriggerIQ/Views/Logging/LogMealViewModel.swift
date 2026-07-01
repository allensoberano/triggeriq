import SwiftUI
import SwiftData
import PhotosUI
import Combine
import UIKit

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
    @Published var capturedPhotoData: Data?
    @Published var manualText: String = ""
    @Published var mealType: MealType = MealType.suggested(for: Date())
    @Published var isSaved = false
    @Published var isReanalyzing = false
    // Changes every time a new analysis result is produced (initial or reanalyze) so the
    // confirm screen resets its @State (description/food tags) instead of keeping stale values.
    @Published private(set) var confirmToken = UUID()

    private let analysisService: AnalysisServiceProtocol
    private let schedulingService: NotificationSchedulingServiceProtocol
    private let photoStorage: PhotoStorageServiceProtocol

    // Holds JPEG from camera capture between camera dismiss and save
    var pendingPhotoData: Data?

    init(
        analysisService: AnalysisServiceProtocol? = nil,
        schedulingService: NotificationSchedulingServiceProtocol? = nil,
        photoStorage: PhotoStorageServiceProtocol? = nil
    ) {
        self.analysisService = analysisService ?? resolve()
        self.schedulingService = schedulingService ?? resolve()
        self.photoStorage = photoStorage ?? resolve()
    }

    private func setConfirmStep(_ result: AnalysisResult) {
        confirmToken = UUID()
        step = .confirm(result)
    }

    func analyzeCapturedPhoto(_ jpegData: Data) async {
        pendingPhotoData = jpegData
        step = .analyzing
        do {
            let result = try await analysisService.analyze(imageData: jpegData)
            setConfirmStep(result)
        } catch {
            pendingPhotoData = nil
            step = .error(error.localizedDescription)
        }
    }

    func analyzePhoto(_ item: PhotosPickerItem) async {
        step = .analyzing
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                step = .error("Could not load photo.")
                return
            }
            // Convert to JPEG — photos from the picker are often HEIC which the API doesn't support
            let jpegData: Data
            if let image = UIImage(data: data), let jpeg = image.jpegData(compressionQuality: 0.8) {
                jpegData = jpeg
            } else {
                jpegData = data
            }
            let result = try await analysisService.analyze(imageData: jpegData)
            setConfirmStep(result)
        } catch {
            step = .error(error.localizedDescription)
        }
    }

    func analyzeText() async {
        let trimmed = manualText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        step = .analyzing
        do {
            let result = try await analysisService.analyze(text: manualText)
            // Keep the user's own manually-typed description rather than any AI paraphrase —
            // only photo analysis should have the description come from the AI, since there's
            // no user-authored text to preserve in that case.
            let resultWithManualDescription = AnalysisResult(
                rawDescription: trimmed,
                predictedScore: result.predictedScore,
                foodTags: result.foodTags,
                portionEstimate: result.portionEstimate,
                modelVersion: result.modelVersion
            )
            setConfirmStep(resultWithManualDescription)
        } catch {
            step = .error(error.localizedDescription)
        }
    }

    /// Re-runs analysis on a user-edited description so a corrected detail can be reflected
    /// in the predicted score and detected ingredients before saving. Works regardless of
    /// whether the original description came from a photo or manual text entry.
    ///
    /// The description the user typed is preserved as-is — only the score, food tags, and
    /// portion estimate are refreshed from the new analysis. The AI may return its own
    /// paraphrased description, which we intentionally discard so the user's edit isn't
    /// silently overwritten.
    func reanalyze(description: String) async {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isReanalyzing = true
        defer { isReanalyzing = false }
        do {
            let result = try await analysisService.analyze(text: trimmed)
            let resultWithEditedDescription = AnalysisResult(
                rawDescription: trimmed,
                predictedScore: result.predictedScore,
                foodTags: result.foodTags,
                portionEstimate: result.portionEstimate,
                modelVersion: result.modelVersion
            )
            setConfirmStep(resultWithEditedDescription)
        } catch {
            step = .error(error.localizedDescription)
        }
    }

    func save(result: AnalysisResult, editedDescription: String, editedTags: [ParsedFoodTag], context: ModelContext) async {
        let hasPhoto = selectedPhotoItem != nil || pendingPhotoData != nil
        let meal = Meal(
            timestamp: Date(),
            mealType: mealType,
            inputMethod: hasPhoto ? .photo : .manualText,
            rawDescription: editedDescription,
            predictedScore: result.predictedScore,
            aiModelVersion: result.modelVersion
        )
        meal.portionEstimate = result.portionEstimate
        meal.userEdited = editedDescription != result.rawDescription || editedTags.count != result.foodTags.count

        // Save photo to app sandbox (never to Photos library)
        if let jpeg = pendingPhotoData {
            meal.photoFileName = try? photoStorage.save(jpegData: jpeg)
        }
        pendingPhotoData = nil

        for tag in editedTags {
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
        pendingPhotoData = nil
    }
}
