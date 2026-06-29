import SwiftUI
import SwiftData

struct CheckInView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @StateObject var vm: CheckInViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(vm.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }

                Section("Symptoms") {
                    SymptomRow(label: "Bloating", value: $vm.bloating)
                    SymptomRow(label: "Joint Pain", value: $vm.jointPain)
                    SymptomRow(label: "Fatigue", value: $vm.fatigue)
                    SymptomRow(label: "Brain Fog", value: $vm.brainFog)
                    SymptomRow(label: "Skin", value: $vm.skin)
                }

                Section {
                    Button {
                        vm.showBristolHydration = true
                    } label: {
                        Label("Log bowel movement or hydration", systemImage: "plus.circle")
                    }
                }

                Section {
                    Button {
                        vm.save(context: context)
                    } label: {
                        Text("Save Check-in")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.borderedProminent)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
            .navigationTitle(vm.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Skip") { vm.skip(context: context) }
                        .foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $vm.showBristolHydration) {
                BristolHydrationView()
            }
            .onChange(of: vm.isSaved) { _, saved in
                if saved { dismiss() }
            }
        }
    }
}

// MARK: - Symptom Row

struct SymptomRow: View {
    let label: String
    @Binding var value: Int

    private let levels = ["None", "Mild", "Moderate", "Severe"]
    private let colors: [Color] = [.secondary, .yellow, .orange, .red]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                Spacer()
                Text(levels[value])
                    .font(.caption)
                    .foregroundStyle(colors[value])
            }

            HStack(spacing: 8) {
                ForEach(0..<4) { level in
                    Button {
                        value = level
                    } label: {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(value == level ? colors[level] : Color(.tertiarySystemFill))
                            .frame(maxWidth: .infinity)
                            .frame(height: 32)
                            .overlay {
                                if value == level {
                                    Text("\(level)")
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.white)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
}
