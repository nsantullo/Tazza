import Foundation
import UserNotifications

/// Local notifications for when Tazza turns itself off. Nothing is sent over the network.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private static let shared = Notifier()
    private static let warningCategory = "tazza.warning"
    static let extendAction = "tazza.warning.extend"
    static let stopAction = "tazza.warning.stop"

    private static var onExtend: (() -> Void)?
    private static var onStopNow: (() -> Void)?
    private static var warningID: String?

    static func setUp(onExtend: @escaping () -> Void, onStopNow: @escaping () -> Void) {
        self.onExtend = onExtend
        self.onStopNow = onStopNow
        let center = UNUserNotificationCenter.current()
        center.delegate = shared
        let extend = UNNotificationAction(identifier: extendAction, title: L("notify.action.extend"), options: [])
        let stop = UNNotificationAction(identifier: stopAction, title: L("notify.action.stop"), options: [.destructive])
        center.setNotificationCategories([
            UNNotificationCategory(identifier: warningCategory, actions: [extend, stop],
                                   intentIdentifiers: [], options: [])
        ])
        // Sessions do not survive a quit or a crash, so anything left from a previous run is out of date.
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }

    /// macOS asks the user only the first time. If they refuse, notifications do nothing and the menu says so.
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    /// For the menu, which is rebuilt as it opens. If macOS is slow to answer, the item stays out this time.
    static func isDenied() -> Bool {
        var denied = false
        let done = DispatchSemaphore(value: 0)
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            denied = settings.authorizationStatus == .denied
            done.signal()
        }
        return done.wait(timeout: .now() + 0.5) == .success && denied
    }

    static func post(_ text: String) {
        let content = UNMutableNotificationContent()
        content.title = "Tazza"
        content.body = text
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }

    /// Plans the warning with its two buttons. Waits for the permission answer, which the first session may still
    /// be waiting on. Each warning has its own id, so a cancel still in progress cannot remove the new one.
    static func scheduleWarning(at date: Date) {
        let id = UUID().uuidString
        warningID = id
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                let delay = date.timeIntervalSinceNow
                guard granted, warningID == id, delay > 0 else { return }
                let content = UNMutableNotificationContent()
                content.title = "Tazza"
                content.body = L("notify.warning")
                content.sound = .default
                content.categoryIdentifier = warningCategory
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            }
        }
    }

    /// Removes the warning whether it is still planned or already on screen, so its buttons cannot act later.
    static func cancelWarning() {
        guard let id = warningID else { return }
        warningID = nil
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [id])
        center.removeDeliveredNotifications(withIdentifiers: [id])
    }

    static func handleAction(_ identifier: String) {
        switch identifier {
        case extendAction: onExtend?()
        case stopAction: onStopNow?()
        default: break // the user clicked the banner itself or dismissed it
        }
    }

    /// Without this macOS hides the banner while the app is active, for example with its menu open.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    /// May arrive off the main thread, while the session and its timer live on the main one.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        DispatchQueue.main.async {
            Notifier.handleAction(response.actionIdentifier)
            completionHandler()
        }
    }
}
