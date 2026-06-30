import Foundation

enum FeedbackType: String, CaseIterable {
    case suggestion = "enhancement"

    var label: String { "Suggestion" }
    var icon: String  { "lightbulb" }
}

enum GitHubIssueError: LocalizedError {
    case missingSecret
    case httpError(Int)

    var errorDescription: String? {
        switch self {
        case .missingSecret:    return "Feedback is not configured. Please contact support."
        case .httpError(let c): return "Could not submit feedback (HTTP \(c)). Please try again."
        }
    }
}

protocol GitHubIssueServiceProtocol {
    func submit(title: String, body: String, type: FeedbackType) async throws
}

final class GitHubIssueService: GitHubIssueServiceProtocol {
    private let owner = "allensoberano"
    private let repo  = "triggeriq"
    private let session: URLSessionProtocol

    init(session: URLSessionProtocol = LiveURLSession()) {
        self.session = session
    }

    func submit(title: String, body: String, type: FeedbackType) async throws {
        guard let token = loadToken() else {
            throw GitHubIssueError.missingSecret
        }

        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/issues")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let issueBody = "\(body)\n\n---\n_Submitted from TriggerIQ app_"
        let payload: [String: Any] = [
            "title": title,
            "body": issueBody,
            "labels": [type.rawValue]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)

        let (_, response) = try await session.fetchData(for: request)
        // GitHub returns 201 Created on success
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw GitHubIssueError.httpError(http.statusCode)
        }
    }

    // MARK: - Private

    private func loadToken() -> String? {
        guard let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
              let dict = NSDictionary(contentsOf: url) as? [String: String] else { return nil }
        return dict["GITHUB_ISSUES_TOKEN"]
    }
}
