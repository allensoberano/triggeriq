import UserNotifications

@MainActor
protocol NotificationSchedulingServiceProtocol {
    func scheduleCheckIns(for meal: Meal) async
    func scheduleNextMorningSummary() async
    func cancelCheckIns(for meal: Meal) async
}

@MainActor
final class NotificationSchedulingService: NotificationSchedulingServiceProtocol {
    private let center: NotificationCenterProtocol

    init(center: NotificationCenterProtocol = LiveNotificationCenter()) {
        self.center = center
    }

    func scheduleCheckIns(for meal: Meal) async {
        let settings = await center.notificationSettings()
        print("[Notifications] Auth status: \(settings.authorizationStatus.rawValue)")
        guard settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .provisional else {
            print("[Notifications] Not authorized — skipping scheduling")
            return
        }

        await scheduleCheckIn(
            identifier: checkInID(meal: meal, type: .oneHour),
            title: "How are you feeling?",
            body: "It's been an hour since your meal. Any symptoms?",
            at: meal.timestamp.addingTimeInterval(10)           // DEBUG: 10 seconds
            // at: meal.timestamp.addingTimeInterval(60 * 60)   // PRODUCTION: 1 hour
        )

        await scheduleCheckIn(
            identifier: checkInID(meal: meal, type: .fourHour),
            title: "Check in time",
            body: "4 hours since your meal — any bloating, fatigue, or joint pain?",
            at: meal.timestamp.addingTimeInterval(20)              // DEBUG: 20 seconds
            // at: meal.timestamp.addingTimeInterval(4 * 60 * 60) // PRODUCTION: 4 hours
        )
    }

    func scheduleNextMorningSummary() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized ||
              settings.authorizationStatus == .provisional else { return }

        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.day! += 1
        components.hour = 8
        components.minute = 0

        guard let fireDate = Calendar.current.date(from: components),
              fireDate > Date() else { return }

        await scheduleCheckIn(
            identifier: "next-morning-summary",
            title: "Morning check-in",
            body: "How did you sleep? Tap to review yesterday's meals and log how you feel.",
            at: fireDate
        )
    }

    func cancelCheckIns(for meal: Meal) async {
        let ids = [
            checkInID(meal: meal, type: .oneHour),
            checkInID(meal: meal, type: .fourHour)
        ]
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Private

    private func scheduleCheckIn(identifier: String, title: String, body: String, at date: Date) async {
        guard date > Date() else {
            print("[Notifications] Skipping \(identifier) — date \(date) is in the past")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.userInfo = ["notificationIdentifier": identifier]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: date.timeIntervalSinceNow,
            repeats: false
        )
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        do {
            try await center.add(request)
            print("[Notifications] Scheduled \(identifier) in \(Int(date.timeIntervalSinceNow))s")
        } catch {
            print("[Notifications] Failed to schedule \(identifier): \(error)")
        }
    }

    private func checkInID(meal: Meal, type: CheckInType) -> String {
        "checkin-\(meal.id.uuidString)-\(type.rawValue)"
    }
}
