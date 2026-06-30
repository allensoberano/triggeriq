import SwiftUI
import PhotosUI
import SwiftData
import UIKit

struct LogMealSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @StateObject private var vm = LogMealViewModel()
    @State private var showCamera = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Log Meal")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { image in
                guard let jpeg = image.jpegData(compressionQuality: 0.8) else { return }
                vm.capturedPhotoData = jpeg
                showCamera = false
            }
            .ignoresSafeArea()
        }
        .onChange(of: showCamera) { _, isShowing in
            // Trigger analysis after camera sheet fully dismisses
            if !isShowing, let jpeg = vm.capturedPhotoData {
                vm.capturedPhotoData = nil
                Task { await vm.analyzeCapturedPhoto(jpeg) }
            }
        }
        .onChange(of: vm.selectedPhotoItem) { _, item in
            guard let item else { return }
            Task { await vm.analyzePhoto(item) }
        }
        .onChange(of: vm.isSaved) { _, saved in
            if saved { dismiss() }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch vm.step {
        case .inputMethod:
            InputMethodView(vm: vm, onCamera: { showCamera = true })
        case .analyzing:
            AnalyzingView()
        case .confirm(let result):
            MealConfirmView(vm: vm, result: result, context: context)
        case .error(let message):
            ErrorView(message: message, vm: vm)
        }
    }
}

// MARK: - Input Method

private struct InputMethodView: View {
    @ObservedObject var vm: LogMealViewModel
    let onCamera: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Button(action: onCamera) {
                    InputOptionRow(
                        icon: "camera.fill",
                        title: "Take a photo",
                        subtitle: "Use your camera to capture the meal"
                    )
                }

                Divider().padding(.horizontal)

                PhotosPicker(selection: $vm.selectedPhotoItem, matching: .images) {
                    InputOptionRow(
                        icon: "photo.on.rectangle",
                        title: "Choose from library",
                        subtitle: "Pick an existing photo"
                    )
                }

                Divider().padding(.horizontal)

                Button {
                    vm.step = .inputMethod  // stay on step but reveal text entry below
                } label: {
                    InputOptionRow(
                        icon: "text.cursor",
                        title: "Describe your meal",
                        subtitle: "Type what you ate"
                    )
                }
                .accessibilityIdentifier("describeMealButton")
            }
            .padding()
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal)

            if case .inputMethod = vm.step {
                VStack(spacing: 12) {
                    MealTypePickerRow(mealType: $vm.mealType)
                        .padding(.horizontal)

                    ManualTextEntry(vm: vm)
                        .padding(.horizontal)
                }
            }

            Spacer()
        }
        .background(Color(.systemGroupedBackground))
    }
}

private struct InputOptionRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}

private struct MealTypePickerRow: View {
    @Binding var mealType: MealType

    var body: some View {
        Picker("Meal type", selection: $mealType) {
            Text("Breakfast").tag(MealType.breakfast)
            Text("Lunch").tag(MealType.lunch)
            Text("Dinner").tag(MealType.dinner)
            Text("Snack").tag(MealType.snack)
        }
        .pickerStyle(.segmented)
    }
}

private struct ManualTextEntry: View {
    @ObservedObject var vm: LogMealViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What did you eat?")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            TextField("e.g. grilled salmon, roasted vegetables, brown rice", text: $vm.manualText, axis: .vertical)
                .lineLimit(3...6)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                Task { await vm.analyzeText() }
            } label: {
                Text("Analyze")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(vm.manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("analyzeButton")
        }
    }
}

// MARK: - Analyzing

private struct AnalyzingView: View {
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.4)
            Text("Analyzing your meal…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - Error

private struct ErrorView: View {
    let message: String
    let vm: LogMealViewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Try again") { vm.retry() }
                .buttonStyle(.borderedProminent)
            Spacer()
        }
    }
}
