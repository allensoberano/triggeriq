import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var vm = TodayViewModel()
    @State private var showLogMeal = false
    @State private var showBathroomLogging = false

    var body: some View {
        NavigationStack {
            List {
                if vm.hasPendingCheckIn {
                    PendingCheckInCard(vm: vm)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                        .listRowBackground(Color.clear)
                }

                Section("HealthKit") {
                    HealthKitStripView(log: vm.todayLog)
                }

                Section("How's today going?") {
                    ConfounderRow(
                        icon: "brain.head.profile",
                        label: "Stress",
                        value: $vm.stress,
                        max: 3
                    )
                    ConfounderRow(
                        icon: "wineglass",
                        label: "Alcohol",
                        value: $vm.alcoholDrinks,
                        max: 10
                    )
                    ConfounderRow(
                        icon: "cup.and.saucer.fill",
                        label: "Caffeine",
                        value: $vm.caffeineDrinks,
                        max: 10
                    )
                    ConfounderRow(
                        icon: "drop.fill",
                        label: "Water (8oz)",
                        value: $vm.waterGlasses,
                        max: 20
                    )
                }

                Section("Bathroom") {
                    Button {
                        showBathroomLogging = true
                    } label: {
                        Label("Log bowel movement or hydration", systemImage: "plus.circle")
                    }
                }

                Section("Today's meals") {
                    if vm.todayMeals.isEmpty {
                        Text("No meals logged yet")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(vm.todayMeals) { meal in
                            MealRow(meal: meal)
                                .accessibilityIdentifier("mealRow-\(meal.id)")
                        }
                    }
                }
                .accessibilityIdentifier("todayMealsSection")
            }
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showLogMeal = true
                    } label: {
                        Label("Log Meal", systemImage: "plus")
                    }
                    .accessibilityIdentifier("logMealButton")
                }
            }
            .sheet(isPresented: $showLogMeal) {
                LogMealSheet()
            }
            .sheet(isPresented: $showBathroomLogging) {
                BristolHydrationView()
            }
            .sheet(item: $vm.pendingCheckIn) { destination in
                CheckInView(vm: CheckInViewModel(
                    checkInType: destination.checkInType,
                    mealID: destination.mealID
                ))
            }
            .task {
                vm.load(context: context)
                await vm.refreshHealthKit(context: context)
            }
            .onChange(of: showLogMeal) { _, isShowing in
                if !isShowing { vm.load(context: context) }
            }
            .onChange(of: vm.stress) { _, _ in vm.saveConfounders(context: context) }
            .onChange(of: vm.alcoholDrinks) { _, _ in vm.saveConfounders(context: context) }
            .onChange(of: vm.caffeineDrinks) { _, _ in vm.saveConfounders(context: context) }
            .onChange(of: vm.waterGlasses) { _, _ in vm.saveConfounders(context: context) }
        }
    }
}

// MARK: - Pending Check-in Card

private struct PendingCheckInCard: View {
    @ObservedObject var vm: TodayViewModel

    var body: some View {
        Button {
            if let pending = vm.firstPendingMeal() {
                vm.pendingCheckIn = CheckInDestination(
                    checkInType: pending.type,
                    mealID: pending.meal.persistentModelID
                )
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bell.badge.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Check-in ready")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("Tap to rate your symptoms")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - HealthKit Strip

private struct HealthKitStripView: View {
    let log: DailyLog?

    var body: some View {
        if let log {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                HealthMetricTile(
                    icon: "figure.walk",
                    label: "Steps",
                    value: log.stepCount.map { "\($0)" } ?? "—"
                )
                HealthMetricTile(
                    icon: "moon.fill",
                    label: "Sleep",
                    value: log.sleepDuration.map { formatSleep($0) } ?? "—"
                )
                HealthMetricTile(
                    icon: "waveform.path.ecg",
                    label: "HRV",
                    value: log.avgHRV.map { String(format: "%.0f ms", $0) } ?? "—"
                )
                HealthMetricTile(
                    icon: "heart.fill",
                    label: "Resting HR",
                    value: log.restingHeartRate.map { String(format: "%.0f bpm", $0) } ?? "—"
                )
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        } else {
            Button {
                Task {
                    try? await resolve(HealthKitServiceProtocol.self).requestAuthorization()
                }
            } label: {
                Label("Connect HealthKit", systemImage: "heart.text.square")
            }
        }
    }

    private func formatSleep(_ seconds: TimeInterval) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

private struct HealthMetricTile: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.tint)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Confounder Row

private struct ConfounderRow: View {
    let icon: String
    let label: String
    @Binding var value: Int
    let max: Int

    private var displayValue: String {
        max == 3 ? ["None", "Low", "Moderate", "High"][min(value, 3)] : "\(value)"
    }

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
            Spacer()
            HStack(spacing: 12) {
                Button {
                    if value > 0 { value -= 1 }
                } label: {
                    Image(systemName: "minus.circle")
                        .foregroundStyle(value > 0 ? Color.accentColor : Color(.tertiaryLabel))
                }
                .buttonStyle(.plain)

                Text(displayValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(minWidth: 60, alignment: .center)

                Button {
                    if value < max { value += 1 }
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(value < max ? Color.accentColor : Color(.tertiaryLabel))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Meal Row

struct MealRow: View {
    let meal: Meal

    private var scoreColor: Color {
        switch meal.predictedScore {
        case ..<3.5: return .green
        case ..<6.5: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(meal.mealType.rawValue.capitalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(meal.rawDescription)
                    .font(.subheadline)
                    .lineLimit(2)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", meal.predictedScore))
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(scoreColor)
                Text("score")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
