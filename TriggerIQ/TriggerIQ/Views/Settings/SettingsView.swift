import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var vm = SettingsViewModel()
    @State private var showClearConfirm = false
    @State private var showFeedback = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profile
                Section("About You") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Known conditions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. IBS, Crohn's, Eczema", text: $vm.conditionsText, axis: .vertical)
                            .onChange(of: vm.conditionsText) { _, _ in vm.save(context: context) }
                        Text("Separate with commas")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Known allergies")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. peanuts, gluten", text: $vm.allergiesText, axis: .vertical)
                            .onChange(of: vm.allergiesText) { _, _ in vm.save(context: context) }
                        Text("Separate with commas")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - Check-ins
                Section {
                    Toggle("1-Hour Check-in", isOn: $vm.oneHourEnabled)
                        .onChange(of: vm.oneHourEnabled) { _, _ in vm.save(context: context) }
                    Toggle("3-Hour Check-in", isOn: $vm.fourHourEnabled)
                        .onChange(of: vm.fourHourEnabled) { _, _ in vm.save(context: context) }
                    Toggle("Morning Check-in", isOn: $vm.nextMorningEnabled)
                        .onChange(of: vm.nextMorningEnabled) { _, _ in vm.save(context: context) }
                } header: {
                    Text("Check-in Reminders")
                } footer: {
                    Text("Disabling a check-in type stops future notifications for that window. Past data is kept.")
                }

                // MARK: - Feedback
                Section {
                    Button {
                        showFeedback = true
                    } label: {
                        Label("Ask a Question", systemImage: "questionmark.circle")
                    }
                    Button {
                        showFeedback = true
                    } label: {
                        Label("Submit a Suggestion", systemImage: "lightbulb")
                    }
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("Opens a form that files a GitHub issue on the TriggerIQ repo.")
                }

                // MARK: - Data
                Section("Data") {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label("Clear All Data", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Settings")
            .task { vm.load(context: context) }
            .sheet(isPresented: $showFeedback) {
                FeedbackView()
            }
            .confirmationDialog(
                "Clear all data?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear Everything", role: .destructive) {
                    vm.clearAllData(context: context)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes all meals, check-ins, and insights. This cannot be undone.")
            }
        }
    }
}
