import Foundation
@testable import TriggerIQ

final class MockURLSession: URLSessionProtocol {
    var responseData: Data = Data()
    var responseStatusCode: Int = 200
    var errorToThrow: Error?

    func fetchData(for request: URLRequest) async throws -> (Data, URLResponse) {
        if let error = errorToThrow { throw error }
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: responseStatusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (responseData, response)
    }
}
