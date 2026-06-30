import Testing
import Foundation
@testable import TriggerIQ

@MainActor
struct FeedbackViewModelTests {

    private func makeVM(error: Error? = nil,
                        store: FeedbackRateLimitStore = InMemoryRateLimitStore()) -> (FeedbackViewModel, MockGitHubIssueService) {
        let mock = MockGitHubIssueService()
        mock.errorToThrow = error
        let vm = FeedbackViewModel(service: mock, rateLimitStore: store)
        return (vm, mock)
    }

    // MARK: - canSubmit

    @Test func cannotSubmitWhenTitleEmpty() {
        let (vm, _) = makeVM()
        vm.body = "Some body"
        #expect(vm.canSubmit == false)
    }

    @Test func cannotSubmitWhenBodyEmpty() {
        let (vm, _) = makeVM()
        vm.title = "Some title"
        #expect(vm.canSubmit == false)
    }

    @Test func canSubmitWhenBothFilled() {
        let (vm, _) = makeVM()
        vm.title = "My title"
        vm.body = "My body"
        #expect(vm.canSubmit == true)
    }

    @Test func cannotSubmitWhitespaceOnly() {
        let (vm, _) = makeVM()
        vm.title = "   "
        vm.body = "   "
        #expect(vm.canSubmit == false)
    }

    @Test func cannotSubmitWhenTitleExceedsMaxLength() {
        let (vm, _) = makeVM()
        vm.title = String(repeating: "a", count: FeedbackViewModel.maxTitleLength + 1)
        vm.body = "Body"
        #expect(vm.canSubmit == false)
    }

    @Test func cannotSubmitWhenBodyExceedsMaxLength() {
        let (vm, _) = makeVM()
        vm.title = "Title"
        vm.body = String(repeating: "a", count: FeedbackViewModel.maxBodyLength + 1)
        #expect(vm.canSubmit == false)
    }

    @Test func canSubmitAtExactMaxLength() {
        let (vm, _) = makeVM()
        vm.title = String(repeating: "a", count: FeedbackViewModel.maxTitleLength)
        vm.body = String(repeating: "b", count: FeedbackViewModel.maxBodyLength)
        #expect(vm.canSubmit == true)
    }

    @Test func remainingCountsReflectInput() {
        let (vm, _) = makeVM()
        vm.title = "12345"
        vm.body = "1234567890"
        #expect(vm.titleRemaining == FeedbackViewModel.maxTitleLength - 5)
        #expect(vm.bodyRemaining == FeedbackViewModel.maxBodyLength - 10)
    }

    // MARK: - submit

    @Test func submitCallsServiceWithCorrectValues() async throws {
        let (vm, mock) = makeVM()
        vm.title = "Add dark mode"
        vm.body = "Would love a dark mode option"
        vm.feedbackType = .suggestion
        await vm.submit()
        #expect(mock.submittedTitle == "Add dark mode")
        #expect(mock.submittedBody == "Would love a dark mode option")
        #expect(mock.submittedType == .suggestion)
    }

    @Test func submitSetsSubmittedOnSuccess() async {
        let (vm, _) = makeVM()
        vm.title = "Title"
        vm.body = "Body"
        await vm.submit()
        #expect(vm.submitted == true)
    }

    @Test func submitSetsErrorMessageOnFailure() async {
        let (vm, _) = makeVM(error: GitHubIssueError.httpError(422))
        vm.title = "Title"
        vm.body = "Body"
        await vm.submit()
        #expect(vm.errorMessage != nil)
        #expect(vm.submitted == false)
    }

    @Test func submitClearsErrorOnRetry() async {
        let mock = MockGitHubIssueService()
        let vm = FeedbackViewModel(service: mock, rateLimitStore: InMemoryRateLimitStore())
        vm.title = "Title"
        vm.body = "Body"

        mock.errorToThrow = GitHubIssueError.httpError(500)
        await vm.submit()
        #expect(vm.errorMessage != nil)

        mock.errorToThrow = nil
        await vm.submit()
        #expect(vm.errorMessage == nil)
        #expect(vm.submitted == true)
    }

    @Test func defaultFeedbackTypeIsSuggestion() {
        let (vm, _) = makeVM()
        #expect(vm.feedbackType == .suggestion)
    }

    // MARK: - rate limiting

    @Test func allowsUpToThreeSubmissionsPerHour() async {
        let store = InMemoryRateLimitStore()
        let mock = MockGitHubIssueService()
        let vm = FeedbackViewModel(service: mock, rateLimitStore: store)

        for i in 1...3 {
            vm.title = "Title \(i)"
            vm.body = "Body \(i)"
            await vm.submit()
            #expect(vm.submitted == true)
            vm.submitted = false
        }
    }

    @Test func blocksFourthSubmissionWithinHour() async {
        let store = InMemoryRateLimitStore()
        let mock = MockGitHubIssueService()
        let vm = FeedbackViewModel(service: mock, rateLimitStore: store)

        for i in 1...3 {
            vm.title = "Title \(i)"
            vm.body = "Body \(i)"
            await vm.submit()
        }

        vm.title = "Fourth"
        vm.body = "Should be blocked"
        await vm.submit()

        #expect(vm.submitted == false)
        #expect(vm.errorMessage != nil)
        #expect(mock.submittedTitle != "Fourth")
    }

    @Test func rateLimitDoesNotCountFailedSubmissions() async {
        let store = InMemoryRateLimitStore()
        let mock = MockGitHubIssueService()
        mock.errorToThrow = GitHubIssueError.httpError(500)
        let vm = FeedbackViewModel(service: mock, rateLimitStore: store)

        for i in 1...3 {
            vm.title = "Title \(i)"
            vm.body = "Body \(i)"
            await vm.submit()
            #expect(vm.submitted == false)
        }

        mock.errorToThrow = nil
        vm.title = "Should succeed"
        vm.body = "Body"
        await vm.submit()
        #expect(vm.submitted == true)
    }

    @Test func oldSubmissionsOutsideWindowDoNotCountTowardLimit() async {
        let store = InMemoryRateLimitStore()
        // Pre-seed with 3 stale timestamps (older than 1 hour)
        let staleTimestamps = [
            Date().addingTimeInterval(-7200).timeIntervalSince1970,
            Date().addingTimeInterval(-7100).timeIntervalSince1970,
            Date().addingTimeInterval(-7000).timeIntervalSince1970
        ]
        store.save(staleTimestamps)

        let mock = MockGitHubIssueService()
        let vm = FeedbackViewModel(service: mock, rateLimitStore: store)
        vm.title = "Title"
        vm.body = "Body"
        await vm.submit()

        #expect(vm.submitted == true)
    }
}
