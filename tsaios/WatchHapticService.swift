import Foundation
import UserNotifications

/// Triggers an Apple Watch haptic by posting a local notification with
/// `.timeSensitive` interruption level. When the iPhone is locked or in
/// "wrist-on" forwarding scenarios, watchOS mirrors the notification and
/// plays its default haptic on the paired Apple Watch.
///
/// This requires neither a Watch app target nor any developer-portal setup
/// beyond enabling the "Time Sensitive Notifications" capability on the
/// app's App ID (which is on by default for development profiles).
@MainActor
final class WatchHapticService {

    static let shared = WatchHapticService()

    private var permissionGranted = false

    private init() {}

    /// Call once at launch — prompts the user for notification permission.
    func requestPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .timeSensitive]) { [weak self] granted, _ in
            DispatchQueue.main.async {
                self?.permissionGranted = granted
            }
        }
    }

    /// Post an immediate local notification. The paired Apple Watch will
    /// mirror it (haptic + banner) under iOS notification-forwarding rules.
    func triggerWatchHaptic(distanceMetres: Int) {
        guard permissionGranted else { return }

        let content = UNMutableNotificationContent()
        content.title = "🚦 Signal Ahead"
        content.body = "\(distanceMetres) m away"
        content.sound = nil          // audio is already played by AudioService
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        // Fire immediately — nil trigger delivers right away.
        let request = UNNotificationRequest(
            identifier: "tsaios.signal.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request) { _ in
            // Best-effort — swallow errors (e.g. permission revoked mid-session).
        }
    }
}
