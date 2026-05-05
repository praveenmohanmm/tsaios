import WatchConnectivity
import WatchKit
import UserNotifications

/// Receives alert messages from the paired iPhone and fires the chosen haptic pattern.
///
/// Delivery paths:
///   • sendMessage            → Watch app in foreground  → WKInterfaceDevice.play() directly
///   • updateApplicationContext → Watch app backgrounded/locked → local UNNotification → haptic
///   • transferUserInfo (legacy fallback) → same as above
@MainActor
final class WatchSessionManager: NSObject, ObservableObject {

    static let shared = WatchSessionManager()

    @Published var lastAlertDistance: Int?
    @Published var lastAlertTime: Date?

    /// Used to keep the .watchConnectivity background task alive until the
    /// delegate callback fires, then resolved so the task exits cleanly.
    private var backgroundContinuation: CheckedContinuation<Void, Never>?

    private override init() {
        super.init()
        // Request permission for local notifications (background haptic delivery)
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound]) { granted, _ in
                print("WatchSessionManager: notification permission granted=\(granted)")
            }
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
    }

    // MARK: - Background task entry point

    /// Called by the `.watchConnectivity` background task in WatchApp.swift.
    /// Suspends until the incoming delegate callback fires (or times out after 5 s).
    func handleBackgroundConnectivity() async {
        await withCheckedContinuation { continuation in
            backgroundContinuation = continuation
            // Safety timeout — ensures the background task always exits.
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                self.resolveBackgroundTask()
            }
        }
    }

    private func resolveBackgroundTask() {
        backgroundContinuation?.resume()
        backgroundContinuation = nil
    }

    // MARK: - Foreground: direct haptic pattern

    fileprivate func receiveAlertForeground(distanceMetres: Int, pattern: String) {
        Task { await self.playPattern(pattern) }
        updateState(distanceMetres: distanceMetres)
    }

    // MARK: - Background: local notification → watchOS haptic tap

    fileprivate func receiveAlertBackground(distanceMetres: Int, pattern: String) {
        let content = UNMutableNotificationContent()
        content.title = "🚦 Signal Ahead"
        content.body  = "\(distanceMetres) m away"
        content.sound = .default
        if #available(watchOS 8.0, *) {
            content.interruptionLevel = .timeSensitive
        }
        let request = UNNotificationRequest(
            identifier: "tsaios.alert.\(UUID().uuidString)",
            content: content,
            trigger: nil   // fire immediately
        )
        UNUserNotificationCenter.current().add(request) { err in
            if let err { print("WatchSessionManager: notification error \(err)") }
        }
        updateState(distanceMetres: distanceMetres)
        resolveBackgroundTask()   // let the background task exit cleanly
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
            for i in 0..<5 {
                if i > 0 { try? await sleep(ms: 150) }
                play(.notification)
            }

        case "urgentPulse":
            play(.failure)
            try? await sleep(ms: 350)
            for i in 0..<3 {
                if i > 0 { try? await sleep(ms: 180) }
                play(.notification)
            }

        default:
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

    /// Foreground path: iPhone used sendMessage (Watch app was reachable).
    nonisolated func session(_ session: WCSession,
                             didReceiveMessage message: [String: Any]) {
        guard let dist = message["haptic"] as? Int else { return }
        let pattern = message["pattern"] as? String ?? "triple"
        Task { @MainActor in
            WatchSessionManager.shared.receiveAlertForeground(distanceMetres: dist,
                                                              pattern: pattern)
        }
    }

    /// Background path: iPhone used updateApplicationContext (Watch was locked/backgrounded).
    /// This is the primary background delivery mechanism — fast and reliable.
    nonisolated func session(_ session: WCSession,
                             didReceiveApplicationContext context: [String: Any]) {
        guard let dist = context["haptic"] as? Int else { return }
        let pattern = context["pattern"] as? String ?? "triple"
        Task { @MainActor in
            WatchSessionManager.shared.receiveAlertBackground(distanceMetres: dist,
                                                              pattern: pattern)
        }
    }

    /// Legacy fallback: iPhone used transferUserInfo.
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
