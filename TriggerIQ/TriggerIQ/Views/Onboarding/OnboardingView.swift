import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @StateObject private var vm = OnboardingViewModel()
    let onComplete: () -> Void

    var body: some View {
        TabView(selection: $vm.page) {
            WelcomePage()
                .tag(0)
            ConditionsPage(vm: vm)
                .tag(1)
            NotificationsPage(vm: vm)
                .tag(2)
            HealthKitPage(vm: vm)
                .tag(3)
            ReadyPage()
                .tag(4)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .animation(.easeInOut, value: vm.page)
        .overlay(alignment: .bottom) {
            OnboardingNavBar(
                page: $vm.page,
                totalPages: vm.totalPages,
                onFinish: {
                    vm.finish(context: context)
                    onComplete()
                }
            )
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Pages

private struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "fork.knife.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.tint)
            Text("Welcome to TriggerIQ")
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            Text("Track what you eat and how you feel after. Over time, TriggerIQ identifies foods that may be triggering your symptoms.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }
}

private struct ConditionsPage: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                PageHeader(
                    icon: "heart.text.square",
                    title: "About You",
                    subtitle: "This helps personalize your insights. You can skip and update this later in Settings."
                )

                ChecklistSection(
                    title: "Known conditions",
                    presets: OnboardingViewModel.presetConditions,
                    selected: $vm.selectedConditions,
                    customText: $vm.customConditions,
                    customPlaceholder: "Other conditions, separated by commas"
                )

                ChecklistSection(
                    title: "Known allergies",
                    presets: OnboardingViewModel.presetAllergies,
                    selected: $vm.selectedAllergies,
                    customText: $vm.customAllergies,
                    customPlaceholder: "Other allergies, separated by commas"
                )
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }
}

private struct ChecklistSection: View {
    let title: String
    let presets: [String]
    @Binding var selected: Set<String>
    @Binding var customText: String
    let customPlaceholder: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)

            ForEach(presets, id: \.self) { item in
                Button {
                    if selected.contains(item) {
                        selected.remove(item)
                    } else {
                        selected.insert(item)
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selected.contains(item) ? "checkmark.square.fill" : "square")
                            .foregroundStyle(selected.contains(item) ? Color.accentColor : Color(.tertiaryLabel))
                            .font(.title3)
                        Text(item)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
            }

            TextField(customPlaceholder, text: $customText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .font(.subheadline)
                .padding(.top, 4)
            Text("Separate with commas")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct NotificationsPage: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            PageHeader(
                icon: "bell.badge.fill",
                title: "Check-in Reminders",
                subtitle: "TriggerIQ sends reminders 1 hour and 3 hours after meals so you don't forget to rate your symptoms."
            )

            if vm.notificationStepDone {
                Label("Notification request sent", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
            } else {
                Button {
                    Task { await vm.requestNotifications() }
                } label: {
                    Label("Enable Notifications", systemImage: "bell")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 32)

                Button("Skip for now") { vm.page += 1 }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Spacer()
        }
    }
}

private struct HealthKitPage: View {
    @ObservedObject var vm: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            PageHeader(
                icon: "heart.fill",
                title: "HealthKit",
                subtitle: "TriggerIQ reads sleep, HRV, and steps to help understand how lifestyle factors interact with food triggers."
            )

            if vm.healthKitStepDone {
                Label("HealthKit request sent", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
            } else {
                Button {
                    Task { await vm.requestHealthKit() }
                } label: {
                    Label("Connect HealthKit", systemImage: "heart.text.square")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 32)

                Button("Skip for now") { vm.page += 1 }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Spacer()
        }
    }
}

private struct ReadyPage: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)
            Text("You're all set!")
                .font(.largeTitle)
                .fontWeight(.bold)
            Text("Log your first meal to get started. The more consistently you check in, the better your insights will be.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
            Spacer()
        }
    }
}

// MARK: - Shared Components

private struct PageHeader: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(.tint)
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct OnboardingNavBar: View {
    @Binding var page: Int
    let totalPages: Int
    let onFinish: () -> Void

    var isLast: Bool { page == totalPages - 1 }

    var body: some View {
        HStack {
            if page > 0 {
                Button("Back") { page -= 1 }
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(isLast ? "Get Started" : "Next") {
                if isLast { onFinish() } else { page += 1 }
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 32)
    }
}
