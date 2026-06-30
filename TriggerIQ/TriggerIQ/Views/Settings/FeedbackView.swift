import SwiftUI

struct FeedbackView: View {
    @StateObject private var vm = FeedbackViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                // Type picker
                Section {
                    Picker("Type", selection: $vm.feedbackType) {
                        ForEach(FeedbackType.allCases, id: \.self) { type in
                            Label(type.label, systemImage: type.icon).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }

                Section("Title") {
                    TextField(
                        vm.feedbackType == .question
                            ? "What's your question?"
                            : "Briefly describe your suggestion",
                        text: $vm.title
                    )
                }

                Section("Details") {
                    TextField(
                        vm.feedbackType == .question
                            ? "Give us more context…"
                            : "What would you like to see, and why?",
                        text: $vm.body,
                        axis: .vertical
                    )
                    .frame(minHeight: 120, alignment: .top)
                }

            }
            .navigationTitle(vm.feedbackType == .question ? "Ask a Question" : "Submit a Suggestion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if vm.isSubmitting {
                        ProgressView()
                    } else {
                        Button("Submit") {
                            Task { await vm.submit() }
                        }
                        .disabled(!vm.canSubmit)
                    }
                }
            }
            .alert("Thank You!", isPresented: $vm.submitted) {
                Button("Done") { dismiss() }
            } message: {
                Text("Your feedback has been received. We appreciate you helping improve TriggerIQ.")
            }
            .alert("Couldn't Send Feedback", isPresented: Binding(
                get: { vm.errorMessage != nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )) {
                Button("OK") { vm.errorMessage = nil }
            } message: {
                Text("We weren't able to submit your feedback. Please try again later.")
            }
        }
    }
}
