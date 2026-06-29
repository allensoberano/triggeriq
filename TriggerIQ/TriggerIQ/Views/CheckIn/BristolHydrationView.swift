import SwiftUI
import SwiftData

struct BristolHydrationView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var bristolScale: Int = 4
    @State private var hydrationColor: Int = 3
    @State private var bowelNotes: String = ""
    @State private var showBowel = true
    @State private var showHydration = true

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("Log bowel movement", isOn: $showBowel)
                    Toggle("Log hydration", isOn: $showHydration)
                }

                if showBowel {
                    Section("Bristol Stool Scale") {
                        Text("Select the type that best matches")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        ForEach(1...7, id: \.self) { scale in
                            Button {
                                bristolScale = scale
                            } label: {
                                HStack {
                                    Text("\(scale)")
                                        .font(.headline)
                                        .foregroundStyle(.primary)
                                        .frame(width: 28)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(bristolLabel(scale))
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                        Text(bristolDescription(scale))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    if bristolScale == scale {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.tint)
                                    }
                                }
                            }
                        }

                        TextField("Notes (optional)", text: $bowelNotes)
                            .font(.subheadline)
                    }
                }

                if showHydration {
                    Section("Hydration (Urine Color)") {
                        Text("Darker = more dehydrated")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                            ForEach(1...8, id: \.self) { level in
                                Button {
                                    hydrationColor = level
                                } label: {
                                    VStack(spacing: 4) {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(hydrationSwatchColor(level))
                                            .frame(height: 44)
                                            .overlay {
                                                if hydrationColor == level {
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .stroke(Color.primary, lineWidth: 2)
                                                }
                                            }
                                        Text("\(level)")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section {
                    Button {
                        saveEntries()
                    } label: {
                        Text("Save")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Bowel & Hydration")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func saveEntries() {
        let today = Calendar.current.startOfDay(for: Date())
        let dayDescriptor = FetchDescriptor<DailyLog>(predicate: #Predicate { $0.date == today })
        let day = (try? context.fetch(dayDescriptor).first) ?? {
            let log = DailyLog(date: today)
            context.insert(log)
            return log
        }()

        if showBowel {
            let entry = BowelMovementEntry(timestamp: Date(), bristolScale: bristolScale)
            entry.notes = bowelNotes.isEmpty ? nil : bowelNotes
            entry.day = day
            context.insert(entry)
        }

        if showHydration {
            let entry = HydrationEntry(timestamp: Date(), colorScale: hydrationColor)
            entry.day = day
            context.insert(entry)
        }

        try? context.save()
        dismiss()
    }

    private func bristolLabel(_ scale: Int) -> String {
        switch scale {
        case 1: return "Separate hard lumps"
        case 2: return "Lumpy and sausage-like"
        case 3: return "Sausage with cracks"
        case 4: return "Smooth and soft"
        case 5: return "Soft blobs"
        case 6: return "Mushy consistency"
        case 7: return "Liquid, no solids"
        default: return ""
        }
    }

    private func bristolDescription(_ scale: Int) -> String {
        switch scale {
        case 1, 2: return "Constipated"
        case 3, 4: return "Normal"
        case 5: return "Lacking fiber"
        case 6, 7: return "Diarrhea"
        default: return ""
        }
    }

    private func hydrationSwatchColor(_ level: Int) -> Color {
        switch level {
        case 1: return Color(red: 1.0, green: 0.98, blue: 0.82)
        case 2: return Color(red: 1.0, green: 0.96, blue: 0.70)
        case 3: return Color(red: 1.0, green: 0.93, blue: 0.55)
        case 4: return Color(red: 1.0, green: 0.88, blue: 0.35)
        case 5: return Color(red: 0.95, green: 0.80, blue: 0.15)
        case 6: return Color(red: 0.85, green: 0.68, blue: 0.05)
        case 7: return Color(red: 0.65, green: 0.45, blue: 0.02)
        case 8: return Color(red: 0.45, green: 0.28, blue: 0.01)
        default: return .clear
        }
    }
}
