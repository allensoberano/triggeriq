import Foundation
@testable import TriggerIQ

final class MockAnalysisService: AnalysisServiceProtocol, @unchecked Sendable {
    var analyzeImageCalled = false
    var analyzeTextCalled = false
    var shouldThrow = false
    var stubbedResult = AnalysisResult(
        rawDescription: "Test meal",
        predictedScore: 3.0,
        foodTags: [
            ParsedFoodTag(rawName: "chicken", canonicalTag: "poultry", category: "protein")
        ],
        portionEstimate: "medium",
        modelVersion: "mock-1.0"
    )

    func analyze(imageData: Data) async throws -> AnalysisResult {
        analyzeImageCalled = true
        if shouldThrow { throw URLError(.notConnectedToInternet) }
        return stubbedResult
    }

    func analyze(text: String) async throws -> AnalysisResult {
        analyzeTextCalled = true
        if shouldThrow { throw URLError(.notConnectedToInternet) }
        return stubbedResult
    }
}
