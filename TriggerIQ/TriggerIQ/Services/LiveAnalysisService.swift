import Foundation

// TODO: Replace with Apple Foundation Models once vision API is confirmed (WWDC26 image understanding)
final class LiveAnalysisService: AnalysisServiceProtocol {
    private let client: AnthropicClient

    init(client: AnthropicClient) {
        self.client = client
    }

    // TODO: Replace image path with Apple Foundation Models multimodal prompt
    func analyze(imageData: Data) async throws -> AnalysisResult {
        let base64 = imageData.base64EncodedString()
        let messages = [
            AnthropicMessage(role: "user", content: [
                .image(mediaType: "image/jpeg", base64Data: base64),
                .text(analysisPrompt(context: "the meal shown in this photo"))
            ])
        ]
        let raw = try await client.send(messages: messages, system: systemPrompt)
        return try parse(raw, modelVersion: AnthropicClient.model)
    }

    // TODO: Replace text path with Apple Foundation Models on-device inference
    func analyze(text: String) async throws -> AnalysisResult {
        let messages = [
            AnthropicMessage(role: "user", content: [
                .text(analysisPrompt(context: "this meal description: \(text)"))
            ])
        ]
        let raw = try await client.send(messages: messages, system: systemPrompt)
        return try parse(raw, modelVersion: AnthropicClient.model)
    }

    // MARK: - Prompt

    private var systemPrompt: String {
        """
        You are a nutritional analysis assistant specializing in food inflammation research.
        Always respond with valid JSON only — no markdown, no explanation, just the JSON object.
        """
    }

    private func analysisPrompt(context: String) -> String {
        """
        Analyze \(context).

        Return a JSON object with this exact structure:
        {
          "description": "A concise one-sentence description of the meal",
          "predicted_score": 4.5,
          "portion_estimate": "medium plate",
          "food_tags": [
            { "raw_name": "grilled chicken", "canonical_tag": "poultry", "category": "protein" },
            { "raw_name": "olive oil", "canonical_tag": "olive oil", "category": "fat" }
          ]
        }

        Rules:
        - predicted_score: 1–10 inflammatory potential (1 = anti-inflammatory, 10 = highly inflammatory)
        - canonical_tag: normalize to a common food group (e.g. "dairy", "gluten", "leafy greens", "poultry")
        - category: one of protein, fat, carbohydrate, vegetable, fruit, dairy, beverage, condiment, other
        - portion_estimate: natural language estimate like "small bowl", "large plate", null if unclear
        - Include every distinct ingredient you can identify
        """
    }

    // MARK: - Parsing

    private struct RawResponse: Decodable {
        let description: String
        let predictedScore: Double
        let portionEstimate: String?
        let foodTags: [RawTag]

        enum CodingKeys: String, CodingKey {
            case description
            case predictedScore = "predicted_score"
            case portionEstimate = "portion_estimate"
            case foodTags = "food_tags"
        }
    }

    private struct RawTag: Decodable {
        let rawName: String
        let canonicalTag: String
        let category: String?

        enum CodingKeys: String, CodingKey {
            case rawName = "raw_name"
            case canonicalTag = "canonical_tag"
            case category
        }
    }

    private func parse(_ text: String, modelVersion: String) throws -> AnalysisResult {
        var clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip markdown code fences Claude sometimes adds despite being asked not to
        if clean.hasPrefix("```") {
            clean = clean
                .replacingOccurrences(of: #"^```(?:json)?\n?"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\n?```$"#, with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let data = clean.data(using: .utf8) else {
            throw AnthropicClientError.decodingError("Response is not valid UTF-8")
        }
        do {
            let raw = try JSONDecoder().decode(RawResponse.self, from: data)
            let tags = raw.foodTags.map {
                ParsedFoodTag(rawName: $0.rawName, canonicalTag: $0.canonicalTag, category: $0.category)
            }
            return AnalysisResult(
                rawDescription: raw.description,
                predictedScore: min(max(raw.predictedScore, 1.0), 10.0),
                foodTags: tags,
                portionEstimate: raw.portionEstimate,
                modelVersion: modelVersion
            )
        } catch {
            throw AnthropicClientError.decodingError(error.localizedDescription)
        }
    }
}
