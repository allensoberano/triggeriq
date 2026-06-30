import Foundation

// MARK: - URLSession protocol for testability

protocol URLSessionProtocol {
    func fetchData(for request: URLRequest) async throws -> (Data, URLResponse)
}

final class LiveURLSession: URLSessionProtocol {
    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }
    func fetchData(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

// MARK: - Anthropic API client

enum AnthropicClientError: Error, LocalizedError {
    case missingAPIKey
    case httpError(statusCode: Int, body: String)
    case decodingError(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "No Anthropic API key found. Add your key in Settings."
        case .httpError(let code, let body):
            return "API error \(code): \(body)"
        case .decodingError(let detail):
            return "Could not parse AI response: \(detail)"
        }
    }
}

struct AnthropicMessage: Encodable {
    let role: String
    let content: [AnthropicContent]
}

enum AnthropicContent: Encodable {
    case text(String)
    case image(mediaType: String, base64Data: String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .image(let mediaType, let base64Data):
            try container.encode("image", forKey: .type)
            var sourceContainer = container.nestedContainer(keyedBy: SourceKeys.self, forKey: .source)
            try sourceContainer.encode("base64", forKey: .type)
            try sourceContainer.encode(mediaType, forKey: .mediaType)
            try sourceContainer.encode(base64Data, forKey: .data)
        }
    }

    enum CodingKeys: String, CodingKey {
        case type, text, source
    }
    enum SourceKeys: String, CodingKey {
        case type, mediaType = "media_type", data
    }
}

struct AnthropicRequest: Encodable {
    let model: String
    let maxTokens: Int
    let system: String
    let messages: [AnthropicMessage]

    enum CodingKeys: String, CodingKey {
        case model, system, messages
        case maxTokens = "max_tokens"
    }
}

struct AnthropicResponse: Decodable {
    struct ContentBlock: Decodable {
        let type: String
        let text: String?
    }
    struct Usage: Decodable {
        let inputTokens: Int
        let outputTokens: Int
        enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }
    let content: [ContentBlock]
    let model: String
    let usage: Usage
}

final class AnthropicClient {
    private let session: URLSessionProtocol
    private let apiKey: String

    static let model = "claude-haiku-4-5-20251001"
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let apiVersion = "2023-06-01"

    init(apiKey: String, session: URLSessionProtocol = LiveURLSession()) {
        self.apiKey = apiKey
        self.session = session
    }

    func send(messages: [AnthropicMessage], system: String, maxTokens: Int = 1024) async throws -> String {
        let body = AnthropicRequest(
            model: Self.model,
            maxTokens: maxTokens,
            system: system,
            messages: messages
        )

        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue(Self.apiVersion, forHTTPHeaderField: "anthropic-version")
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.fetchData(for: request)

        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AnthropicClientError.httpError(statusCode: http.statusCode, body: body)
        }

        let decoded = try JSONDecoder().decode(AnthropicResponse.self, from: data)
        guard let text = decoded.content.first(where: { $0.type == "text" })?.text else {
            throw AnthropicClientError.decodingError("No text block in response")
        }
        return text
    }
}
