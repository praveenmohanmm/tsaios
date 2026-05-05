import WatchConnectivity
import WatchKit
import UserNotifications

/// Receives messages from the paired iPhone and fires a haptic immediately.
///
/// Two delivery paths:
///   • sendMessage  (iPhone → Watch app is reachable / foreground)
///       → WKInterfaceDevice.play(.notification) — instant, no banner
///   • transferUserInfo (iPhone → Watch app is in background / not running)
///       → local UNNotification fired on the Watch — triggers haptic + banner
///         even when the Watch face is showing something else entirely
@MainActor
final class WatchSessionManager: NSObject, ObservableObject {

    static let shared = WatchSessionManager()

    @Published var lastAlertDistance: Int?
    @Published var lastAlertTime: Date?

    private override init() {
        super.init()
        // Request permission for local notifications (needed for background haptics)
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Background task entry point

    /// Called by the `.watchConnectivity` background task in WatchApp.swift.
    /// Stays alive long enough for WCSession delegate callbacks to fire.
    func handleBackgroundConnectivity() async {
        // The didReceiveUserInfo delegate fires during this task window.
        // A short sleep ensures we don't exit before the callback runs.
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 s
    }

    // MARK: - Alert handling

    /// Foreground path: direct haptic via WKInterfaceDevice (silent, instant).
    fileprivate func receiveAlertForeground(distanceMetres: Int) {
        WKInterfaceDevice.current().play(.notification)
        updateState(distanceMetres: distanceMetres)
    }

    /// Background path: local notification → Watch OS triggers haptic tap
    /// even when the app is not visible / not running.
    fileprivate func receiveAlertBackground(distanceMetres: Int) {
        let content = UNMutableNotificationContent()
        content.title = "🚦 Signal Ahead"
        content.body  = "\(distanceMetres) m away"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "tsaios.alert.\(UUID().uuidString)",
            content: content,
            trigger: nil          // fire immediately
        )
        UNUserNotificationCenter.current().add(request) { _ in }
        updateState(distanceMetres: distanceMetres)
    }

    private func updateState(distanceMetres: Int) {
        lastAlertDistance = distanceMetres
        lastAlertTime = Date()
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    /// Fired when iPhone used sendMessage — Watch app was reachable (foreground).
    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        guard let dist = message["haptic"] as? Int else { return }
        Task { @MainActor in
            WatchSessionManager.shared.receiveAlertForeground(distanceMetres: dist)
        }
    }

    /// Fired when iPhone used transferUserInfo — Watch app was in background.
    /// This delegate is the KEY missing piece for background haptics.
    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let dist = userInfo["haptic"] as? Int else { return }
        Task { @MainActor in
            WatchSessionManager.shared.receiveAlertBackground(distanceMetres: dist)
        }
    }

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}
}
