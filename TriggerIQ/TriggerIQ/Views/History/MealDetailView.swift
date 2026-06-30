import SwiftUI
import SwiftData
import UIKit

struct MealDetailView: View {
    let meal: Meal
    @Environment(\.modelContext) private var context
    @State private var dailyLog: DailyLog?
    @State private var mealPhoto: UIImage?

    private var photoStorage: PhotoStorageServiceProtocol { resolve() }

    var body: some View {
        List {
            // MARK: - Photo / Header
            Section {
                MealHeaderView(meal: meal, photo: mealPhoto)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            }

            // MARK: - Score
            Section("Predicted inflammation") {
                ScoreBarView(score: meal.predictedScore)
            }

            // MARK: - Description
            Section("Description") {
                Text(meal.rawDescription)
                    .font(.subheadline)
                if meal.userEdited {
                    Label("You edited this", systemImage: "pencil")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: - Food Tags
            if !meal.foodTags.isEmpty {
                Section("Ingredients") {
                    FlowLayout(tags: meal.foodTags)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }

            // MARK: - Check-in Timeline
            Section("Check-in timeline") {
                if meal.checkIns.isEmpty {
                    Text("No check-ins recorded")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(meal.checkIns.sorted { $0.scheduledTime < $1.scheduledTime }) { checkIn in
                        CheckInTimelineRow(meal: meal, checkIn: checkIn)
                    }
                }
            }

            // MARK: - Day Confounders
            if let log = dailyLog {
                Section("That day") {
                    ConfounderSummaryView(log: log)
                }
            }
        }
        .navigationTitle(meal.mealType.rawValue.capitalized)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadDailyLog()
            loadPhoto()
        }
    }

    private func loadDailyLog() {
        let day = Calendar.current.startOfDay(for: meal.timestamp)
        let descriptor = FetchDescriptor<DailyLog>(
            predicate: #Predicate { $0.date == day }
        )
        dailyLog = try? context.fetch(descriptor).first
    }

    private func loadPhoto() {
        guard let fileName = meal.photoFileName else { return }
        mealPhoto = photoStorage.load(fileName: fileName)
    }
}

// MARK: - Meal Header

private struct MealHeaderView: View {
    let meal: Meal
    let photo: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Rectangle()
                    .fill(Color(.secondarySystemGroupedBackground))
                    .frame(height: 200)

                if let photo {
                    Image(uiImage: photo)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipped()
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 48))
                            .foregroundStyle(.tertiary)
                        Text(meal.photoDeleted ? "Photo deleted" : "No photo")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            HStack {
                Label(meal.timestamp.formatted(date: .omitted, time: .shortened),
                      systemImage: "clock")
                Spacer()
                Label(meal.mealType.rawValue.capitalized, systemImage: "fork.knife")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }
}

// MARK: - Score Bar

private struct ScoreBarView: View {
    let score: Double

    var color: Color {
        switch score {
        case ..<3.5: return .green
        case ..<6.5: return .orange
        default: return .red
        }
    }

    var label: String {
        switch score {
        case ..<3.5: return "Low"
        case ..<6.5: return "Moderate"
        default: return "High"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(color)
                Spacer()
                Text(String(format: "%.1f / 10", score))
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.tertiarySystemFill))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * (score / 10), height: 8)
                }
            }
            .frame(height: 8)
        }
    }
}

// MARK: - Food Tag Flow Layout

private struct FlowLayout: View {
    let tags: [FoodTag]

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 80))],
            alignment: .leading,
            spacing: 8
        ) {
            ForEach(tags) { tag in
                Text(tag.rawName.capitalized)
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
            }
        }
    }
}

// MARK: - Check-in Timeline Row

private struct CheckInTimelineRow: View {
    let meal: Meal
    let checkIn: CheckIn

    private var typeLabel: String {
        switch checkIn.type {
        case .oneHour: return "+1 hr"
        case .fourHour: return "+4 hr"
        case .nextMorning: return "Morning"
        case .adHoc: return "Ad hoc"
        }
    }

    private var maxSymptom: Int {
        [checkIn.bloating, checkIn.gassy, checkIn.jointPain, checkIn.fatigue,
         checkIn.brainFog, checkIn.skin]
            .compactMap { $0 }
            .max() ?? 0
    }

    private var symptomColor: Color {
        switch maxSymptom {
        case 0: return .green
        case 1: return .yellow
        case 2: return .orange
        default: return .red
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            VStack(spacing: 2) {
                Text(typeLabel)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Text(checkIn.scheduledTime.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(width: 56, alignment: .center)

            Divider()

            if checkIn.skipped {
                Text("Skipped")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
            } else if checkIn.completedTime != nil {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(symptomColor)
                            .frame(width: 10, height: 10)
                        Text(symptomSummary)
                            .font(.subheadline)
                    }
                    Text("vs predicted \(String(format: "%.1f", meal.predictedScore))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No response")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .italic()
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var symptomSummary: String {
        guard checkIn.completedTime != nil else { return "" }
        let all = [
            ("Bloating", checkIn.bloating),
            ("Gassy", checkIn.gassy),
            ("Joint pain", checkIn.jointPain),
            ("Fatigue", checkIn.fatigue),
            ("Brain fog", checkIn.brainFog),
            ("Skin", checkIn.skin)
        ]
        let active = all.compactMap { label, val -> String? in
            guard let val, val > 0 else { return nil }
            return label
        }
        return active.isEmpty ? "No symptoms" : active.joined(separator: ", ")
    }
}

// MARK: - Confounder Summary

private struct ConfounderSummaryView: View {
    let log: DailyLog

    var body: some View {
        HStack(spacing: 16) {
            ConfounderChip(icon: "brain.head.profile", label: "Stress",
                           value: log.stressLevel, max: 3)
            ConfounderChip(icon: "wineglass", label: "Alcohol",
                           value: log.alcoholDrinks, max: nil)
            ConfounderChip(icon: "cup.and.saucer.fill", label: "Caffeine",
                           value: log.caffeineDrinks, max: nil)
            ConfounderChip(icon: "drop.fill", label: "Water",
                           value: log.waterGlasses, max: nil)
        }
    }
}

private struct ConfounderChip: View {
    let icon: String
    let label: String
    let value: Int?
    let max: Int?

    var displayValue: String {
        guard let value else { return "—" }
        if let max, max == 3 {
            return ["None", "Low", "Moderate", "High"][min(value, 3)]
        }
        return "\(value)"
    }

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
            Text(displayValue)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}
