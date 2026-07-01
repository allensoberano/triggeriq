import SwiftUI
import SwiftData
import Charts

struct InsightsView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var vm = InsightsViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if vm.mealCount == 0 {
                    InsightsEmptyView()
                } else {
                    List {
                        Section {
                            SummaryStatsView(
                                mealCount: vm.mealCount,
                                checkInCount: vm.checkInCount
                            )
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        }

                        Section("Predicted Score Trend") {
                            ScoreTrendChart(points: vm.scorePoints)
                                .frame(height: 200)
                                .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                        }

                        if !vm.hydrationPoints.isEmpty {
                            Section("Hydration Average") {
                                HydrationTrendChart(points: vm.hydrationPoints)
                                    .frame(height: 200)
                                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            }
                        }

                        if !vm.stoolPoints.isEmpty {
                            Section("Stool Average") {
                                StoolTrendChart(points: vm.stoolPoints)
                                    .frame(height: 200)
                                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                            }
                        }

                        if !vm.patterns.isEmpty {
                            Section {
                                ForEach(vm.patterns.prefix(10)) { pattern in
                                    FoodPatternRow(pattern: pattern, baseline: vm.baselineSeverity)
                                }
                            } header: {
                                Text("Suspect Foods")
                            } footer: {
                                Text("Based on check-in symptoms after meals containing each ingredient. Needs more data to be reliable.")
                                    .font(.caption)
                            }
                        } else {
                            Section("Suspect Foods") {
                                PatternsInsufficientDataView()
                            }
                        }
                    }
                }
            }
            .navigationTitle("Insights")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        vm.recomputePatterns(context: context)
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                }
            }
            .task {
                vm.load(context: context)
            }
        }
    }
}

// MARK: - Empty State

private struct InsightsEmptyView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 56))
                .foregroundStyle(.tertiary)
            Text("No data yet")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Log a few meals and check in after eating. Insights will appear once you have enough data.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Summary Stats

private struct SummaryStatsView: View {
    let mealCount: Int
    let checkInCount: Int

    var body: some View {
        HStack(spacing: 0) {
            StatTile(value: "\(mealCount)", label: "Meals logged")
            Divider().frame(height: 40)
            StatTile(value: "\(checkInCount)", label: "Check-ins")
        }
    }
}

private struct StatTile: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Score Trend Chart

private struct ScoreTrendChart: View {
    let points: [ScorePoint]

    private var avgScore: Double {
        guard !points.isEmpty else { return 0 }
        return points.map(\.score).reduce(0, +) / Double(points.count)
    }

    private func color(for score: Double) -> Color {
        switch score {
        case ..<3.5: return .green
        case ..<6.5: return .orange
        default:     return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Avg score")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(String(format: "%.1f / 10", avgScore))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(color(for: avgScore))
            }

            Chart {
                // Baseline rule
                RuleMark(y: .value("Avg", avgScore))
                    .foregroundStyle(.secondary.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4]))

                ForEach(points) { point in
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.6))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Score", point.score)
                    )
                    .foregroundStyle(color(for: point.score))
                    .symbolSize(40)
                }
            }
            .chartYScale(domain: 0...10)
            .chartYAxis {
                AxisMarks(values: [0, 2.5, 5, 7.5, 10]) { val in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: max(1, points.count / 5))) { _ in
                    AxisValueLabel(format: .dateTime.month().day())
                }
            }
        }
    }
}

// MARK: - Hydration Trend Chart

private struct HydrationTrendChart: View {
    let points: [TrendPoint]

    private var avgValue: Double {
        guard !points.isEmpty else { return 0 }
        return points.map(\.value).reduce(0, +) / Double(points.count)
    }

    private func color(for level: Double) -> Color {
        switch level {
        case ..<3:  return .yellow
        case ..<6:  return .orange
        default:    return .brown
        }
    }

