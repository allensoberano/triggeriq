import SwiftUI
import Combine

@MainActor
final class FeedbackViewModel: ObservableObject {
    static let maxTitleLength = 100
    static let maxBodyLength  = 1000
    static let rateLimit      = 3
    static let rateLimitWindow: TimeInterval = 3600 // 1 hour

    @Published var feedbackType: FeedbackType = .suggestion
    @Published var title: String = ""
    @Published var body: String = ""
    @Published var isSubmitting = false
    @Published var submitted = false
    @Published var errorMessage: String?

    var titleRemaining: Int { Self.maxTitleLength - title.count }
    var bodyRemaining: Int  { Self.maxBodyLength  - body.count  }

    var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        title.count <= Self.maxTitleLength &&
        body.count  <= Self.maxBodyLength  &&
        !isSubmitting
    }

    private let service: GitHubIssueServiceProtocol
    private let defaults: UserDefaults

    init(service: GitHubIssueServiceProtocol? = nil, defaults: UserDefaults = .standard) {
        self.service  = service ?? GitHubIssueService()
        self.defaults = defaults
    }

    func submit() async {
        guard canSubmit else { return }
        submitted = false

        if isRateLimited {
            errorMessage = "You've submitted 3 suggestions in the last hour. Please try again later."
            return
        }

        isSubmitting = true
        errorMessage = nil
        do {
            try await service.submit(title: title, body: body, type: feedbackType)
            recordSubmission()
            submitted = true
        } catch {
            errorMessage = "We weren't able to submit your feedback. Please try again later."
        }
        isSubmitting = false
    }

    // MARK: - Rate limiting

    private var isRateLimited: Bool {
        recentSubmissions().count >= Self.rateLimit
    }

    private func recentSubmissions() -> [Date] {
        let cutoff = Date().addingTimeInterval(-Self.rateLimitWindow)
        let stored = defaults.array(forKey: "feedbackSubmissions") as? [Double] ?? []
        return stored.map { Date(timeIntervalSince1970: $0) }.filter { $0 > cutoff }
    }

    private func recordSubmission() {
        var recent = recentSubmissions().map(\.timeIntervalSince1970)
        recent.append(Date().timeIntervalSince1970)
        defaults.set(recent, forKey: "feedbackSubmissions")
    }
}
