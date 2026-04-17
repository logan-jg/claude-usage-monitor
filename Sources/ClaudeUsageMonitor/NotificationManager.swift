import AppKit
import Foundation
import UserNotifications

/// Thin wrapper around UNUserNotificationCenter. Uses the notification `identifier`
/// as a dedup key — re-sending with the same identifier replaces instead of stacking.
@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    enum AuthorizationState {
        case notDetermined
        case denied
        case authorized
    }

    private(set) var state: AuthorizationState = .notDetermined

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    /// Ensure notifications surface as banners even when the app is foreground —
    /// LSUIElement apps can still be "active" when Settings window is visible,
    /// which otherwise suppresses the banner entirely.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func refreshState() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        state = Self.translate(settings.authorizationStatus)
    }

    /// Ask for permission. No-op if already determined (user must change via System Settings).
    @discardableResult
    func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound])
            await refreshState()
            return granted
        } catch {
            await refreshState()
            return false
        }
    }

    /// Post a notification with the given identifier. Repeated calls with the same
    /// identifier replace the existing notification silently; the caller is expected
    /// to handle its own "fire once" dedup.
    func post(identifier: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error {
                NSLog("[ClaudeUsageMonitor] notification post failed: \(error)")
            }
        }
    }

    func openSystemNotificationSettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.Notifications-Settings.extension")
            ?? URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!
        NSWorkspace.shared.open(url)
    }

    private static func translate(_ s: UNAuthorizationStatus) -> AuthorizationState {
        switch s {
        case .authorized, .provisional, .ephemeral: return .authorized
        case .denied: return .denied
        case .notDetermined: return .notDetermined
        @unknown default: return .notDetermined
        }
    }
}
