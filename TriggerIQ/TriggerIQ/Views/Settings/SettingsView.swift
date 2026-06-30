import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @State private var profile: UserProfile?
    @State private var showClearConfirm = false
    @State private var conditionsText = ""
    @State private var allergiesText = ""

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profile
                Section("About You") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Known conditions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. IBS, Crohn's, Eczema", text: $conditionsText, axis: .vertical)
                            .onChange(of: conditionsText) { _, _ in saveProfile() }
                        Text("Separate with commas")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Known allergies")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("e.g. peanuts, gluten", text: $allergiesText, axis: .vertical)
                            .onChange(of: allergiesText) { _, _ in saveProfile() }
                        Text("Separate with commas")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 4)
                }

                // MARK: - Check-ins
                Section {
                    Toggle("1-Hour Check-in", isOn: Binding(
                        get: { profile?.oneHourCheckInEnabled ?? true },
                        set: { profile?.oneHourCheckInEnabled = $0; saveProfile() }
                    ))
                    Toggle("3-Hour Check-in", isOn: Binding(
                        get: { profile?.fourHourCheckInEnabled ?? true },
                        set: { profile?.fourHourCheckInEnabled = $0; saveProfile() }
                    ))
                    Toggle("Morning Check-in", isOn: Binding(
                        get: { profile?.nextMorningCheckInEnabled ?? true },
                        set: { profile?.nextMorningCheckInEnabled = $0; saveProfile() }
                    ))
                } header: {
                    Text("Check-in Reminders")
                } footer: {
                    Text("Disabling a check-in type stops future notifications for that window. Past data is kept.")
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
            .task { loadProfile() }
            .confirmationDialog(
                "Clear all data?",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear Everything", role: .destructive) { clearAllData() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes all meals, check-ins, and insights. This cannot be undone.")
            }
        }
    }

    // MARK: - Helpers

    private func loadProfile() {
        let profiles = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        let p = profiles.first ?? {
            let newProfile = UserProfile()
            context.insert(newProfile)
            return newProfile
        }()
        profile = p
        conditionsText = p.knownConditions.joined(separator: ", ")
        allergiesText = p.knownAllergies.joined(separator: ", ")
    }

    private func saveProfile() {
        guard let profile else { return }
        profile.knownConditions = conditionsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        profile.knownAllergies = allergiesText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        try? context.save()
    }

    private func clearAllData() {
        let photoStorage: PhotoStorageServiceProtocol = resolve()
        let meals = (try? context.fetch(FetchDescriptor<Meal>())) ?? []
        for meal in meals {
            if let fileName = meal.photoFileName {
                photoStorage.delete(fileName: fileName)
            }
            context.delete(meal)
        }
        let patterns = (try? context.fetch(FetchDescriptor<SuspectFoodPattern>())) ?? []
        patterns.forEach { context.delete($0) }
        let logs = (try? context.fetch(FetchDescriptor<DailyLog>())) ?? []
        logs.forEach { context.delete($0) }
        try? context.save()
    }
}
