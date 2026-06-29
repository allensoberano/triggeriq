import UserNotifications
internal import Combine

@MainActor
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate, ObservableObject {
    static let shared = NotificationDelegate()

    @Published var pendingCheckIn: CheckInDestination?

    // Called when user taps a notification
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        let destination = checkInDestination(from: identifier)

        if let destination {
            Task { @MainActor in
                self.pendingCheckIn = destination
            }
        }

        completionHandler()
    }

    // Allow notifications to show as banners when app is foregrounded
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func checkInDestination(from identifier: String) -> CheckInDestination? {
        if identifier == "next-morning-summary" {
            return CheckInDestination(checkInType: .nextMorning, mealID: nil)
        }

        let parts = identifier.components(separatedBy: "-")
        guard parts.count >= 3, parts[0] == "checkin" else { return nil }

        let typeString = parts.last ?? ""
        let checkInType: CheckInType = typeString == "oneHour" ? .oneHour : .fourHour
        return CheckInDestination(checkInType: checkInType, mealID: nil)
    }
}
