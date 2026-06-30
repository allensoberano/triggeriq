import SwiftUI

struct FeedbackView: View {
    @StateObject private var vm = FeedbackViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Briefly describe your suggestion", text: $vm.title)
                        .onChange(of: vm.title) { _, new in
                            if new.count > FeedbackViewModel.maxTitleLength {
                                vm.title = String(new.prefix(FeedbackViewModel.maxTitleLength))
                            }
                        }
                } header: {
                    Text("Title")
                } footer: {
                    Text("\(vm.titleRemaining) characters remaining")
                        .foregroundStyle(vm.titleRemaining < 10 ? .red : .secondary)
                }

                Section {
                    TextField("What would you like to see, and why?", text: $vm.body, axis: .vertical)
                        .frame(minHeight: 120, alignment: .top)
                        .onChange(of: vm.body) { _, new in
                            if new.count > FeedbackViewModel.maxBodyLength {
                                vm.body = String(new.prefix(FeedbackViewModel.maxBodyLength))
                            }
                        }
                } header: {
                    Text("Details")
                } footer: {
                    Text("\(vm.bodyRemaining) characters remaining")
                        .foregroundStyle(vm.bodyRemaining < 50 ? .red : .secondary)
                }
            }
            .navigationTitle("Submit a Suggestion")
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
