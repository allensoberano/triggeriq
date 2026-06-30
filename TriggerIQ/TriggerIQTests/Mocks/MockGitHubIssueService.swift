import Foundation
@testable import TriggerIQ

final class MockGitHubIssueService: GitHubIssueServiceProtocol {
    var submittedTitle: String?
    var submittedBody: String?
    var submittedType: FeedbackType?
    var errorToThrow: Error?

    func submit(title: String, body: String, type: FeedbackType) async throws {
        if let error = errorToThrow { throw error }
        submittedTitle = title
        submittedBody = body
        submittedType = type
    }
}
