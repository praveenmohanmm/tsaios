import Foundation
import UserNotifications

/// Triggers an Apple Watch haptic by posting a local notification with
/// `.timeSensitive` interruption level. When the iPhone screen is off /
/// locked, watchOS mirrors the notification and plays a haptic on the paired
/// Apple Watch.
@MainActor
final class WatchHapticService {

    static let shared = WatchHapticService()
    private init() {}

    /// Call once at launch — prompts for notification permission if needed.
    func requestPermission() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .timeSensitive]) { _, _ in }
    }

    /// Post an immediate local notification. Always attempts delivery —
    /// if the user denied permission, `add(_:)` fails silently on its own.
    func triggerWatchHaptic(distanceMetres: Int) {
        let content = UNMutableNotificationContent()
        content.title = "🚦 Signal Ahead"
        content.body = "\(distanceMetres) m away"
        content.sound = .default     // sound required for notification to mirror to Watch
        if #available(iOS 15.0, *) {
            content.interruptionLevel = .timeSensitive
        }

        let request = UNNotificationRequest(
            identifier: "tsaios.signal.\(UUID().uuidString)",
            content: content,
            trigger: nil             // nil trigger = deliver immediately
        )

        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
