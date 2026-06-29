import Foundation

struct AnalysisResult {
    let rawDescription: String
    let predictedScore: Double
    let foodTags: [ParsedFoodTag]
    let portionEstimate: String?
    let modelVersion: String
}

struct ParsedFoodTag {
    let rawName: String
    let canonicalTag: String
    let category: String?
}

protocol AnalysisServiceProtocol {
    func analyze(imageData: Data) async throws -> AnalysisResult
    func analyze(text: String) async throws -> AnalysisResult
}

final class StubAnalysisService: AnalysisServiceProtocol {
    func analyze(imageData: Data) async throws -> AnalysisResult {
        try await Task.sleep(for: .milliseconds(800))
        return AnalysisResult(
            rawDescription: "Grilled chicken salad with romaine, tomatoes, and olive oil dressing",
            predictedScore: 2.5,
            foodTags: [
                ParsedFoodTag(rawName: "grilled chicken", canonicalTag: "poultry", category: "protein"),
                ParsedFoodTag(rawName: "romaine", canonicalTag: "leafy greens", category: "vegetable"),
                ParsedFoodTag(rawName: "tomato", canonicalTag: "tomato", category: "vegetable"),
                ParsedFoodTag(rawName: "olive oil", canonicalTag: "olive oil", category: "fat")
            ],
            portionEstimate: "medium plate",
            modelVersion: "stub-1.0"
        )
    }

    func analyze(text: String) async throws -> AnalysisResult {
        try await Task.sleep(for: .milliseconds(600))
        return AnalysisResult(
            rawDescription: text,
            predictedScore: 3.0,
            foodTags: [
                ParsedFoodTag(rawName: text, canonicalTag: "unknown", category: nil)
            ],
            portionEstimate: nil,
            modelVersion: "stub-1.0"
        )
    }
}