    private func label(for level: Double) -> String {
        switch level {
        case ..<3:  return "Well hydrated"
        case ..<6:  return "Mild dehydration"
        default:    return "Dehydrated"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Avg urine color")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(label(for: avgValue))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(color(for: avgValue))
            }

            Chart {
                ForEach(points) { point in
                    // Smoothed rolling average (past 5 logs) shown as a dotted line
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Rolling avg", point.rollingAverage)
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Color scale", point.value)
                    )
                    .foregroundStyle(color(for: point.value))
                    .symbolSize(30)
                }
            }
            .chartYScale(domain: 1...8)
            .chartYAxis {
                AxisMarks(values: [1, 2, 3, 4, 5, 6, 7, 8]) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: max(1, points.count / 5))) { _ in
                    AxisValueLabel(format: .dateTime.month().day())
                }
            }
        }
    }
}

// MARK: - Stool Trend Chart

private struct StoolTrendChart: View {
    let points: [TrendPoint]

    private var avgValue: Double {
        guard !points.isEmpty else { return 0 }
        return points.map(\.value).reduce(0, +) / Double(points.count)
    }

    private func color(for scale: Double) -> Color {
        switch scale {
        case ..<2.5:  return .orange
        case ..<4.5:  return .green
        case ..<5.5:  return .yellow
        default:      return .red
        }
    }

    private func label(for scale: Double) -> String {
        switch scale {
        case ..<2.5:  return "Constipated"
        case ..<4.5:  return "Regular"
        case ..<5.5:  return "Lacking fiber"
        default:      return "Diarrhea"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Avg Bristol scale")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(label(for: avgValue))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(color(for: avgValue))
            }

            Chart {
                ForEach(points) { point in
                    // Smoothed rolling average (past 5 logs) shown as a dotted line
                    LineMark(
                        x: .value("Date", point.date),
                        y: .value("Rolling avg", point.rollingAverage)
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.7))
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 4]))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("Date", point.date),
                        y: .value("Bristol scale", point.value)
                    )
                    .foregroundStyle(color(for: point.value))
                    .symbolSize(30)
                }
            }
            .chartYScale(domain: 1...7)
            .chartYAxis {
                AxisMarks(values: [1, 2, 3, 4, 5, 6, 7]) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: max(1, points.count / 5))) { _ in
                    AxisValueLabel(format: .dateTime.month().day())
                }
            }
        }
    }
}

// MARK: - Food Pattern Row

private struct FoodPatternRow: View {
    let pattern: SuspectFoodPattern
    let baseline: Double

    private var delta: Double { pattern.avgSymptomSeverity - baseline }

    private var confidenceBadge: some View {
        Text(pattern.confidence.rawValue.capitalized)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(confidenceColor.opacity(0.15))
            .foregroundStyle(confidenceColor)
            .clipShape(Capsule())
    }

    private var confidenceColor: Color {
        switch pattern.confidence {
        case .low:      return .secondary
        case .emerging: return .orange
        case .strong:   return .red
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(pattern.canonicalTag.capitalized)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                confidenceBadge
            }

            HStack(spacing: 8) {
                // Severity bar relative to baseline
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(.tertiarySystemFill))
                            .frame(height: 6)

                        // Baseline marker
                        let baseX = geo.size.width * (baseline / 3.0)
                        Rectangle()
                            .fill(Color.secondary.opacity(0.5))
                            .frame(width: 1.5, height: 10)
                            .offset(x: min(baseX, geo.size.width - 1.5))

                        // Actual bar
                        RoundedRectangle(cornerRadius: 3)
                            .fill(confidenceColor.opacity(0.7))
                            .frame(
                                width: geo.size.width * min(pattern.avgSymptomSeverity / 3.0, 1.0),
                                height: 6
                            )
                    }
                }
                .frame(height: 10)

                Text(delta > 0 ? String(format: "+%.1f vs avg", delta) : String(format: "%.1f vs avg", delta))
                    .font(.caption)
                    .foregroundStyle(delta > 0.2 ? confidenceColor : .secondary)
                    .frame(width: 90, alignment: .trailing)
            }

            Text("\(pattern.sampleSize) meal\(pattern.sampleSize == 1 ? "" : "s")")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Insufficient Data

private struct PatternsInsufficientDataView: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
            Text("Complete more check-ins to see which foods may be triggering symptoms.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
