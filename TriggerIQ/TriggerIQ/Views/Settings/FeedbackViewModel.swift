import SwiftUI
import Combine

@MainActor
final class FeedbackViewModel: ObservableObject {
    @Published var feedbackType: FeedbackType = .suggestion
    @Published var title: String = ""
    @Published var body: String = ""
    @Published var isSubmitting = false
    @Published var submitted = false
    @Published var errorMessage: String?

    var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isSubmitting
    }

    private let service: GitHubIssueServiceProtocol

    init(service: GitHubIssueServiceProtocol? = nil) {
        self.service = service ?? GitHubIssueService()
    }

    func submit() async {
        guard canSubmit else { return }
        isSubmitting = true
        errorMessage = nil
        do {
            try await service.submit(title: title, body: body, type: feedbackType)
            submitted = true
        } catch {
            errorMessage = error.localizedDescription
        }
        isSubmitting = false
    }
}
