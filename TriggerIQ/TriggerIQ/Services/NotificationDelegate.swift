import UserNotifications

final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    // Called when user taps a notification while app is in foreground or background
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        let destination = checkInDestination(from: identifier)

        if let destination {
            NotificationCenter.default.post(name: .openCheckIn, object: destination)
        }

        completionHandler()
    }

    // Allow notifications to show as banners even when app is foregrounded
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    private func checkInDestination(from identifier: String) -> CheckInDestination? {
        if identifier == "next-morning-summary" {
            return CheckInDestination(checkInType: .nextMorning, mealID: nil)
        }

        // Format: "checkin-<uuid>-oneHour" or "checkin-<uuid>-fourHour"
        let parts = identifier.components(separatedBy: "-")
        guard parts.count >= 3, parts[0] == "checkin" else { return nil }

        let typeString = parts.last ?? ""
        let checkInType: CheckInType = typeString == "oneHour" ? .oneHour : .fourHour

        // mealID lookup happens via UUID match at the check-in save site
        return CheckInDestination(checkInType: checkInType, mealID: nil)
    }
}
