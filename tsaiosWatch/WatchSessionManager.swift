import WatchConnectivity
import WatchKit
import UserNotifications

/// Receives messages from the paired iPhone and fires the chosen haptic pattern.
///
/// Two delivery paths:
///   • sendMessage  → Watch app reachable (foreground): plays pattern directly
///   • transferUserInfo → Watch app backgrounded: fires a local notification
///     (watchOS always taps for a notification, even with screen off)
@MainActor
final class WatchSessionManager: NSObject, ObservableObject {

    static let shared = WatchSessionManager()

    @Published var lastAlertDistance: Int?
    @Published var lastAlertTime: Date?

    private override init() {
        super.init()
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { _, _ in }
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Background task entry point

    func handleBackgroundConnectivity() async {
        try? await Task.sleep(nanoseconds: 2_000_000_000)
    }

    // MARK: - Foreground: play haptic pattern directly

    fileprivate func receiveAlertForeground(distanceMetres: Int, pattern: String) {
        Task { await playPattern(pattern) }
        updateState(distanceMetres: distanceMetres)
    }

    // MARK: - Background: local notification triggers Watch haptic

    fileprivate func receiveAlertBackground(distanceMetres: Int, pattern: String) {
        let content = UNMutableNotificationContent()
        content.title = "🚦 Signal Ahead"
        content.body  = "\(distanceMetres) m away"
        content.sound = .default
        if #available(watchOS 7.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        // Embed pattern so if the app wakes it can play additional taps.
        content.userInfo = ["pattern": pattern, "distance": distanceMetres]
        let request = UNNotificationRequest(
            identifier: "tsaios.alert.\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { _ in }
        updateState(distanceMetres: distanceMetres)
    }

    // MARK: - Haptic pattern player

    private func playPattern(_ rawPattern: String) async {
        switch rawPattern {
        case "single":
            play(.notification)

        case "double":
            play(.notification)
            try? await sleep(ms: 220)
            play(.notification)

        case "triple":
            for i in 0..<3 {
                if i > 0 { try? await sleep(ms: 200) }
                play(.notification)
            }

        case "longBuzz":
            // 5 rapid taps — ~0.8 s of continuous buzzing
            for i in 0..<5 {
                if i > 0 { try? await sleep(ms: 150) }
                play(.notification)
            }

        case "urgentPulse":
            // Failure burst (longer tap) then 3 notification taps
            play(.failure)
            try? await sleep(ms: 350)
            for i in 0..<3 {
                if i > 0 { try? await sleep(ms: 180) }
                play(.notification)
            }

        default:
            // Fallback: triple
            for i in 0..<3 {
                if i > 0 { try? await sleep(ms: 200) }
                play(.notification)
            }
        }
    }

    // MARK: - Helpers

    private func play(_ type: WKHapticType) {
        WKInterfaceDevice.current().play(type)
    }

    private func sleep(ms: UInt64) async throws {
        try await Task.sleep(nanoseconds: ms * 1_000_000)
    }

    private func updateState(distanceMetres: Int) {
        lastAlertDistance = distanceMetres
        lastAlertTime = Date()
    }
}

// MARK: - WCSessionDelegate

extension WatchSessionManager: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        guard let dist = message["haptic"] as? Int else { return }
        let pattern = message["pattern"] as? String ?? "triple"
        Task { @MainActor in
            WatchSessionManager.shared.receiveAlertForeground(distanceMetres: dist,
                                                              pattern: pattern)
        }
    }

    nonisolated func session(_ session: WCSession,
                             didReceiveUserInfo userInfo: [String: Any] = [:]) {
        guard let dist = userInfo["haptic"] as? Int else { return }
        let pattern = userInfo["pattern"] as? String ?? "triple"
        Task { @MainActor in
            WatchSessionManager.shared.receiveAlertBackground(distanceMetres: dist,
                                                              pattern: pattern)
        }
    }

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}
}
