import Testing
import Foundation
@testable import TriggerIQ

@MainActor
struct FeedbackViewModelTests {

    private func makeVM(error: Error? = nil) -> (FeedbackViewModel, MockGitHubIssueService) {
        let mock = MockGitHubIssueService()
        mock.errorToThrow = error
        let vm = FeedbackViewModel(service: mock)
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
        let vm = FeedbackViewModel(service: mock)
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
}
