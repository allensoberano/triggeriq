import Testing
import Foundation
@testable import TriggerIQ

@MainActor
struct LiveAnalysisServiceTests {
    private let mockSession = MockURLSession()
    private var client: AnthropicClient { AnthropicClient(apiKey: "test-key", session: mockSession) }
    private var service: LiveAnalysisService { LiveAnalysisService(client: client) }

    private func anthropicResponse(text: String) -> Data {
        let json = """
        {
          "content": [{ "type": "text", "text": \(try! String(data: JSONEncoder().encode(text), encoding: .utf8)!) }],
          "model": "claude-haiku-4-5-20251001",
          "usage": { "input_tokens": 100, "output_tokens": 50 }
        }
        """
        return Data(json.utf8)
    }

    private func validAnalysisJSON() -> String {
        """
        {
          "description": "Grilled chicken with vegetables",
          "predicted_score": 2.5,
          "portion_estimate": "medium plate",
          "food_tags": [
            { "raw_name": "grilled chicken", "canonical_tag": "poultry", "category": "protein" },
            { "raw_name": "broccoli", "canonical_tag": "cruciferous", "category": "vegetable" }
          ]
        }
        """
    }

    // MARK: - Text analysis

    @Test func analyzeTextReturnsCorrectDescription() async throws {
        mockSession.responseData = anthropicResponse(text: validAnalysisJSON())
        let result = try await service.analyze(text: "chicken and broccoli")
        #expect(result.rawDescription == "Grilled chicken with vegetables")
    }

    @Test func analyzeTextReturnsCorrectScore() async throws {
        mockSession.responseData = anthropicResponse(text: validAnalysisJSON())
        let result = try await service.analyze(text: "chicken and broccoli")
        #expect(result.predictedScore == 2.5)
    }

    @Test func analyzeTextReturnsFoodTags() async throws {
        mockSession.responseData = anthropicResponse(text: validAnalysisJSON())
        let result = try await service.analyze(text: "chicken and broccoli")
        #expect(result.foodTags.count == 2)
        #expect(result.foodTags[0].canonicalTag == "poultry")
        #expect(result.foodTags[1].category == "vegetable")
    }

    @Test func analyzeTextReturnsPortionEstimate() async throws {
        mockSession.responseData = anthropicResponse(text: validAnalysisJSON())
        let result = try await service.analyze(text: "chicken and broccoli")
        #expect(result.portionEstimate == "medium plate")
    }

    @Test func analyzeTextReturnsModelVersion() async throws {
        mockSession.responseData = anthropicResponse(text: validAnalysisJSON())
        let result = try await service.analyze(text: "chicken and broccoli")
        #expect(result.modelVersion == AnthropicClient.model)
    }

    // MARK: - Image analysis

    @Test func analyzeImageReturnsResult() async throws {
        mockSession.responseData = anthropicResponse(text: validAnalysisJSON())
        let fakeImage = Data([0xFF, 0xD8, 0xFF]) // JPEG magic bytes
        let result = try await service.analyze(imageData: fakeImage)
        #expect(result.rawDescription == "Grilled chicken with vegetables")
    }

    // MARK: - Score clamping

    @Test func scoreClampedToMaximum() async throws {
        let highScoreJSON = """
        {
          "description": "Very inflammatory meal",
          "predicted_score": 15.0,
          "portion_estimate": null,
          "food_tags": []
        }
        """
        mockSession.responseData = anthropicResponse(text: highScoreJSON)
        let result = try await service.analyze(text: "test")
        #expect(result.predictedScore == 10.0)
    }

    @Test func scoreClampedToMinimum() async throws {
        let lowScoreJSON = """
        {
          "description": "Very anti-inflammatory",
          "predicted_score": -2.0,
          "portion_estimate": null,
          "food_tags": []
        }
        """
        mockSession.responseData = anthropicResponse(text: lowScoreJSON)
        let result = try await service.analyze(text: "test")
        #expect(result.predictedScore == 1.0)
    }

    // MARK: - Markdown stripping

    @Test func parsesJsonWrappedInMarkdownFences() async throws {
        let fenced = "```json\n\(validAnalysisJSON())\n```"
        mockSession.responseData = anthropicResponse(text: fenced)
        let result = try await service.analyze(text: "test")
        #expect(result.rawDescription == "Grilled chicken with vegetables")
    }

    @Test func parsesJsonWithPlainCodeFence() async throws {
        let fenced = "```\n\(validAnalysisJSON())\n```"
        mockSession.responseData = anthropicResponse(text: fenced)
        let result = try await service.analyze(text: "test")
        #expect(result.predictedScore == 2.5)
    }

    // MARK: - Error handling

    @Test func httpErrorThrows() async throws {
        mockSession.responseStatusCode = 401
        mockSession.responseData = Data("{\"error\": \"unauthorized\"}".utf8)
        await #expect(throws: AnthropicClientError.self) {
            try await service.analyze(text: "test")
        }
    }

    @Test func invalidJSONThrows() async throws {
        mockSession.responseData = anthropicResponse(text: "not valid json at all")
        await #expect(throws: AnthropicClientError.self) {
            try await service.analyze(text: "test")
        }
    }

    @Test func networkErrorThrows() async throws {
        mockSession.errorToThrow = URLError(.notConnectedToInternet)
        await #expect(throws: URLError.self) {
            try await service.analyze(text: "test")
        }
    }
}
