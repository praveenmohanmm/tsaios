import WatchConnectivity

/// Manages the iPhone side of WatchConnectivity.
/// Activated at launch; sends a haptic trigger message to the Watch
/// via `sendMessage` (real-time) or `transferUserInfo` (background fallback).
@MainActor
final class PhoneSessionManager: NSObject, ObservableObject {

    static let shared = PhoneSessionManager()

    private override init() {
        super.init()
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    /// Send a haptic command to the paired Apple Watch.
    /// Works whether the iPhone screen is on or off.
    func sendHaptic(distanceMetres: Int, pattern: WatchHapticPattern = .triple) {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }

        let message: [String: Any] = [
            "haptic":  distanceMetres,
            "pattern": pattern.rawValue
        ]

        if session.isReachable {
            // Watch app is in foreground — deliver instantly via sendMessage.
            session.sendMessage(message, replyHandler: nil) { _ in }
        } else {
            // Watch app is backgrounded/locked.
            // updateApplicationContext is delivered as soon as the next background
            // task runs — much faster than transferUserInfo for real-time alerts.
            try? session.updateApplicationContext(message)
        }
    }
}

// MARK: - WCSessionDelegate (iOS requires these three methods)

extension PhoneSessionManager: WCSessionDelegate {

    nonisolated func session(_ session: WCSession,
                             activationDidCompleteWith activationState: WCSessionActivationState,
                             error: Error?) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Re-activate after a Watch swap.
        WCSession.default.activate()
    }
}
