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
    @Published var mealType: MealType = .lunch
    @Published var isSaved = false

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

    func analyzeCapturedPhoto(_ jpegData: Data) async {
        pendingPhotoData = jpegData
        step = .analyzing
        do {
            let result = try await analysisService.analyze(imageData: jpegData)
            step = .confirm(result)
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
