import Testing
import Foundation
@testable import TriggerIQ

struct AnthropicClientTests {
    private let mockSession = MockURLSession()
    private var client: AnthropicClient { AnthropicClient(apiKey: "test-key", session: mockSession) }

    private func makeResponse(text: String, statusCode: Int = 200) -> Data {
        let encoded = (try? String(data: JSONEncoder().encode(text), encoding: .utf8)) ?? "\"\""
        let json = """
        {
          "content": [{ "type": "text", "text": \(encoded) }],
          "model": "claude-haiku-4-5-20251001",
          "usage": { "input_tokens": 10, "output_tokens": 20 }
        }
        """
        mockSession.responseStatusCode = statusCode
        return Data(json.utf8)
    }

    @Test func sendsAuthorizationHeader() async throws {
        mockSession.responseData = makeResponse(text: "hello")
        let result = try await client.send(
            messages: [AnthropicMessage(role: "user", content: [.text("hi")])],
            system: "test"
        )
        #expect(result == "hello")
        let authHeader = mockSession.capturedRequest?.value(forHTTPHeaderField: "x-api-key")
        #expect(authHeader == "test-key")
    }

    @Test func returnsTextFromResponse() async throws {
        mockSession.responseData = makeResponse(text: "parsed output")
        let result = try await client.send(
            messages: [AnthropicMessage(role: "user", content: [.text("hi")])],
            system: "test"
        )
        #expect(result == "parsed output")
    }

    @Test func throwsOnNon200Response() async throws {
        mockSession.responseData = makeResponse(text: "error body", statusCode: 429)
        await #expect(throws: AnthropicClientError.self) {
            try await client.send(
                messages: [AnthropicMessage(role: "user", content: [.text("hi")])],
                system: "test"
            )
        }
    }

    @Test func throwsOnNetworkFailure() async throws {
        mockSession.errorToThrow = URLError(.timedOut)
        await #expect(throws: URLError.self) {
            try await client.send(
                messages: [AnthropicMessage(role: "user", content: [.text("hi")])],
                system: "test"
            )
        }
    }
}
