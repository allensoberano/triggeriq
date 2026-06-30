import SwiftUI
import Combine

// MARK: - Rate-limit store

protocol FeedbackRateLimitStore {
    func load() -> [Double]
    func save(_ timestamps: [Double])
}

final class UserDefaultsRateLimitStore: FeedbackRateLimitStore {
    private let key = "feedbackSubmissions"

    func load() -> [Double] {
        UserDefaults.standard.array(forKey: key) as? [Double] ?? []
    }

    func save(_ timestamps: [Double]) {
        UserDefaults.standard.set(timestamps, forKey: key)
    }
}

final class InMemoryRateLimitStore: FeedbackRateLimitStore {
    private var timestamps: [Double] = []
    func load() -> [Double] { timestamps }
    func save(_ timestamps: [Double]) { self.timestamps = timestamps }
}

// MARK: - ViewModel

@MainActor
final class FeedbackViewModel: ObservableObject {
    static let maxTitleLength = 100
    static let maxBodyLength  = 1000
    static let rateLimit      = 3
    static let rateLimitWindow: TimeInterval = 3600

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
    private let rateLimitStore: FeedbackRateLimitStore

    init(service: GitHubIssueServiceProtocol? = nil,
         rateLimitStore: FeedbackRateLimitStore = UserDefaultsRateLimitStore()) {
        self.service = service ?? GitHubIssueService()
        self.rateLimitStore = rateLimitStore
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
        return rateLimitStore.load()
            .map { Date(timeIntervalSince1970: $0) }
            .filter { $0 > cutoff }
    }

    private func recordSubmission() {
        var timestamps = recentSubmissions().map(\.timeIntervalSince1970)
        timestamps.append(Date().timeIntervalSince1970)
        rateLimitStore.save(timestamps)
    }
}
